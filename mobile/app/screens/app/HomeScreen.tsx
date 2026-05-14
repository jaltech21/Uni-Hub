/**
 * Home Screen
 * Main dashboard for students and teachers
 */

import React from "react";
import { View, Text, ScrollView } from "react-native";
import { useAuth } from "@context/AuthContext";

export default function HomeScreen() {
  const { user } = useAuth();

  return (
    <ScrollView className="flex-1 bg-gray-50">
      <View className="px-4 py-6">
        {/* Header */}
        <Text className="text-2xl font-bold text-gray-900 mb-1">
          Welcome, {user?.first_name}!
        </Text>
        <Text className="text-base text-gray-600 mb-8">
          Here's your academic overview
        </Text>

        {/* Widgets - Placeholder */}
        <View className="bg-white rounded-lg p-4 mb-4">
          <Text className="text-base font-semibold text-gray-900">
            📋 Upcoming Classes
          </Text>
          <Text className="text-sm text-gray-600 mt-2">
            Loading your schedule...
          </Text>
        </View>

        <View className="bg-white rounded-lg p-4 mb-4">
          <Text className="text-base font-semibold text-gray-900">
            📝 Pending Assignments
          </Text>
          <Text className="text-sm text-gray-600 mt-2">
            You have no pending assignments
          </Text>
        </View>

        <View className="bg-white rounded-lg p-4 mb-4">
          <Text className="text-base font-semibold text-gray-900">
            📚 Recent Notes
          </Text>
          <Text className="text-sm text-gray-600 mt-2">
            Start creating notes to see them here
          </Text>
        </View>
      </View>
    </ScrollView>
  );
}
