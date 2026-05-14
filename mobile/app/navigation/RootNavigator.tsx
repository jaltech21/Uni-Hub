/**
 * Root Navigation
 * Manages auth vs app navigation stacks and screen routing
 */

import React from "react";
import { NavigationContainer } from "@react-navigation/native";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";
import { ActivityIndicator, View } from "react-native";
import { useAuth } from "@context/AuthContext";

// Screens - Auth Stack
import LoginScreen from "@screens/auth/LoginScreen";
import RegisterScreen from "@screens/auth/RegisterScreen";

// Screens - App Stack
import HomeScreen from "@screens/app/HomeScreen";
import NotesScreen from "@screens/app/NotesScreen";
import AssignmentsScreen from "@screens/app/AssignmentsScreen";
import ScheduleScreen from "@screens/app/ScheduleScreen";
import MessagesScreen from "@screens/app/MessagesScreen";
import ProfileScreen from "@screens/app/ProfileScreen";

const Stack = createNativeStackNavigator();
const Tab = createBottomTabNavigator();

const AuthStack = () => (
  <Stack.Navigator
    screenOptions={{
      headerShown: false,
      cardStyle: { backgroundColor: "white" },
    }}
  >
    <Stack.Screen name="Login" component={LoginScreen} />
    <Stack.Screen name="Register" component={RegisterScreen} />
  </Stack.Navigator>
);

const AppTabs = () => (
  <Tab.Navigator
    screenOptions={{
      headerStyle: { backgroundColor: "#3b5bfd" },
      headerTintColor: "#fff",
      headerTitleStyle: { fontWeight: "600" },
      tabBarStyle: {
        borderTopColor: "#e9ecef",
        borderTopWidth: 1,
        backgroundColor: "#fff",
      },
      tabBarLabelStyle: { fontSize: 12, fontWeight: "500" },
      tabBarActiveTintColor: "#3b5bfd",
      tabBarInactiveTintColor: "#adb5bd",
    }}
  >
    <Tab.Screen
      name="Home"
      component={HomeScreen}
      options={{
        title: "Home",
        tabBarLabel: "Home",
      }}
    />
    <Tab.Screen
      name="Notes"
      component={NotesScreen}
      options={{
        title: "Notes",
        tabBarLabel: "Notes",
      }}
    />
    <Tab.Screen
      name="Assignments"
      component={AssignmentsScreen}
      options={{
        title: "Assignments",
        tabBarLabel: "Assignments",
      }}
    />
    <Tab.Screen
      name="Schedule"
      component={ScheduleScreen}
      options={{
        title: "Schedule",
        tabBarLabel: "Schedule",
      }}
    />
    <Tab.Screen
      name="Messages"
      component={MessagesScreen}
      options={{
        title: "Messages",
        tabBarLabel: "Messages",
      }}
    />
    <Tab.Screen
      name="Profile"
      component={ProfileScreen}
      options={{
        title: "Profile",
        tabBarLabel: "Profile",
      }}
    />
  </Tab.Navigator>
);

export const RootNavigator = () => {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <View style={{ flex: 1, justifyContent: "center", alignItems: "center" }}>
        <ActivityIndicator size="large" color="#3b5bfd" />
      </View>
    );
  }

  return (
    <NavigationContainer>
      {user ? <AppTabs /> : <AuthStack />}
    </NavigationContainer>
  );
};
