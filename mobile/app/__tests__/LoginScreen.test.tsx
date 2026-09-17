import React from "react";
import { render, fireEvent, waitFor } from "@testing-library/react-native";
import AsyncStorage from "@react-native-async-storage/async-storage";

import LoginScreen from "@screens/auth/LoginScreen";

const mockLogin = jest.fn();

jest.mock("@context/AuthContext", () => ({
  useAuth: () => ({
    user: null,
    token: null,
    loading: false,
    error: null,
    login: mockLogin,
    logout: jest.fn(),
    register: jest.fn(),
    checkAuth: jest.fn(),
  }),
}));

// The first render pays the nativewind/babel transform cost under jest-expo.
jest.setTimeout(120000);

const ONBOARDING_KEY = "@unihub/onboarding-complete";

const navigation = { navigate: jest.fn() };

const completeOnboarding = () => AsyncStorage.setItem(ONBOARDING_KEY, "true");

const renderLoginForm = async () => {
  await completeOnboarding();
  const utils = render(<LoginScreen navigation={navigation} />);
  await utils.findByText("Welcome back");
  return utils;
};

describe("LoginScreen", () => {
  beforeEach(async () => {
    jest.clearAllMocks();
    await AsyncStorage.clear();
  });

  describe("onboarding UI rendering", () => {
    it("renders the welcome hero for first-time users", async () => {
      const { findByText, getByText, getAllByText } = render(
        <LoginScreen navigation={navigation} />
      );

      expect(await findByText("Get Started")).toBeTruthy();
      expect(getByText("Learn. Connect.\nAchieve.")).toBeTruthy();
      expect(getAllByText("UniHub").length).toBeGreaterThan(0);
    });

it("walks from welcome to the login form via onboarding", async () => {
      const { findByText, getByText } = render(
        <LoginScreen navigation={navigation} />
      );

      fireEvent.press(await findByText("Get Started"));

      expect(await findByText("Study with\nconfidence.")).toBeTruthy();
      fireEvent.press(getByText("Continue"));

      expect(await findByText("Welcome back")).toBeTruthy();
      expect(getByText("Sign in to continue your UniHub journey.")).toBeTruthy();
    });

    it("skips onboarding when it was already completed", async () => {
      const { findByText, queryByText } = await renderLoginForm();

      expect(await findByText("Sign In")).toBeTruthy();
      expect(queryByText("Get Started")).toBeNull();
    });
  });

  describe("login form rendering", () => {
    it("renders all expected fields, actions and footer links", async () => {
      const { getByLabelText, getByText } = await renderLoginForm();

      expect(getByLabelText("University email")).toBeTruthy();
      expect(getByLabelText("Password")).toBeTruthy();
      expect(getByText("Sign In")).toBeTruthy();
      expect(getByText("Forgot password?")).toBeTruthy();
      expect(getByText("Create an account")).toBeTruthy();
      expect(getByText("STUDENT PORTAL")).toBeTruthy();
    });
  });

  describe("login behaviour", () => {
    it("shows a validation error when fields are empty", async () => {
      const { getByText, findByText } = await renderLoginForm();

      fireEvent.press(getByText("Sign In"));

      expect(
        await findByText("Enter your university email and password to continue.")
      ).toBeTruthy();
      expect(mockLogin).not.toHaveBeenCalled();
    });

    it("submits trimmed credentials through the auth context", async () => {
      mockLogin.mockResolvedValueOnce(undefined);
      const { getByLabelText, getByText } = await renderLoginForm();

      fireEvent.changeText(
        getByLabelText("University email"),
        "  student@unimtech.edu  "
      );
      fireEvent.changeText(getByLabelText("Password"), "secret123");
      fireEvent.press(getByText("Sign In"));

      await waitFor(() => {
        expect(mockLogin).toHaveBeenCalledTimes(1);
      });
      expect(mockLogin).toHaveBeenCalledWith("student@unimtech.edu", "secret123");
    });

    it("renders the API error when login is rejected", async () => {
      mockLogin.mockRejectedValueOnce(new Error("Invalid email or password."));
      const { getByLabelText, getByText, findByText } = await renderLoginForm();

      fireEvent.changeText(getByLabelText("University email"), "student@unimtech.edu");
      fireEvent.changeText(getByLabelText("Password"), "wrong");
      fireEvent.press(getByText("Sign In"));

      expect(await findByText("Invalid email or password.")).toBeTruthy();
    });
  });

  describe("navigation", () => {
    it("links to the register screen", async () => {
      const { getByText } = await renderLoginForm();

      fireEvent.press(getByText("Create an account"));

      expect(navigation.navigate).toHaveBeenCalledWith("Register");
    });
  });
});
