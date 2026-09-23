/**
 * StatCard — compact metric tile (icon, value, label) for dashboards.
 */
import React from "react";
import { StyleSheet, Text, View } from "react-native";
import { palette } from "./tokens";

type Tone = "blue" | "green" | "orange";

interface StatCardProps {
  icon: string;
  label: string;
  value: number;
  tone?: Tone;
}

const toneMap: Record<Tone, { icon: string; bg: string }> = {
  blue: { icon: palette.primary, bg: palette.primarySoft },
  green: { icon: palette.green, bg: palette.greenSoft },
  orange: { icon: palette.orange, bg: palette.orangeSoft },
};

export default function StatCard({ icon, label, value, tone = "blue" }: StatCardProps) {
  const paletteForTone = toneMap[tone];
  return (
    <View style={styles.card}>
      <View style={[styles.iconWrap, { backgroundColor: paletteForTone.bg }]}>
        <Text style={[styles.icon, { color: paletteForTone.icon }]}>{icon}</Text>
      </View>
      <Text style={styles.value}>{value}</Text>
      <Text style={styles.label}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 15,
    borderWidth: 1,
    flex: 1,
    padding: 12,
  },
  iconWrap: {
    alignItems: "center",
    borderRadius: 9,
    height: 34,
    justifyContent: "center",
    width: 34,
  },
  icon: { fontSize: 20, lineHeight: 23 },
  value: { color: palette.ink, fontSize: 22, fontWeight: "800", marginTop: 10 },
  label: { color: palette.muted, fontSize: 11, marginTop: 2 },
});