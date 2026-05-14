/**
 * Profile Screen - Placeholder
 */

import React from "react";
import { View, Text, ScrollView, TouchableOpacity } from "react-native";
import { useAuth } from "@context/AuthContext";

export default function ProfileScreen() {
  const { user, logout } = useAuth();

  const handleLogout = async () => {
    await logout();
  };

  return (
    <ScrollView className="flex-1 bg-gray-50">
      <View className="px-4 py-6">
        <Text className="text-2xl font-bold text-gray-900 mb-6">Profile</Text>

        {/* User Info Card */}
        <View className="bg-white rounded-lg p-4 mb-4">
          <Text className="text-base font-semibold text-gray-900">
            {user?.first_name} {user?.last_name}
          </Text>
          <Text className="text-sm text-gray-600 mt-1">{user?.email}</Text>
          <Text className="text-sm text-primary-600 mt-2 capitalize font-medium">
            {user?.role}
          </Text>
        </View>

        {/* Settings Section */}
        <View className="bg-white rounded-lg p-4 mb-4">
          <Text className="text-base font-semibold text-gray-900 mb-3">
            Settings
          </Text>
          <TouchableOpacity style={{ paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: "#e9ecef" }}>
            <Text className="text-base text-gray-700">Edit Profile</Text>
          </TouchableOpacity>
          <TouchableOpacity style={{ paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: "#e9ecef" }}>
            <Text className="text-base text-gray-700">Change Password</Text>
          </TouchableOpacity>
          <TouchableOpacity style={{ paddingVertical: 12 }}>
            <Text className="text-base text-gray-700">Notifications</Text>
          </TouchableOpacity>
        </View>

        {/* Logout Button */}
        <TouchableOpacity
          onPress={handleLogout}
          style={{
            backgroundColor: "#f04438",
            borderRadius: 8,
            paddingVertical: 12,
            alignItems: "center",
          }}
        >
          <Text className="text-white font-semibold text-base">Logout</Text>
        </TouchableOpacity>
      </View>
    </ScrollView>
  );
}
