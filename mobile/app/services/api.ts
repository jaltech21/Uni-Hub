/**
 * API Client Service
 * Centralized HTTP client with authentication, error handling, and interceptors
 */

import axios, { AxiosInstance, AxiosError, AxiosResponse } from "axios";
import AsyncStorage from "@react-native-async-storage/async-storage";
import * as Keychain from "react-native-keychain";
import { Platform } from "react-native";
import { ApiError } from "@app/types";

const STORAGE_TOKEN_KEY = "uniHub_auth_token";
const STORAGE_REFRESH_TOKEN_KEY = "uniHub_auth_refresh_token";

const keychain = (Keychain as any) || {};
const hasNativeKeychain =
  !!keychain &&
  typeof keychain.getGenericPassword === "function" &&
  typeof keychain.setGenericPassword === "function" &&
  typeof keychain.resetGenericPassword === "function";
const useFallbackStorage = Platform.OS === "web" || !hasNativeKeychain;

const getStorageKey = (service?: string) =>
  service === "refresh_token" ? STORAGE_REFRESH_TOKEN_KEY : STORAGE_TOKEN_KEY;

const keychainSafe = {
  async getGenericPassword(options?: any) {
    const key = getStorageKey(options?.service);
    if (useFallbackStorage) {
      const value = await AsyncStorage.getItem(key);
      return value ? { password: value } : null;
    }

    try {
      const credentials = await keychain.getGenericPassword(options);
      if (credentials) {
        return credentials;
      }
      const fallbackValue = await AsyncStorage.getItem(key);
      return fallbackValue ? { password: fallbackValue } : null;
    } catch (error) {
      console.error("Error retrieving token:", error);
      const value = await AsyncStorage.getItem(key);
      return value ? { password: value } : null;
    }
  },

  async setGenericPassword(username: string, password: string, options?: any) {
    const key = getStorageKey(options?.service);

    if (useFallbackStorage) {
      await AsyncStorage.setItem(key, password);
      return { username, password };
    }

    try {
      const result = await keychain.setGenericPassword(username, password, options);
      await AsyncStorage.removeItem(key);
      return result;
    } catch (error) {
      console.error("Error saving token:", error);
      await AsyncStorage.setItem(key, password);
      return { username, password };
    }
  },

  async resetGenericPassword(options?: any) {
    const key = getStorageKey(options?.service);

    if (useFallbackStorage) {
      await AsyncStorage.removeItem(key);
      return true;
    }

    try {
      const result = await keychain.resetGenericPassword(options);
      await AsyncStorage.removeItem(key);
      return result;
    } catch (error) {
      console.error("Error clearing tokens:", error);
      await AsyncStorage.removeItem(key);
      return true;
    }
  },
};

// EAS builds receive EXPO_PUBLIC_API_URL at build time; local development keeps
// the emulator/browser defaults when no environment value is configured.
const configuredApiUrl = process.env.EXPO_PUBLIC_API_URL?.trim();
const API_BASE_URL =
  configuredApiUrl ||
  (Platform.OS === "android"
    ? "http://10.0.2.2:3000/api/v1"
    : "http://localhost:3000/api/v1");

class ApiClient {
  private client: AxiosInstance;
  private isRefreshing = false;
  private refreshSubscribers: Array<(token: string) => void> = [];

  private unwrapResponseData<T>(response: AxiosResponse<T> | any): T {
    const payload = response?.data;

    if (payload && typeof payload === "object") {
      if ("data" in payload && !Array.isArray(payload) && payload.data !== undefined) {
        return (payload as any).data as T;
      }

      if ("success" in payload && payload.success === false && payload.error) {
        throw new Error(payload.error.message || "Request failed");
      }
    }

    return payload as T;
  }

  constructor() {
    this.client = axios.create({
      baseURL: API_BASE_URL,
      timeout: 15000,
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
      },
    });

