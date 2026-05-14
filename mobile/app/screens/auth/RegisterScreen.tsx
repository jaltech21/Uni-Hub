/**
 * Register Screen
 * New user registration
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

export default function RegisterScreen({ navigation }: any) {
  const [formData, setFormData] = useState({
    first_name: "",
    last_name: "",
    email: "",
    password: "",
    password_confirmation: "",
    role: "student" as "student" | "teacher",
  });
  const [error, setError] = useState("");
  const { register, loading } = useAuth();

  const handleRegister = async () => {
    setError("");

    if (
      !formData.first_name ||
      !formData.last_name ||
      !formData.email ||
      !formData.password
    ) {
      setError("Please fill in all fields");
      return;
    }

    if (formData.password !== formData.password_confirmation) {
      setError("Passwords do not match");
      return;
    }

    try {
      await register({
        ...formData,
        department_id: 1, // TODO: Add department selection
      });
    } catch (err: any) {
      setError(err.message || "Registration failed");
    }
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === "ios" ? "padding" : "height"}
      style={{ flex: 1 }}
    >
      <ScrollView contentContainerStyle={{ minHeight: "100%" }} className="bg-white">
        <View className="px-6 py-10">
          {/* Header */}
          <View className="mb-6">
            <Text className="text-3xl font-bold text-primary-600 mb-2">
              Join UniHub
            </Text>
            <Text className="text-base text-gray-600">
              Create your account to get started
            </Text>
          </View>

          {/* Error Message */}
          {error && (
            <View className="bg-red-50 border border-red-200 rounded-lg p-3 mb-6">
              <Text className="text-red-800 text-sm font-medium">{error}</Text>
            </View>
          )}

          {/* First Name */}
          <View className="mb-4">
            <Text className="text-sm font-medium text-gray-700 mb-2">
              First Name
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
              placeholder="First name"
              value={formData.first_name}
              onChangeText={(text) =>
                setFormData({ ...formData, first_name: text })
              }
              editable={!loading}
            />
          </View>

          {/* Last Name */}
          <View className="mb-4">
            <Text className="text-sm font-medium text-gray-700 mb-2">
              Last Name
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
              placeholder="Last name"
              value={formData.last_name}
              onChangeText={(text) =>
                setFormData({ ...formData, last_name: text })
              }
              editable={!loading}
            />
          </View>

          {/* Email */}
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
              placeholder="your@email.com"
              keyboardType="email-address"
              value={formData.email}
              onChangeText={(text) =>
                setFormData({ ...formData, email: text })
              }
              editable={!loading}
            />
          </View>

          {/* Role Selection */}
          <View className="mb-4">
            <Text className="text-sm font-medium text-gray-700 mb-2">
              I am a
            </Text>
            <View className="flex-row gap-3">
              {["student", "teacher"].map((role) => (
                <TouchableOpacity
                  key={role}
                  onPress={() =>
                    setFormData({
                      ...formData,
                      role: role as "student" | "teacher",
                    })
                  }
                  style={{
                    flex: 1,
                    borderWidth: 1,
                    borderColor:
                      formData.role === role ? "#3b5bfd" : "#dee2e6",
                    borderRadius: 8,
                    paddingVertical: 10,
                    alignItems: "center",
                    backgroundColor:
                      formData.role === role ? "#f0f4ff" : "transparent",
                  }}
                >
                  <Text
                    style={{
                      color: formData.role === role ? "#3b5bfd" : "#495057",
                      fontWeight: "500",
                      textTransform: "capitalize",
                    }}
                  >
                    {role}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
          </View>

          {/* Password */}
          <View className="mb-4">
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
              placeholder="Create a password"
              secureTextEntry
              value={formData.password}
              onChangeText={(text) =>
                setFormData({ ...formData, password: text })
              }
              editable={!loading}
            />
          </View>

          {/* Confirm Password */}
          <View className="mb-6">
            <Text className="text-sm font-medium text-gray-700 mb-2">
              Confirm Password
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
              placeholder="Confirm your password"
              secureTextEntry
              value={formData.password_confirmation}
              onChangeText={(text) =>
                setFormData({ ...formData, password_confirmation: text })
              }
              editable={!loading}
            />
          </View>

          {/* Register Button */}
          <TouchableOpacity
            onPress={handleRegister}
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
              <Text className="text-white font-semibold text-base">
                Create Account
              </Text>
            )}
          </TouchableOpacity>

          {/* Login Link */}
          <View className="flex-row justify-center">
            <Text className="text-gray-600 text-sm">
              Already have an account?{" "}
            </Text>
            <TouchableOpacity onPress={() => navigation.navigate("Login")}>
              <Text className="text-primary-600 font-semibold text-sm">
                Sign in
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
