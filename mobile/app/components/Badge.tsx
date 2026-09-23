/**
 * Badge — small pill for roles/status/priorities.
 */
import React from "react";
import { StyleSheet, Text, View } from "react-native";
import { palette, radius } from "./tokens";

type Tone = "primary" | "green" | "orange" | "danger" | "muted";

interface BadgeProps {
  label: string;
  tone?: Tone;
}

const toneStyles: Record<Tone, { bg: string; fg: string }> = {
  primary: { bg: palette.primary, fg: "#ffffff" },
  green: { bg: palette.green, fg: "#ffffff" },
  orange: { bg: palette.orange, fg: "#ffffff" },
  danger: { bg: palette.danger, fg: "#ffffff" },
  muted: { bg: palette.background, fg: palette.muted },
};

export default function Badge({ label, tone = "muted" }: BadgeProps) {
  const colors = toneStyles[tone];
  return (
    <View style={[styles.base, { backgroundColor: colors.bg }]}>
      <Text style={[styles.text, { color: colors.fg }]}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  base: {
    alignSelf: "flex-start",
    borderRadius: radius.pill,
    paddingHorizontal: 10,
    paddingVertical: 4,
  },
  text: { fontSize: 11, fontWeight: "800" },
});