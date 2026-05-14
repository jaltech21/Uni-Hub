/**
 * API Client Service
 * Centralized HTTP client with authentication, error handling, and interceptors
 */

import axios, { AxiosInstance, AxiosError, AxiosResponse } from "axios";
import * as Keychain from "react-native-keychain";
import { ApiResponse, ApiError } from "@types";

const API_BASE_URL =
  process.env.EXPO_PUBLIC_API_URL || "http://localhost:3000/api/v1";

class ApiClient {
  private client: AxiosInstance;
  private isRefreshing = false;
  private refreshSubscribers: Array<(token: string) => void> = [];

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
        const token = await this.getStoredToken();
        if (token) {
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

        if (error.response?.status === 401 && !originalRequest._retry) {
          originalRequest._retry = true;

          if (!this.isRefreshing) {
            this.isRefreshing = true;
            try {
              const refreshToken = await this.getStoredRefreshToken();
              if (refreshToken) {
                const response = await axios.post(
                  `${API_BASE_URL}/auth/refresh_token`,
                  { refresh_token: refreshToken }
                );
                const newToken = response.data.token;
                await this.saveToken(newToken);

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
      const credentials = await Keychain.getGenericPassword();
      return credentials ? credentials.password : null;
    } catch (error) {
      console.error("Error retrieving token:", error);
      return null;
    }
  }

  async getStoredRefreshToken(): Promise<string | null> {
    try {
      const credentials = await Keychain.getGenericPassword({
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
      await Keychain.setGenericPassword("auth_token", token);
      if (refreshToken) {
        await Keychain.setGenericPassword("auth_token", refreshToken, {
          service: "refresh_token",
        });
      }
    } catch (error) {
      console.error("Error saving token:", error);
    }
  }

  async clearTokens(): Promise<void> {
    try {
      await Keychain.resetGenericPassword();
      await Keychain.resetGenericPassword({ service: "refresh_token" });
    } catch (error) {
      console.error("Error clearing tokens:", error);
    }
  }

  // Request methods
  async get<T>(url: string, config?: any): Promise<T> {
    try {
      const response = await this.client.get<T>(url, config);
      return response.data;
    } catch (error) {
      throw this.handleError(error);
    }
  }

  async post<T>(url: string, data?: any, config?: any): Promise<T> {
    try {
      const response = await this.client.post<T>(url, data, config);
      return response.data;
    } catch (error) {
      throw this.handleError(error);
    }
  }

  async put<T>(url: string, data?: any, config?: any): Promise<T> {
    try {
      const response = await this.client.put<T>(url, data, config);
      return response.data;
    } catch (error) {
      throw this.handleError(error);
    }
  }

  async patch<T>(url: string, data?: any, config?: any): Promise<T> {
    try {
      const response = await this.client.patch<T>(url, data, config);
      return response.data;
    } catch (error) {
      throw this.handleError(error);
    }
  }

  async delete<T>(url: string, config?: any): Promise<T> {
    try {
      const response = await this.client.delete<T>(url, config);
      return response.data;
    } catch (error) {
      throw this.handleError(error);
    }
  }

  // Error handling
  private handleError(error: any): Error {
    if (error.response) {
      const apiError: ApiError = {
        status: error.response.status,
        message: error.response.data?.message || "An error occurred",
        errors: error.response.data?.errors,
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
