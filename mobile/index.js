import "./global.css";
import { registerRootComponent } from "expo";
import { AuthProvider } from "./app/context/AuthContext";
import { RootNavigator } from "./app/navigation/RootNavigator";
import { StatusBar } from "expo-status-bar";
import React from "react";
import { GestureHandlerRootView } from "react-native-gesture-handler";

function RootApp() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <AuthProvider>
        <StatusBar barStyle="dark-content" />
        <RootNavigator />
      </AuthProvider>
    </GestureHandlerRootView>
  );
}

registerRootComponent(RootApp);
