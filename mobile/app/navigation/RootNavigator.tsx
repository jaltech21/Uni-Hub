/**
 * Root Navigation
 * Manages auth vs app navigation stacks and screen routing
 */

import React from "react";
import { NavigationContainer } from "@react-navigation/native";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";
import { ActivityIndicator, View } from "react-native";
import { Text } from "react-native";
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
import AIAssistantScreen from "@screens/app/AIAssistantScreen";

const Stack = createNativeStackNavigator();
const Tab = createBottomTabNavigator();

const AuthStack = () => (
  <Stack.Navigator
    screenOptions={{
      headerShown: false,
    }}
  >
    <Stack.Screen name="Login" component={LoginScreen} />
    <Stack.Screen name="Register" component={RegisterScreen} />
  </Stack.Navigator>
);

const AppTabs = () => (
  <Tab.Navigator
    screenOptions={{
      headerStyle: { backgroundColor: "#ffffff" },
      headerTintColor: "#172033",
      headerTitleStyle: { fontSize: 18, fontWeight: "800" },
      tabBarStyle: {
        borderTopColor: "#e9ecef",
        borderTopWidth: 1,
        backgroundColor: "#ffffff",
        height: 68,
        paddingBottom: 8,
        paddingTop: 8,
      },
      tabBarLabelStyle: { fontSize: 11, fontWeight: "600" },
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
        tabBarIcon: ({ color }) => <Text style={{ color, fontSize: 20 }}>⌂</Text>,
      }}
    />
    <Tab.Screen
      name="Notes"
      component={NotesScreen}
      options={{
        title: "Notes",
        tabBarLabel: "Notes",
        tabBarIcon: ({ color }) => <Text style={{ color, fontSize: 20 }}>▤</Text>,
      }}
    />
    <Tab.Screen
      name="Assignments"
      component={AssignmentsScreen}
      options={{
        title: "Assignments",
        tabBarLabel: "Assignments",
        tabBarIcon: ({ color }) => <Text style={{ color, fontSize: 20 }}>✓</Text>,
      }}
    />
    <Tab.Screen
      name="Schedule"
      component={ScheduleScreen}
      options={{
        title: "Schedule",
        tabBarLabel: "Schedule",
        tabBarIcon: ({ color }) => <Text style={{ color, fontSize: 20 }}>□</Text>,
      }}
    />
    <Tab.Screen
      name="Messages"
      component={MessagesScreen}
      options={{
        title: "Messages",
        tabBarLabel: "Messages",
        tabBarIcon: ({ color }) => <Text style={{ color, fontSize: 20 }}>✉</Text>,
      }}
    />
    <Tab.Screen
      name="Profile"
      component={ProfileScreen}
      options={{
        title: "Profile",
        tabBarLabel: "Profile",
        tabBarIcon: ({ color }) => <Text style={{ color, fontSize: 20 }}>◯</Text>,
      }}
    />
    <Tab.Screen
      name="AI"
      component={AIAssistantScreen}
      options={{
        title: "UniHub AI",
        tabBarLabel: "AI",
        tabBarIcon: ({ color }) => <Text style={{ color, fontSize: 16, fontWeight: "800" }}>AI</Text>,
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
