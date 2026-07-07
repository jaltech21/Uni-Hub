import React from "react";
import { AppRegistry, View, Text } from "react-native";
import { AuthProvider } from "@context/AuthContext";
import LoginScreen from "@screens/auth/LoginScreen";

const App = () => (
  <AuthProvider>
    <LoginScreen navigation={null} />
  </AuthProvider>
);

AppRegistry.registerComponent("UniHub", () => App);
AppRegistry.runApplication("UniHub", {
  rootTag: document.getElementById("root"),
});
