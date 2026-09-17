/**
 * Root Navigation
 * Manages auth vs app navigation stacks with role-based tab rendering.
 * - Admin users get the Admin tab set (Dashboard, Users, Departments, Courses, Schedules, Announcements)
 * - Students and teachers get the standard tab set (Home, Notes, Assignments, Schedule, Messages, AI, Profile)
 */

import React from "react";
import { NavigationContainer } from "@react-navigation/native";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";
import { ActivityIndicator, Text, View } from "react-native";
import { useAuth } from "@context/AuthContext";

// ── Auth screens ─────────────────────────────────────────────────
import LoginScreen from "@screens/auth/LoginScreen";
import RegisterScreen from "@screens/auth/RegisterScreen";

// ── Standard app screens ─────────────────────────────────────────
import HomeScreen from "@screens/app/HomeScreen";
import NotesScreen from "@screens/app/NotesScreen";
import AssignmentsScreen from "@screens/app/AssignmentsScreen";
import ScheduleScreen from "@screens/app/ScheduleScreen";
import MessagesScreen from "@screens/app/MessagesScreen";
import ProfileScreen from "@screens/app/ProfileScreen";
import AIAssistantScreen from "@screens/app/AIAssistantScreen";

// ── Admin screens ─────────────────────────────────────────────────
import AdminDashboardScreen from "@screens/admin/AdminDashboardScreen";
import AdminUsersScreen from "@screens/admin/AdminUsersScreen";
import AdminDepartmentsScreen from "@screens/admin/AdminDepartmentsScreen";
import AdminCoursesScreen from "@screens/admin/AdminCoursesScreen";
import AdminSchedulesScreen from "@screens/admin/AdminSchedulesScreen";
import AdminAnnouncementsScreen from "@screens/admin/AdminAnnouncementsScreen";

const Stack = createNativeStackNavigator();
const Tab = createBottomTabNavigator();

// ── Shared tab bar config ─────────────────────────────────────────
const tabBarScreenOptions = {
  headerStyle: { backgroundColor: "#ffffff" },
  headerTintColor: "#172033",
  headerTitleStyle: { fontSize: 18, fontWeight: "800" as const },
  tabBarStyle: {
    borderTopColor: "#e9ecef",
    borderTopWidth: 1,
    backgroundColor: "#ffffff",
    height: 68,
    paddingBottom: 8,
    paddingTop: 8,
  },
  tabBarLabelStyle: { fontSize: 11, fontWeight: "600" as const },
  tabBarActiveTintColor: "#3b5bfd",
  tabBarInactiveTintColor: "#adb5bd",
};

// ── Auth stack ────────────────────────────────────────────────────
const AuthStack = () => (
  <Stack.Navigator screenOptions={{ headerShown: false }}>
    <Stack.Screen name="Login" component={LoginScreen} />
    <Stack.Screen name="Register" component={RegisterScreen} />
  </Stack.Navigator>
);

// ── Standard tabs (student + teacher) ────────────────────────────
const AppTabs = () => (
  <Tab.Navigator screenOptions={tabBarScreenOptions}>
    <Tab.Screen
      name="Home"
      component={HomeScreen}
      options={{
        title: "Home",
        tabBarLabel: "Home",
        tabBarIcon: ({ color }: { color: string }) => (
          <Text style={{ color, fontSize: 20 }}>&#8962;</Text>
        ),
      }}
    />
    <Tab.Screen
      name="Notes"
      component={NotesScreen}
      options={{
        title: "Notes",
        tabBarLabel: "Notes",
        tabBarIcon: ({ color }: { color: string }) => (
          <Text style={{ color, fontSize: 20 }}>&#9636;</Text>
        ),
      }}
    />
    <Tab.Screen
      name="Assignments"
      component={AssignmentsScreen}
      options={{
        title: "Assignments",
        tabBarLabel: "Tasks",
        tabBarIcon: ({ color }: { color: string }) => (
          <Text style={{ color, fontSize: 20 }}>&#10003;</Text>
        ),
      }}
    />
    <Tab.Screen
      name="Schedule"
      component={ScheduleScreen}
      options={{
        title: "Schedule",
        tabBarLabel: "Schedule",
        tabBarIcon: ({ color }: { color: string }) => (
          <Text style={{ color, fontSize: 20 }}>&#9633;</Text>
        ),
      }}
    />
    <Tab.Screen
      name="Messages"
      component={MessagesScreen}
      options={{
        title: "Messages",
        tabBarLabel: "Messages",
        tabBarIcon: ({ color }: { color: string }) => (
          <Text style={{ color, fontSize: 20 }}>&#9993;</Text>
        ),
      }}
    />
    <Tab.Screen
      name="AI"
      component={AIAssistantScreen}
      options={{
        title: "UniHub AI",
        tabBarLabel: "AI",
        tabBarIcon: ({ color }: { color: string }) => (
          <Text style={{ color, fontSize: 15, fontWeight: "800" }}>AI</Text>
        ),
      }}
    />
    <Tab.Screen
      name="Profile"
      component={ProfileScreen}
      options={{
        title: "Profile",
        tabBarLabel: "Profile",
        tabBarIcon: ({ color }: { color: string }) => (
          <Text style={{ color, fontSize: 20 }}>&#9711;</Text>
        ),
      }}
    />
  </Tab.Navigator>
);

