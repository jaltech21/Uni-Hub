/**
 * EmptyState — friendly placeholder for empty lists/screens.
 */
import React from "react";
import { StyleSheet, Text, View } from "react-native";
import { palette } from "./tokens";

interface EmptyStateProps {
  icon?: string;
  title: string;
  text?: string;
}

export default function EmptyState({ icon, title, text }: EmptyStateProps) {
  return (
    <View style={styles.card}>
      {icon ? (
        <View style={styles.iconWrap}>
          <Text style={styles.icon}>{icon}</Text>
        </View>
      ) : null}
      <Text style={styles.title}>{title}</Text>
      {text ? <Text style={styles.text}>{text}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    alignItems: "center",
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 15,
    borderWidth: 1,
    padding: 28,
  },
  iconWrap: {
    alignItems: "center",
    backgroundColor: palette.primarySoft,
    borderRadius: 26,
    height: 52,
    justifyContent: "center",
    width: 52,
  },
  icon: { fontSize: 24 },
  title: {
    color: palette.ink,
    fontSize: 15,
    fontWeight: "800",
    marginTop: 14,
  },
  text: {
    color: palette.muted,
    fontSize: 13,
    lineHeight: 19,
    marginTop: 7,
    textAlign: "center",
  },
});