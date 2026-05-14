/**
 * Login Screen
 * User authentication entry point
 */

import React, { useState } from "react";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
} from "react-native";
import { useAuth } from "@context/AuthContext";

export default function LoginScreen({ navigation }: any) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const { login, loading } = useAuth();

  const handleLogin = async () => {
    setError("");
    if (!email || !password) {
      setError("Please fill in all fields");
      return;
    }

    try {
      await login(email, password);
    } catch (err: any) {
      setError(err.message || "Login failed");
    }
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === "ios" ? "padding" : "height"}
      style={{ flex: 1 }}
    >
      <ScrollView contentContainerStyle={{ flex: 1 }} className="bg-white">
        <View className="flex-1 px-6 py-10 justify-center">
          {/* Header */}
          <View className="mb-8">
            <Text className="text-3xl font-bold text-primary-600 mb-2">
              UniHub
            </Text>
            <Text className="text-base text-gray-600">
              Welcome back to your academic hub
            </Text>
          </View>

          {/* Error Message */}
          {error && (
            <View className="bg-red-50 border border-red-200 rounded-lg p-3 mb-6">
              <Text className="text-red-800 text-sm font-medium">{error}</Text>
            </View>
          )}

          {/* Email Input */}
          <View className="mb-4">
            <Text className="text-sm font-medium text-gray-700 mb-2">
              Email
            </Text>
            <TextInput
              style={{
                borderWidth: 1,
                borderColor: "#dee2e6",
                borderRadius: 8,
                paddingHorizontal: 12,
                paddingVertical: 10,
                fontSize: 16,
              }}
              placeholder="Enter your email"
              placeholderTextColor="#adb5bd"
              keyboardType="email-address"
              value={email}
              onChangeText={setEmail}
              editable={!loading}
            />
          </View>

          {/* Password Input */}
          <View className="mb-6">
            <Text className="text-sm font-medium text-gray-700 mb-2">
              Password
            </Text>
            <TextInput
              style={{
                borderWidth: 1,
                borderColor: "#dee2e6",
                borderRadius: 8,
                paddingHorizontal: 12,
                paddingVertical: 10,
                fontSize: 16,
              }}
              placeholder="Enter your password"
              placeholderTextColor="#adb5bd"
              secureTextEntry
              value={password}
              onChangeText={setPassword}
              editable={!loading}
            />
          </View>

          {/* Login Button */}
          <TouchableOpacity
            onPress={handleLogin}
            disabled={loading}
            style={{
              backgroundColor: "#3b5bfd",
              borderRadius: 8,
              paddingVertical: 12,
              alignItems: "center",
              marginBottom: 12,
            }}
          >
            {loading ? (
              <ActivityIndicator color="white" />
            ) : (
              <Text className="text-white font-semibold text-base">Login</Text>
            )}
          </TouchableOpacity>

          {/* Register Link */}
          <View className="flex-row justify-center">
            <Text className="text-gray-600 text-sm">
              Don't have an account?{" "}
            </Text>
            <TouchableOpacity onPress={() => navigation.navigate("Register")}>
              <Text className="text-primary-600 font-semibold text-sm">
                Sign up
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
