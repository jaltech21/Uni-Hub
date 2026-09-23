/**
 * ScreenHeader — eyebrow/title/subtitle section heading used at the top of
 * every tab screen for a consistent layout and voice.
 */
import React from "react";
import { StyleSheet, Text, View } from "react-native";
import { palette } from "./tokens";

interface ScreenHeaderProps {
  eyebrow?: string;
  title: string;
  subtitle?: string;
}

export default function ScreenHeader({ eyebrow, title, subtitle }: ScreenHeaderProps) {
  return (
    <View style={styles.wrap}>
      {eyebrow ? <Text style={styles.eyebrow}>{eyebrow}</Text> : null}
      <Text style={styles.title}>{title}</Text>
      {subtitle ? <Text style={styles.subtitle}>{subtitle}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { marginBottom: 18, marginTop: 8 },
  eyebrow: {
    color: palette.primary,
    fontSize: 11,
    fontWeight: "800",
    letterSpacing: 1.2,
  },
  title: { color: palette.ink, fontSize: 27, fontWeight: "800", marginTop: 4 },
  subtitle: { color: palette.muted, fontSize: 13, marginTop: 4 },
});