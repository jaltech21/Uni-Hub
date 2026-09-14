import React from "react";
import { AppRegistry } from "react-native";
import { AuthProvider } from "@context/AuthContext";
import { RootNavigator } from "@navigation/RootNavigator";

const App = () => (
  <AuthProvider>
    <RootNavigator />
  </AuthProvider>
);

AppRegistry.registerComponent("UniHub", () => App);
AppRegistry.runApplication("UniHub", {
  rootTag: document.getElementById("root"),
});
