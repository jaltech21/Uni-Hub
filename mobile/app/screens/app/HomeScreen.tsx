/**
 * HomeScreen — live dashboard wired to /home/stats.
 */
import React, { useCallback, useEffect, useState } from "react";
import {
  ActivityIndicator,
  Pressable,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { useFocusEffect } from "@react-navigation/native";
import { useAuth } from "@context/AuthContext";
import homeService from "@services/home";
import notificationService from "@services/notifications";
import { Assignment, HomeStats, Schedule } from "@app/types";

const palette = {
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

const Icon = ({
  glyph,
  color = palette.primary,
  size = 22,
}: {
  glyph: string;
  color?: string;
  size?: number;
}) => <Text style={{ color, fontSize: size, lineHeight: size + 3 }}>{glyph}</Text>;

const StatCard = ({
  icon,
  label,
  value,
  tone,
}: {
  icon: string;
  label: string;
  value: number;
  tone: "blue" | "green" | "orange";
}) => {
  const toneMap = {
    blue: { icon: palette.primary, bg: palette.lavender },
    green: { icon: palette.green, bg: palette.greenSoft },
    orange: { icon: palette.orange, bg: palette.orangeSoft },
  }[tone];
  return (
    <View style={styles.statCard}>
      <View style={[styles.statIconWrap, { backgroundColor: toneMap.bg }]}>
        <Icon glyph={icon} size={20} color={toneMap.icon} />
      </View>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
};

const ScheduleRow = ({ item }: { item: Schedule }) => (
  <View style={styles.scheduleRow}>
    <View style={styles.scheduleTime}>
      <Text style={styles.scheduleTimeText}>{item.start_time?.slice(0, 5) ?? "--"}</Text>
      <Text style={styles.scheduleTimeSub}>{item.end_time?.slice(0, 5) ?? "--"}</Text>
    </View>
    <View style={styles.scheduleDot} />
    <View style={styles.scheduleBody}>
      <Text style={styles.scheduleTitle}>{item.title}</Text>
      {item.location ? <Text style={styles.scheduleSub}>{item.location}</Text> : null}
    </View>
  </View>
);

const TaskRow = ({ item }: { item: Assignment }) => {
  const due = item.due_date
    ? new Date(item.due_date).toLocaleDateString(undefined, {
        month: "short",
        day: "numeric",
      })
    : null;
  return (
    <View style={styles.taskRow}>
      <View style={styles.taskDot} />
      <View style={styles.taskBody}>
        <Text style={styles.taskTitle}>{item.title}</Text>
        {item.course_name ? (
          <Text style={styles.taskSub}>{item.course_name}</Text>
        ) : null}
      </View>
      {due ? <Text style={styles.taskDue}>{due}</Text> : null}
    </View>
  );
};

function greeting(): string {
  const h = new Date().getHours();
  if (h < 12) return "Good morning";
  if (h < 17) return "Good afternoon";
  return "Good evening";
}

const todayLabel = () =>
  new Date()
    .toLocaleDateString(undefined, {
      weekday: "long",
      month: "long",
      day: "numeric",
    })
    .toUpperCase();

export default function HomeScreen({ navigation }: { navigation: any }) {
  const { user } = useAuth();
  const firstName = user?.first_name ?? "there";
  const [stats, setStats] = useState<HomeStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [unread, setUnread] = useState(0);

  useFocusEffect(
    useCallback(() => {
      let active = true;
      notificationService
        .unreadCount()
        .then((count) => {
          if (active) setUnread(count);
        })
        .catch(() => undefined);
      return () => {
        active = false;
      };
    }, [])
  );

  const load = useCallback(async () => {
    try {
      setError(null);
      const data = await homeService.stats();
      setStats(data);
    } catch (e: any) {
      setError(e.message ?? "Could not load dashboard");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const onRefresh = () => {
    setRefreshing(true);
    load();
  };

  const todaySchedule: Schedule[] = stats?.today_schedule ?? [];
  const upcomingTasks: Assignment[] = stats?.upcoming_tasks ?? [];

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
      showsVerticalScrollIndicator={false}
      refreshControl={
        <RefreshControl
          refreshing={refreshing}
          onRefresh={onRefresh}
          colors={[palette.primary]}
          tintColor={palette.primary}
        />
      }
    >
      {/* Greeting header */}
      <View style={styles.greetingRow}>
        <View style={{ flex: 1 }}>
          <Text style={styles.eyebrow}>{todayLabel()}</Text>
          <Text style={styles.greeting}>
            {greeting()}, {firstName}
          </Text>
          <Text style={styles.subtitle}>Here is your academic overview.</Text>
        </View>
        <View style={styles.headerActions}>
          <Pressable
            style={styles.bellBtn}
            onPress={() => navigation.navigate("Notifications")}
            accessibilityLabel="Notifications"
          >
            <Icon glyph="🔔" size={20} />
            {unread > 0 ? (
              <View style={styles.bellBadge}>
                <Text style={styles.bellBadgeText}>
                  {unread > 99 ? "99+" : unread}
                </Text>
              </View>
            ) : null}
          </Pressable>
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>{firstName.charAt(0).toUpperCase()}</Text>
          </View>
        </View>
      </View>

      {loading ? (
        <ActivityIndicator
          size="large"
          color={palette.primary}
          style={{ marginVertical: 24 }}
        />
      ) : error ? (
        <View style={styles.errorBanner}>
          <Text style={styles.errorBannerText}>{error}</Text>
        </View>
      ) : (
        <>
          {/* Stats row */}
          <View style={styles.statsRow}>
            <StatCard
              icon="□"
              label="Classes today"
              value={stats?.classes_today ?? 0}
              tone="blue"
            />
            <StatCard
              icon="✓"
              label="Due soon"
              value={stats?.assignments_due ?? 0}
              tone="orange"
            />
            <StatCard
              icon="▤"
              label="Notes"
              value={stats?.notes_count ?? 0}
              tone="green"
            />
          </View>

          {/* Today's schedule */}
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Today&apos;s schedule</Text>
            <Pressable onPress={() => navigation.navigate("Schedule")}>
              <Text style={styles.link}>View all</Text>
            </Pressable>
          </View>
          {todaySchedule.length > 0 ? (
            <View style={styles.card}>
              {todaySchedule.map((s) => (
                <ScheduleRow key={s.id} item={s} />
              ))}
            </View>
          ) : (
            <View style={styles.emptyCard}>
              <View style={styles.emptyIconWrap}>
                <Icon glyph="□" size={24} />
              </View>
              <View style={styles.emptyBody}>
                <Text style={styles.emptyTitle}>No classes today</Text>
                <Text style={styles.emptyText}>
                  Your schedule will appear here when classes are enrolled.
                </Text>
              </View>
            </View>
          )}

          {/* Upcoming tasks */}
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Upcoming tasks</Text>
            <Pressable onPress={() => navigation.navigate("Assignments")}>
              <Text style={styles.link}>View all</Text>
            </Pressable>
          </View>
          {upcomingTasks.length > 0 ? (
            <View style={styles.card}>
              {upcomingTasks.map((a) => (
                <TaskRow key={a.id} item={a} />
              ))}
            </View>
          ) : (
            <View style={styles.emptyCard}>
              <View
                style={[styles.emptyIconWrap, { backgroundColor: palette.greenSoft }]}
              >
                <Icon glyph="✓" size={24} color={palette.green} />
              </View>
              <View style={styles.emptyBody}>
                <Text style={styles.emptyTitle}>All caught up</Text>
                <Text style={styles.emptyText}>
                  No pending assignments or upcoming deadlines.
                </Text>
              </View>
            </View>
          )}
        </>
      )}

      {/* Quick actions */}
      <View style={[styles.sectionHeader, { marginTop: 8 }]}>
        <Text style={styles.sectionTitle}>Quick actions</Text>
      </View>
      <View style={styles.actionsGrid}>
        {[
          { icon: "+", label: "New note", screen: "Notes" },
          { icon: "□", label: "Schedule", screen: "Schedule" },
          { icon: "✉", label: "Messages", screen: "Messages" },
          { icon: "▤", label: "Assignments", screen: "Assignments" },
        ].map((action) => (
          <Pressable
            key={action.label}
            style={styles.actionBtn}
            onPress={() => navigation.navigate(action.screen)}
            accessibilityLabel={action.label}
          >
            <Icon glyph={action.icon} size={22} />
            <Text style={styles.actionLabel}>{action.label}</Text>
          </Pressable>
        ))}
      </View>

      {/* AI FAB */}
      <View style={styles.aiRow}>
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
  container: { flex: 1, backgroundColor: palette.background },
  content: { padding: 20, paddingBottom: 48 },
  greetingRow: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    marginBottom: 22,
  },
  eyebrow: { color: palette.muted, fontSize: 11, fontWeight: "700", letterSpacing: 1 },
  greeting: { color: palette.ink, fontSize: 24, fontWeight: "800", marginTop: 5 },
  subtitle: { color: palette.muted, fontSize: 14, marginTop: 5 },
  headerActions: { flexDirection: "row", alignItems: "center", gap: 10 },
  bellBtn: {
    alignItems: "center",
    backgroundColor: palette.surface,
    borderRadius: 24,
    borderWidth: 1,
    borderColor: palette.border,
    height: 48,
    justifyContent: "center",
    position: "relative",
    width: 48,
  },
  bellBadge: {
    position: "absolute",
    right: -4,
    top: -4,
    minWidth: 19,
    height: 19,
    borderRadius: 10,
    backgroundColor: "#d92d20",
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 4,
    borderWidth: 2,
    borderColor: palette.background,
  },
  bellBadgeText: { color: "#fff", fontSize: 10, fontWeight: "800" },
  avatar: {
    alignItems: "center",
    backgroundColor: palette.primary,
    borderRadius: 24,
    height: 48,
    justifyContent: "center",
    width: 48,
  },
  avatarText: { color: "#fff", fontSize: 18, fontWeight: "800" },
  statsRow: { flexDirection: "row", gap: 10, marginBottom: 26 },
  statCard: {
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 15,
    borderWidth: 1,
    flex: 1,
    padding: 12,
  },
  statIconWrap: {
    alignItems: "center",
    borderRadius: 9,
    height: 34,
    justifyContent: "center",
    width: 34,
  },
  statValue: { color: palette.ink, fontSize: 22, fontWeight: "800", marginTop: 10 },
  statLabel: { color: palette.muted, fontSize: 11, marginTop: 2 },
  sectionHeader: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    marginBottom: 10,
    marginTop: 2,
  },
  sectionTitle: { color: palette.ink, fontSize: 17, fontWeight: "800" },
  link: { color: palette.primary, fontSize: 12, fontWeight: "700" },
  card: {
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 15,
    borderWidth: 1,
    marginBottom: 22,
    overflow: "hidden",
  },
  emptyCard: {
    alignItems: "center",
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 15,
    borderWidth: 1,
    flexDirection: "row",
    marginBottom: 22,
    padding: 16,
  },
  emptyIconWrap: {
    alignItems: "center",
    backgroundColor: palette.lavender,
    borderRadius: 12,
    height: 48,
    justifyContent: "center",
    width: 48,
  },
  emptyBody: { flex: 1, marginLeft: 12 },
  emptyTitle: { color: palette.ink, fontSize: 14, fontWeight: "700" },
  emptyText: { color: palette.muted, fontSize: 12, lineHeight: 18, marginTop: 4 },
  scheduleRow: {
    borderTopColor: palette.border,
    borderTopWidth: 1,
    flexDirection: "row",
    gap: 12,
    padding: 12,
  },
  scheduleTime: { alignItems: "flex-end", width: 44 },
  scheduleTimeText: { color: palette.primary, fontSize: 12, fontWeight: "700" },
  scheduleTimeSub: { color: palette.muted, fontSize: 11, marginTop: 2 },
  scheduleDot: {
    backgroundColor: palette.primary,
    borderRadius: 4,
    height: 8,
    marginTop: 4,
    width: 8,
  },
  scheduleBody: { flex: 1 },
  scheduleTitle: { color: palette.ink, fontSize: 14, fontWeight: "600" },
  scheduleSub: { color: palette.muted, fontSize: 12, marginTop: 2 },
  taskRow: {
    alignItems: "center",
    borderTopColor: palette.border,
    borderTopWidth: 1,
    flexDirection: "row",
    gap: 10,
    padding: 12,
  },
  taskDot: { backgroundColor: palette.orange, borderRadius: 4, height: 8, width: 8 },
  taskBody: { flex: 1 },
  taskTitle: { color: palette.ink, fontSize: 14, fontWeight: "600" },
  taskSub: { color: palette.muted, fontSize: 12, marginTop: 2 },
  taskDue: { color: palette.orange, fontSize: 12, fontWeight: "700" },
  actionsGrid: { flexDirection: "row", flexWrap: "wrap", gap: 10 },
  actionBtn: {
    alignItems: "center",
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 14,
    borderWidth: 1,
    flexBasis: "48%",
    flexDirection: "row",
    flexGrow: 1,
    gap: 9,
    padding: 15,
  },
  actionLabel: { color: palette.ink, fontSize: 12, fontWeight: "700" },
  aiRow: { alignItems: "flex-end", marginTop: 22, width: "100%" },
  aiFab: {
    alignItems: "center",
    backgroundColor: palette.primary,
    borderColor: "#fff",
    borderRadius: 31,
    borderWidth: 3,
    elevation: 8,
    height: 62,
    justifyContent: "center",
    marginBottom: 10,
    shadowColor: "#172033",
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.22,
    shadowRadius: 7,
    width: 62,
  },
  aiFabSpark: {
    color: "#dfe5ff",
    fontSize: 13,
    lineHeight: 14,
    position: "absolute",
    right: 11,
    top: 8,
  },
  aiFabText: { color: "#fff", fontSize: 17, fontWeight: "800" },
  errorBanner: {
    backgroundColor: "#fee4e2",
    borderRadius: 10,
    marginBottom: 16,
    padding: 14,
  },
  errorBannerText: { color: "#b42318", fontSize: 13, fontWeight: "600" },
});
