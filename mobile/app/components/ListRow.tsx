/**
 * ListRow — single pressable settings/table row with an optional leading icon,
 * trailing glyph, and divider.
 */
import React from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { palette } from "./tokens";

interface ListRowProps {
  icon?: string;
  label: string;
  value?: string;
  onPress?: () => void;
  iconColor?: string;
  iconBg?: string;
  last?: boolean;
}

export default function ListRow({
  icon,
  label,
  value,
  onPress,
  iconColor = palette.primary,
  iconBg = palette.primarySoft,
  last,
}: ListRowProps) {
  const content = (
    <>
      {icon ? (
        <View style={[styles.iconWrap, { backgroundColor: iconBg }]}>
          <Text style={[styles.icon, { color: iconColor }]}>{icon}</Text>
        </View>
      ) : null}
      <Text style={styles.label}>{label}</Text>
      {value ? <Text style={styles.value}>{value}</Text> : null}
      <Text style={styles.chevron}>›</Text>
    </>
  );

  return (
    <View style={!last && styles.divider}>
      {onPress ? (
        <Pressable style={styles.row} onPress={onPress} accessibilityLabel={label}>
          {content}
        </Pressable>
      ) : (
        <View style={styles.row}>{content}</View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  divider: {
    borderBottomColor: palette.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  row: {
    alignItems: "center",
    flexDirection: "row",
    paddingHorizontal: 14,
    paddingVertical: 13,
  },
  iconWrap: {
    alignItems: "center",
    borderRadius: 10,
    height: 38,
    justifyContent: "center",
    marginRight: 12,
    width: 38,
  },
  icon: { fontSize: 18, lineHeight: 22 },
  label: { color: palette.ink, flex: 1, fontSize: 15, fontWeight: "600" },
  value: { color: palette.muted, fontSize: 13, marginRight: 6 },
  chevron: { color: palette.mutedLight, fontSize: 20, lineHeight: 22 },
});