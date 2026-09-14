import React from "react";
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { useAuth } from "@context/AuthContext";

const colors = {
  ink: "#172033",
  muted: "#667085",
  surface: "#ffffff",
  background: "#f5f7fb",
  primary: "#3b5bfd",
  lavender: "#eef0ff",
  green: "#0e9f6e",
  greenSoft: "#e8f8f1",
  orange: "#d97706",
  orangeSoft: "#fff5e6",
  border: "#e7eaf2",
};

const StatCard = ({
  icon,
  label,
  value,
  tone,
}: {
  icon: string;
  label: string;
  value: string;
  tone: "blue" | "green" | "orange";
}) => {
  const palette = {
    blue: { icon: colors.primary, background: colors.lavender },
    green: { icon: colors.green, background: colors.greenSoft },
    orange: { icon: colors.orange, background: colors.orangeSoft },
  }[tone];

  return (
    <View style={styles.statCard}>
      <View style={[styles.statIcon, { backgroundColor: palette.background }]}>
        <Icon glyph={icon} size={20} color={palette.icon} />
      </View>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
};

const Icon = ({ glyph, color = colors.primary, size = 22 }: { glyph: string; color?: string; size?: number }) => (
  <Text style={{ color, fontSize: size, lineHeight: size + 3 }}>{glyph}</Text>
);

export default function HomeScreen({ navigation }: { navigation: any }) {
  const { user } = useAuth();
  const firstName = user?.first_name || "there";

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
      showsVerticalScrollIndicator={false}
    >
      <View style={styles.greetingRow}>
        <View>
          <Text style={styles.eyebrow}>WEDNESDAY, SEPTEMBER 2</Text>
          <Text style={styles.greeting}>Good morning, {firstName}</Text>
          <Text style={styles.subtitle}>Here is your academic overview.</Text>
        </View>
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>{firstName.charAt(0).toUpperCase()}</Text>
        </View>
      </View>

      <View style={styles.heroCard}>
        <View style={styles.heroIcon}>
          <Icon glyph="⌂" color="#fff" size={25} />
        </View>
        <View style={styles.heroCopy}>
          <Text style={styles.heroTitle}>Keep your momentum</Text>
          <Text style={styles.heroText}>
            Stay on top of your classes and upcoming deadlines.
          </Text>
        </View>
        <Icon glyph="›" color="#fff" size={28} />
      </View>

      <View style={styles.statsRow}>
        <StatCard icon="□" label="Classes today" value="0" tone="blue" />
        <StatCard icon="✓" label="Assignments" value="0" tone="orange" />
        <StatCard icon="▤" label="Notes" value="0" tone="green" />
      </View>

      <View style={styles.sectionHeader}>
        <Text style={styles.sectionTitle}>Today&apos;s schedule</Text>
        <Pressable>
          <Text style={styles.link}>View all</Text>
        </Pressable>
      </View>
      <View style={styles.card}>
        <View style={styles.emptyIcon}>
        <Icon glyph="✓" size={25} />
        </View>
        <View style={styles.cardCopy}>
          <Text style={styles.cardTitle}>No classes scheduled</Text>
          <Text style={styles.cardText}>Your schedule will appear here when classes are added.</Text>
        </View>
      </View>

      <View style={styles.sectionHeader}>
        <Text style={styles.sectionTitle}>Your tasks</Text>
        <Pressable>
          <Text style={styles.link}>View all</Text>
        </Pressable>
      </View>
      <View style={styles.card}>
        <View style={[styles.emptyIcon, { backgroundColor: colors.orangeSoft }]}>
        <Icon glyph="□" size={25} color={colors.orange} />
        </View>
        <View style={styles.cardCopy}>
          <Text style={styles.cardTitle}>You&apos;re all caught up</Text>
          <Text style={styles.cardText}>No pending assignments or deadlines right now.</Text>
        </View>
      </View>

      <View style={styles.sectionHeader}>
        <Text style={styles.sectionTitle}>Quick actions</Text>
      </View>
      <View style={styles.actionsGrid}>
        {[
          { icon: "+", label: "New note", screen: "Notes" },
          { icon: "□", label: "Add event", screen: "Schedule" },
          { icon: "✉", label: "Messages", screen: "Messages" },
          { icon: "▤", label: "Assignments", screen: "Assignments" },
        ].map((action) => (
          <Pressable key={action.label} style={styles.action} onPress={() => navigation.navigate(action.screen)}>
            <Icon glyph={action.icon} size={22} />
            <Text style={styles.actionLabel}>{action.label}</Text>
          </Pressable>
        ))}
      </View>

      <View style={styles.aiFloatRow}>
        <Pressable
          style={styles.aiFab}
          onPress={() => navigation.navigate("AI")}
          accessibilityLabel="Ask UniHub AI"
        >
          <Text style={styles.aiFabSpark}>✦</Text>
          <Text style={styles.aiFabText}>AI</Text>
        </Pressable>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: 20, paddingBottom: 48 },
  greetingRow: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    marginBottom: 22,
  },
  eyebrow: { color: colors.muted, fontSize: 11, fontWeight: "700", letterSpacing: 1 },
  greeting: { color: colors.ink, fontSize: 24, fontWeight: "800", marginTop: 5 },
  subtitle: { color: colors.muted, fontSize: 14, marginTop: 5 },
  avatar: {
    alignItems: "center",
    backgroundColor: colors.primary,
    borderRadius: 24,
    height: 48,
    justifyContent: "center",
    width: 48,
  },
  avatarText: { color: "#fff", fontSize: 18, fontWeight: "800" },
  heroCard: {
    alignItems: "center",
    backgroundColor: colors.primary,
    borderRadius: 18,
    flexDirection: "row",
    marginBottom: 18,
    padding: 18,
  },
  heroIcon: {
    alignItems: "center",
    backgroundColor: "rgba(255,255,255,0.18)",
    borderRadius: 12,
    height: 48,
    justifyContent: "center",
    width: 48,
  },
  heroCopy: { flex: 1, marginHorizontal: 13 },
  heroTitle: { color: "#fff", fontSize: 16, fontWeight: "800" },
  heroText: { color: "#dfe5ff", fontSize: 12, lineHeight: 18, marginTop: 4 },
  statsRow: { flexDirection: "row", gap: 10, marginBottom: 26 },
  statCard: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 15,
    borderWidth: 1,
    flex: 1,
    padding: 12,
  },
  statIcon: { alignItems: "center", borderRadius: 9, height: 34, justifyContent: "center", width: 34 },
  statValue: { color: colors.ink, fontSize: 22, fontWeight: "800", marginTop: 10 },
  statLabel: { color: colors.muted, fontSize: 11, marginTop: 2 },
  sectionHeader: { alignItems: "center", flexDirection: "row", justifyContent: "space-between", marginBottom: 10, marginTop: 2 },
  sectionTitle: { color: colors.ink, fontSize: 17, fontWeight: "800" },
  link: { color: colors.primary, fontSize: 12, fontWeight: "700" },
  card: {
    alignItems: "center",
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 15,
    borderWidth: 1,
    flexDirection: "row",
    marginBottom: 22,
    padding: 15,
  },
  emptyIcon: { alignItems: "center", backgroundColor: colors.lavender, borderRadius: 12, height: 48, justifyContent: "center", width: 48 },
  cardCopy: { flex: 1, marginLeft: 13 },
  cardTitle: { color: colors.ink, fontSize: 14, fontWeight: "700" },
  cardText: { color: colors.muted, fontSize: 12, lineHeight: 18, marginTop: 4 },
  actionsGrid: { flexDirection: "row", flexWrap: "wrap", gap: 10 },
  action: {
    alignItems: "center",
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 14,
    borderWidth: 1,
    flexBasis: "48%",
    flexGrow: 1,
    flexDirection: "row",
    gap: 9,
    padding: 15,
  },
  actionLabel: { color: colors.ink, fontSize: 12, fontWeight: "700" },
  aiFloatRow: { alignItems: "flex-end", marginTop: 22, width: "100%" },
  aiFab: { alignItems: "center", backgroundColor: colors.primary, borderColor: "#fff", borderRadius: 31, borderWidth: 3, elevation: 8, height: 62, justifyContent: "center", marginBottom: 10, shadowColor: "#172033", shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.22, shadowRadius: 7, width: 62 },
  aiFabSpark: { color: "#dfe5ff", fontSize: 13, lineHeight: 14, position: "absolute", right: 11, top: 8 },
  aiFabText: { color: "#fff", fontSize: 17, fontWeight: "800" },
});
