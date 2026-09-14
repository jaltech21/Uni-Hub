/**
 * Authentication Service
 * Handles login, logout, registration, and token management
 */

import apiClient from "@services/api";
import { User } from "@app/types";

interface LoginResponse {
  user: User;
  token: string;
  refresh_token: string;
}

interface RegisterPayload {
  first_name: string;
  last_name: string;
  email: string;
  password: string;
  password_confirmation: string;
  role: "student" | "teacher";
  department_id: number;
}

const normalizeAuthResponse = (response: LoginResponse | { data: LoginResponse }) => {
  const payload: LoginResponse = "data" in response ? response.data : response;
  if (!payload.token || !payload.user) {
    throw new Error("Login succeeded but the account data was incomplete. Please try again.");
  }
  return payload;
};

class AuthService {
  async login(email: string, password: string): Promise<LoginResponse> {
    try {
      const rawResponse = await apiClient.post<LoginResponse | { data: LoginResponse }>("/auth/login", {
        email,
        password,
      });
      const response = normalizeAuthResponse(rawResponse);

      // Save tokens
      await apiClient.saveToken(response.token, response.refresh_token);

      return response;
    } catch (error: any) {
      throw new Error(
        error.message || "Login failed. Please check your credentials."
      );
    }
  }

  async logout(): Promise<void> {
    try {
      await apiClient.post("/auth/logout", {});
      await apiClient.clearTokens();
    } catch (error) {
      // Clear tokens even if request fails
      await apiClient.clearTokens();
    }
  }

  async register(userData: RegisterPayload): Promise<LoginResponse> {
    try {
      const rawResponse = await apiClient.post<LoginResponse | { data: LoginResponse }>("/auth/register", {
        user: userData,
      });
      const response = normalizeAuthResponse(rawResponse);

      // Save tokens
      await apiClient.saveToken(response.token, response.refresh_token);

      return response;
    } catch (error: any) {
      throw new Error(
        error.message || "Registration failed. Please try again."
      );
    }
  }

  async getCurrentUser(): Promise<User | null> {
    try {
      const token = await this.getStoredToken();
      if (!token) {
        return null;
      }

      const user = await apiClient.get<User>("/auth/current_user");
      return user;
    } catch (error) {
      return null;
    }
  }

  async getStoredToken(): Promise<string | null> {
    return await apiClient.getStoredToken();
  }

  async refreshToken(): Promise<string> {
    try {
      const refreshToken = await apiClient.getStoredRefreshToken();
      if (!refreshToken) {
        throw new Error("No refresh token available");
      }

      const response = await apiClient.post<{ token: string; refresh_token?: string }>(
        "/auth/refresh",
        {},
        {
          headers: {
            Authorization: `Bearer ${refreshToken}`,
          },
        }
      );

      await apiClient.saveToken(response.token, response.refresh_token);
      return response.token;
    } catch (error: any) {
      await apiClient.clearTokens();
      throw new Error("Token refresh failed. Please login again.");
    }
  }

  async updateProfile(data: Partial<User>): Promise<User> {
    try {
      const user = await apiClient.put<User>("/auth/profile", { user: data });
      return user;
    } catch (error: any) {
      throw new Error(error.message || "Failed to update profile");
    }
  }

  async changePassword(
    currentPassword: string,
    newPassword: string
  ): Promise<void> {
    try {
      await apiClient.post("/auth/change_password", {
        current_password: currentPassword,
        new_password: newPassword,
      });
    } catch (error: any) {
      throw new Error(error.message || "Failed to change password");
    }
  }

  async resetPassword(email: string): Promise<void> {
    try {
      await apiClient.post("/auth/forgot_password", { email });
    } catch (error: any) {
      throw new Error(error.message || "Failed to send reset email");
    }
  }
}

export default new AuthService();
