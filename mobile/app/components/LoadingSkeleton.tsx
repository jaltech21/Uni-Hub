/**
 * LoadingSkeleton — shimmer-free placeholder rows while data loads.
 */
import React from "react";
import { StyleSheet, View } from "react-native";
import { palette, radius } from "./tokens";

export default function LoadingSkeleton() {
  return (
    <View style={styles.card}>
      {[0, 1, 2].map((i) => (
        <View key={i} style={[styles.row, i > 0 && styles.divider]}>
          <View style={styles.avatar} />
          <View style={styles.body}>
            <View style={styles.lineWide} />
            <View style={styles.lineNarrow} />
          </View>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: radius.lg,
    borderWidth: 1,
    overflow: "hidden",
  },
  row: { flexDirection: "row", padding: 14 },
  divider: { borderTopColor: palette.border, borderTopWidth: StyleSheet.hairlineWidth },
  avatar: {
    backgroundColor: "#eef1f7",
    borderRadius: 11,
    height: 40,
    marginRight: 12,
    width: 40,
  },
  body: { flex: 1, justifyContent: "center" },
  lineWide: {
    backgroundColor: "#eef1f7",
    borderRadius: 4,
    height: 14,
    marginBottom: 7,
    width: "80%",
  },
  lineNarrow: {
    backgroundColor: "#f2f4f8",
    borderRadius: 4,
    height: 11,
    width: "55%",
  },
});