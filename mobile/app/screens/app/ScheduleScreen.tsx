/**
 * Schedule Screen - Placeholder
 */

import React from "react";
import { View, Text, ScrollView } from "react-native";

export default function ScheduleScreen() {
  return (
    <ScrollView className="flex-1 bg-gray-50">
      <View className="px-4 py-6">
        <Text className="text-2xl font-bold text-gray-900 mb-1">Schedule</Text>
        <Text className="text-base text-gray-600 mb-8">
          View your classes and events
        </Text>
        <View className="bg-white rounded-lg p-6 items-center">
          <Text className="text-5xl mb-2">📅</Text>
          <Text className="text-base font-semibold text-gray-900">
            No scheduled classes
          </Text>
          <Text className="text-sm text-gray-600 text-center mt-2">
            Enroll in classes to see your schedule
          </Text>
        </View>
      </View>
    </ScrollView>
  );
}