    // Request interceptor: add auth token
    this.client.interceptors.request.use(
      async (config) => {
        if (typeof FormData !== "undefined" && config.data instanceof FormData) {
          delete config.headers["Content-Type"];
          delete config.headers["content-type"];
        }
        const token = await this.getStoredToken();
        if (token && !config.headers?.Authorization && !config.headers?.authorization) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor: handle 401, refresh token
    this.client.interceptors.response.use(
      (response) => response,
      async (error: AxiosError) => {
        const originalRequest = error.config as any;
        const requestUrl = originalRequest?.url || "";

        if (requestUrl.endsWith("/auth/refresh")) {
          await this.clearTokens();
          return Promise.reject(error);
        }

        if (error.response?.status === 401 && !originalRequest._retry) {
          originalRequest._retry = true;

          if (!this.isRefreshing) {
            this.isRefreshing = true;
            try {
              const refreshToken = await this.getStoredRefreshToken();
              if (!refreshToken) {
                this.isRefreshing = false;
                await this.clearTokens();
                return Promise.reject(error);
              }
              if (refreshToken) {
                const response = await this.client.post(
                  "/auth/refresh",
                  {},
                  {
                    headers: {
                      Authorization: `Bearer ${refreshToken}`,
                    },
                  }
                );
                const payload = this.unwrapResponseData<{
                  token: string;
                  refresh_token?: string;
                }>(response);
                const newToken = payload.token;
                const newRefreshToken = payload.refresh_token;
                await this.saveToken(newToken, newRefreshToken);

                this.isRefreshing = false;
                this.refreshSubscribers.forEach((callback) =>
                  callback(newToken)
                );
                this.refreshSubscribers = [];

                originalRequest.headers.Authorization = `Bearer ${newToken}`;
                return this.client(originalRequest);
              }
            } catch (err) {
              this.isRefreshing = false;
              await this.clearTokens();
              // Trigger logout in auth context
              throw err;
            }
          } else {
            return new Promise((resolve) => {
              this.refreshSubscribers.push((token: string) => {
                originalRequest.headers.Authorization = `Bearer ${token}`;
                resolve(this.client(originalRequest));
              });
            });
          }
        }

        return Promise.reject(error);
      }
    );
  }

  // Auth token management
  async getStoredToken(): Promise<string | null> {
    try {
      const credentials = await keychainSafe.getGenericPassword();
      return credentials ? credentials.password : null;
    } catch (error) {
      console.error("Error retrieving token:", error);
      return null;
    }
  }

  async getStoredRefreshToken(): Promise<string | null> {
    try {
      const credentials = await keychainSafe.getGenericPassword({
        service: "refresh_token",
      });
      return credentials ? credentials.password : null;
    } catch (error) {
      console.error("Error retrieving refresh token:", error);
      return null;
    }
  }

  async saveToken(token: string, refreshToken?: string): Promise<void> {
    try {
      await keychainSafe.setGenericPassword("auth_token", token);
      if (refreshToken) {
        await keychainSafe.setGenericPassword("auth_token", refreshToken, {
          service: "refresh_token",
        });
      }
    } catch (error) {
      console.error("Error saving token:", error);
    }
  }

  async clearTokens(): Promise<void> {
    try {
      await keychainSafe.resetGenericPassword();
      await keychainSafe.resetGenericPassword({ service: "refresh_token" });
    } catch (error) {
      console.error("Error clearing tokens:", error);
    }
  }

  // Request methods
  async get<T>(url: string, config?: any): Promise<T> {
    try {
      const response = await this.client.get<T>(url, config);
      return this.unwrapResponseData(response);
    } catch (error) {
      throw this.handleError(error);
    }
  }

  async post<T>(url: string, data?: any, config?: any): Promise<T> {
    try {
      const response = await this.client.post<T>(url, data, config);
      return this.unwrapResponseData(response);
    } catch (error) {
      throw this.handleError(error);
    }
  }

  async put<T>(url: string, data?: any, config?: any): Promise<T> {
    try {
      const response = await this.client.put<T>(url, data, config);
      return this.unwrapResponseData(response);
    } catch (error) {
      throw this.handleError(error);
    }
  }

  async patch<T>(url: string, data?: any, config?: any): Promise<T> {
    try {
      const response = await this.client.patch<T>(url, data, config);
      return this.unwrapResponseData(response);
    } catch (error) {
      throw this.handleError(error);
    }
  }

  async delete<T>(url: string, config?: any): Promise<T> {
    try {
      const response = await this.client.delete<T>(url, config);
      return this.unwrapResponseData(response);
    } catch (error) {
      throw this.handleError(error);
    }
  }

  // Error handling
  private handleError(error: any): Error {
    if (error.response) {
      const payload = error.response.data;
      const apiError: ApiError = {
        status: error.response.status,
        message:
          payload?.error?.message ||
          payload?.message ||
          "An error occurred",
        errors: payload?.error?.errors || payload?.errors,
      };
      const err = new Error(apiError.message);
      (err as any).apiError = apiError;
      return err;
    } else if (error.request) {
      return new Error("No response from server. Please check your connection.");
    } else {
      return new Error(error.message || "An unknown error occurred");
    }
  }

  // Upload file
  async uploadFile(
    url: string,
    fileUri: string,
    fileName: string
  ): Promise<any> {
    const formData = new FormData();
    formData.append("file", {
      uri: fileUri,
      type: "application/octet-stream",
      name: fileName,
    } as any);

    try {
      return await this.post(url, formData, {
        headers: { "Content-Type": "multipart/form-data" },
      });
    } catch (error) {
      throw this.handleError(error);
    }
  }
}

export default new ApiClient();