// ── Admin tabs ────────────────────────────────────────────────────
const AdminTabs = () => (
  <Tab.Navigator
    screenOptions={{
      ...tabBarScreenOptions,
      tabBarActiveTintColor: "#d92d20",
      headerStyle: { backgroundColor: "#172033" },
      headerTintColor: "#ffffff",
      headerTitleStyle: { fontSize: 18, fontWeight: "800" as const, color: "#ffffff" },
    }}
  >
    <Tab.Screen
      name="AdminDashboard"
      component={AdminDashboardScreen}
      options={{
        title: "Admin Dashboard",
        tabBarLabel: "Dashboard",
        tabBarIcon: ({ color }: { color: string }) => (
          <Text style={{ color, fontSize: 18 }}>&#9636;</Text>
        ),
      }}
    />
    <Tab.Screen
      name="AdminUsers"
      component={AdminUsersScreen}
      options={{
        title: "Users",
        tabBarLabel: "Users",
        tabBarIcon: ({ color }: { color: string }) => (
          <Text style={{ color, fontSize: 18 }}>&#9711;</Text>
        ),
      }}
    />
    <Tab.Screen
      name="AdminDepartments"
      component={AdminDepartmentsScreen}
      options={{
        title: "Departments",
        tabBarLabel: "Depts",
        tabBarIcon: ({ color }: { color: string }) => (
          <Text style={{ color, fontSize: 18 }}>&#9962;</Text>
        ),
      }}
    />
    <Tab.Screen
      name="AdminCourses"
      component={AdminCoursesScreen}
      options={{
        title: "Courses",
        tabBarLabel: "Courses",
        tabBarIcon: ({ color }: { color: string }) => (
          <Text style={{ color, fontSize: 16, fontWeight: "700" }}>Co</Text>
        ),
      }}
    />
    <Tab.Screen
      name="AdminSchedules"
      component={AdminSchedulesScreen}
      options={{
        title: "Schedules",
        tabBarLabel: "Schedules",
        tabBarIcon: ({ color }: { color: string }) => (
          <Text style={{ color, fontSize: 18 }}>&#128197;</Text>
        ),
      }}
    />
    <Tab.Screen
      name="AdminAnnouncements"
      component={AdminAnnouncementsScreen}
      options={{
        title: "Announcements",
        tabBarLabel: "Notices",
        tabBarIcon: ({ color }: { color: string }) => (
          <Text style={{ color, fontSize: 18 }}>&#128226;</Text>
        ),
      }}
    />
  </Tab.Navigator>
);

// ── Root navigator ────────────────────────────────────────────────
export const RootNavigator = () => {
  const { user, loading, isAdmin } = useAuth();

  if (loading) {
    return (
      <View style={{ flex: 1, justifyContent: "center", alignItems: "center" }}>
        <ActivityIndicator size="large" color="#3b5bfd" />
      </View>
    );
  }

  return (
    <NavigationContainer>
      {user ? isAdmin ? <AdminTabs /> : <AppTabs /> : <AuthStack />}
    </NavigationContainer>
  );
};
