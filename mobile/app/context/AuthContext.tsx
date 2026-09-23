/**
 * Authentication Context
 * Manages user auth state, token management, and login/logout flows
 */

import React, {
  createContext,
  useReducer,
  useCallback,
  useEffect,
  useRef,
} from "react";
import { AuthState, User } from "@app/types";
import authService from "@services/auth";

interface AuthContextType extends AuthState {
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  register: (userData: any) => Promise<void>;
  checkAuth: () => Promise<void>;
  updateProfile: (data: Partial<User>) => Promise<User>;
  changePassword: (currentPassword: string, newPassword: string) => Promise<void>;
  isAdmin: boolean;
  isTeacher: boolean;
  isStudent: boolean;
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
  const authOperation = useRef(0);

  const isAdmin = state.user?.role === "admin";
  const isTeacher = state.user?.role === "teacher" || state.user?.role === "tutor";
  const isStudent = state.user?.role === "student";

  const login = useCallback(async (email: string, password: string) => {
    authOperation.current += 1;
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
    authOperation.current += 1;
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
    authOperation.current += 1;
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
    const operation = authOperation.current;
    dispatch({ type: "SET_LOADING", payload: true });
    try {
      const response = await authService.getCurrentUser();
      if (operation !== authOperation.current) {
        return;
      }
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
      if (operation !== authOperation.current) {
        return;
      }
      dispatch({ type: "CLEAR_USER" });
    }
  }, []);

  const updateProfile = useCallback(async (data: Partial<User>) => {
    const updated = await authService.updateProfile(data);
    dispatch({ type: "SET_USER", payload: updated, token: state.token || "" });
    return updated;
  }, [state.token]);

  const changePassword = useCallback(
    async (currentPassword: string, newPassword: string) => {
      await authService.changePassword(currentPassword, newPassword);
    },
    []
  );

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
        updateProfile,
        changePassword,
        isAdmin,
        isTeacher,
        isStudent,
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
