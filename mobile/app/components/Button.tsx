/**
 * Button — primary/secondary/danger action button with loading state.
 */
import React from "react";
import { ActivityIndicator, Pressable, StyleSheet, Text } from "react-native";
import { palette, radius } from "./tokens";

type Variant = "primary" | "secondary" | "danger";

interface ButtonProps {
  title: string;
  onPress: () => void;
  variant?: Variant;
  loading?: boolean;
  disabled?: boolean;
}

const background: Record<Variant, string> = {
  primary: palette.primary,
  secondary: palette.primarySoft,
  danger: palette.danger,
};

const foreground: Record<Variant, string> = {
  primary: "#ffffff",
  secondary: palette.primary,
  danger: "#ffffff",
};

export default function Button({
  title,
  onPress,
  variant = "primary",
  loading,
  disabled,
}: ButtonProps) {
  const isDisabled = disabled || loading;
  return (
    <Pressable
      style={[
        styles.base,
        { backgroundColor: background[variant] },
        isDisabled && styles.disabled,
      ]}
      onPress={onPress}
      disabled={isDisabled}
      accessibilityLabel={title}
    >
      {loading ? (
        <ActivityIndicator color={foreground[variant]} />
      ) : (
        <Text style={[styles.text, { color: foreground[variant] }]}>{title}</Text>
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: {
    alignItems: "center",
    borderRadius: radius.md,
    justifyContent: "center",
    minHeight: 50,
    paddingHorizontal: 18,
  },
  disabled: { opacity: 0.6 },
  text: { fontSize: 15, fontWeight: "800" },
});