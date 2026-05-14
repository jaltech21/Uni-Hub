/**
 * Notes Screen - Placeholder
 */

import React from "react";
import { View, Text, ScrollView } from "react-native";

export default function NotesScreen() {
  return (
    <ScrollView className="flex-1 bg-gray-50">
      <View className="px-4 py-6">
        <Text className="text-2xl font-bold text-gray-900 mb-1">Notes</Text>
        <Text className="text-base text-gray-600 mb-8">
          Manage and summarize your notes
        </Text>
        <View className="bg-white rounded-lg p-6 items-center">
          <Text className="text-5xl mb-2">📝</Text>
          <Text className="text-base font-semibold text-gray-900">
            No notes yet
          </Text>
          <Text className="text-sm text-gray-600 text-center mt-2">
            Create your first note to get started
          </Text>
        </View>
      </View>
    </ScrollView>
  );
}
