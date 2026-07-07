/**
 * Authentication Context
 * Manages user auth state, token management, and login/logout flows
 */

import React, { createContext, useReducer, useCallback, useEffect } from "react";
import { AuthState, User } from "@types";
import authService from "@services/auth";

interface AuthContextType extends AuthState {
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  register: (userData: any) => Promise<void>;
  checkAuth: () => Promise<void>;
}

const initialState: AuthState = {
  user: null,
  token: null,
  loading: true,
  error: null,
};

type AuthAction =
  | { type: "SET_LOADING"; payload: boolean }
  | { type: "SET_USER"; payload: User; token: string }
  | { type: "CLEAR_USER" }
  | { type: "SET_ERROR"; payload: string | null };

const authReducer = (state: AuthState, action: AuthAction): AuthState => {
  switch (action.type) {
    case "SET_LOADING":
      return { ...state, loading: action.payload };
    case "SET_USER":
      return {
        ...state,
        user: action.payload,
        token: action.token,
        loading: false,
        error: null,
      };
    case "CLEAR_USER":
      return { ...state, user: null, token: null, loading: false };
    case "SET_ERROR":
      return { ...state, error: action.payload, loading: false };
    default:
      return state;
  }
};

export const AuthContext = createContext<AuthContextType | undefined>(
  undefined
);

interface AuthProviderProps {
  children: React.ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  const [state, dispatch] = useReducer(authReducer, initialState);

  const login = useCallback(async (email: string, password: string) => {
    dispatch({ type: "SET_LOADING", payload: true });
    try {
      const response = await authService.login(email, password);
      dispatch({
        type: "SET_USER",
        payload: response.user,
        token: response.token,
      });
    } catch (error: any) {
      dispatch({
        type: "SET_ERROR",
        payload: error.message || "Login failed",
      });
      throw error;
    }
  }, []);

  const logout = useCallback(async () => {
    try {
      await authService.logout();
      dispatch({ type: "CLEAR_USER" });
    } catch (error: any) {
      dispatch({
        type: "SET_ERROR",
        payload: error.message || "Logout failed",
      });
    }
  }, []);

  const register = useCallback(async (userData: any) => {
    dispatch({ type: "SET_LOADING", payload: true });
    try {
      const response = await authService.register(userData);
      dispatch({
        type: "SET_USER",
        payload: response.user,
        token: response.token,
      });
    } catch (error: any) {
      dispatch({
        type: "SET_ERROR",
        payload: error.message || "Registration failed",
      });
      throw error;
    }
  }, []);

  const checkAuth = useCallback(async () => {
    dispatch({ type: "SET_LOADING", payload: true });
    try {
      const response = await authService.getCurrentUser();
      if (response) {
        const token = await authService.getStoredToken();
        dispatch({
          type: "SET_USER",
          payload: response,
          token: token || "",
        });
      } else {
        dispatch({ type: "CLEAR_USER" });
      }
    } catch (error) {
      dispatch({ type: "CLEAR_USER" });
    }
  }, []);

  // Check auth on app startup
  useEffect(() => {
    checkAuth();
  }, [checkAuth]);

  return (
    <AuthContext.Provider
      value={{
        ...state,
        login,
        logout,
        register,
        checkAuth,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = React.useContext(AuthContext);
  if (context === undefined) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
};
