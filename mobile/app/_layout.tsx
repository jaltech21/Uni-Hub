import React from "react";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { AuthProvider } from "@context/AuthContext";
import { RootNavigator } from "@navigation/RootNavigator";
import { StatusBar } from "expo-status-bar";

export default function RootLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <AuthProvider>
        <StatusBar barStyle="dark-content" />
        <RootNavigator />
      </AuthProvider>
    </GestureHandlerRootView>
  );
}
