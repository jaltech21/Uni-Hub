/**
 * ScheduleScreen — live wired to ScheduleService.
 * Lists the user's schedules (enrolled or owned).
 * Pull-to-refresh + loading/empty states.
 */

import React, { useCallback, useEffect, useState } from "react";
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  RefreshControl,
  StyleSheet,
  Text,
  View,
} from "react-native";
import scheduleService from "@services/schedules";
import { Schedule } from "@app/types";

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
  accent: "#f04438",
  accentSoft: "#fee4e2",
  border: "#e7eaf2",
};

const dayShorthand: Record<string, string> = {
  Monday: "Mon",
  Tuesday: "Tue",
  Wednesday: "Wed",
  Thursday: "Thu",
  Friday: "Fri",
  Saturday: "Sat",
  Sunday: "Sun",
};

function ScheduleCard({ item }: { item: Schedule }) {
  const dayLabel = dayShorthand[item.day_of_week] ?? item.day_of_week;
  return (
    <View style={styles.card}>
      <View style={styles.cardLeft}>
        <View style={styles.dayBadge}>
          <Text style={styles.dayBadgeText}>{dayLabel}</Text>
        </View>
        <View style={styles.cardDot} />
      </View>

      <View style={styles.cardBody}>
        <Text style={styles.cardTitle}>{item.title}</Text>
        {item.course_name ? (
          <Text style={styles.cardSub}>{item.course_name}</Text>
        ) : null}
        <View style={styles.cardMeta}>
          <Text style={styles.metaText}>
            {item.start_time?.slice(0, 5)} – {item.end_time?.slice(0, 5)}
          </Text>
          {item.location ? (
            <>
              <Text style={styles.metaSep}>·</Text>
              <Text style={styles.metaText}>{item.location}</Text>
            </>
          ) : null}
        </View>
      </View>
    </View>
  );
}

export default function ScheduleScreen() {
  const [schedules, setSchedules] = useState<Schedule[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      setError(null);
      const data = await scheduleService.list();
      setSchedules(data);
    } catch (e: any) {
      setError(e.message ?? "Could not load schedules");
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

  const header = (
    <>
      <Text style={styles.eyebrow}>YOUR ACADEMIC CALENDAR</Text>
      <Text style={styles.title}>Schedule</Text>
      <Text style={styles.subtitle}>
        Plan your classes, events, and study time.
      </Text>

      {/* Today date card */}
      <View style={styles.dateCard}>
        <Text style={styles.dateDay}>
          {new Date().getDate().toString().padStart(2, "0")}
        </Text>
        <View>
          <Text style={styles.dateMonth}>
            {new Date()
              .toLocaleDateString(undefined, { month: "long" })
              .toUpperCase()}
          </Text>
          <Text style={styles.dateWeekday}>
            {new Date().toLocaleDateString(undefined, { weekday: "long" })} · Today
          </Text>
        </View>
      </View>
    </>
  );

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color={palette.primary} />
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.center}>
        <Text style={styles.errorText}>{error}</Text>
        <Pressable
          style={styles.retryBtn}
          onPress={() => {
            setLoading(true);
            load();
          }}
        >
          <Text style={styles.retryBtnText}>Retry</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <FlatList
      style={styles.container}
      contentContainerStyle={styles.content}
      data={schedules}
      keyExtractor={(item) => String(item.id)}
      ListHeaderComponent={header}
      renderItem={({ item }) => <ScheduleCard item={item} />}
      refreshControl={
        <RefreshControl
          refreshing={refreshing}
          onRefresh={onRefresh}
          colors={[palette.primary]}
          tintColor={palette.primary}
        />
      }
      ListEmptyComponent={
        <View style={styles.emptyCard}>
          <Text style={styles.emptyIcon}>&#9633;</Text>
          <Text style={styles.emptyTitle}>Your day is clear</Text>
          <Text style={styles.emptyText}>
            Enroll in classes or add an event to build your schedule.
          </Text>
        </View>
      }
    />
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: palette.background },
  content: { padding: 20, paddingBottom: 48 },
  center: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: palette.background,
  },
  eyebrow: {
    color: palette.muted,
    fontSize: 11,
    fontWeight: "700",
    letterSpacing: 1,
    marginBottom: 4,
  },
  title: { color: palette.ink, fontSize: 27, fontWeight: "800" },
  subtitle: { color: palette.muted, fontSize: 14, marginTop: 6, marginBottom: 20 },
  dateCard: {
    alignItems: "center",
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 16,
    borderWidth: 1,
    flexDirection: "row",
    padding: 17,
    marginBottom: 22,
  },
  dateDay: {
    color: palette.primary,
    fontSize: 34,
    fontWeight: "800",
    marginRight: 14,
  },
  dateMonth: {
    color: palette.muted,
    fontSize: 11,
    fontWeight: "800",
    letterSpacing: 1,
  },
  dateWeekday: { color: palette.ink, fontSize: 14, fontWeight: "700", marginTop: 4 },
  card: {
    flexDirection: "row",
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 14,
    borderWidth: 1,
    marginBottom: 12,
    padding: 14,
  },
  cardLeft: { alignItems: "center", marginRight: 12 },
  dayBadge: {
    backgroundColor: palette.lavender,
    borderRadius: 8,
    paddingHorizontal: 8,
    paddingVertical: 4,
    marginBottom: 6,
  },
  dayBadgeText: { color: palette.primary, fontSize: 11, fontWeight: "800" },
  cardDot: {
    backgroundColor: palette.primary,
    borderRadius: 4,
    height: 8,
    width: 8,
  },
  cardBody: { flex: 1 },
  cardTitle: { fontSize: 15, fontWeight: "700", color: palette.ink },
  cardSub: { fontSize: 12, color: palette.muted, marginTop: 3 },
  cardMeta: { flexDirection: "row", alignItems: "center", marginTop: 6 },
  metaText: { fontSize: 12, color: "#495057", fontWeight: "600" },
  metaSep: { color: palette.muted, fontSize: 12, marginHorizontal: 5 },
  emptyCard: {
    alignItems: "center",
    backgroundColor: palette.surface,
    borderRadius: 16,
    padding: 28,
    marginTop: 8,
  },
  emptyIcon: { color: palette.primary, fontSize: 39 },
  emptyTitle: { color: palette.ink, fontSize: 16, fontWeight: "800", marginTop: 12 },
  emptyText: {
    color: palette.muted,
    fontSize: 13,
    lineHeight: 19,
    marginTop: 6,
    textAlign: "center",
  },
  errorText: { color: palette.accent, fontSize: 15, marginBottom: 12 },
  retryBtn: {
    backgroundColor: palette.primary,
    borderRadius: 8,
    paddingHorizontal: 20,
    paddingVertical: 10,
  },
  retryBtnText: { color: "#fff", fontWeight: "700" },
});
