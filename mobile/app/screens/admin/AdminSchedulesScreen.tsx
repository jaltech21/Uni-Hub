/**
 * AdminSchedulesScreen
 * View, approve, and cancel schedules.
 */

import React, { useCallback, useEffect, useState } from "react";
import {
  ActivityIndicator,
  Alert,
  FlatList,
  RefreshControl,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import adminService from "@services/admin";
import { Schedule } from "@app/types";
import { colors, spacing, typography } from "@theme/index";

const statusColor: Record<string, string> = {
  approved: colors.success[600],
  cancelled: colors.accent[500],
  pending: colors.warning[600],
};

export default function AdminSchedulesScreen() {
  const [schedules, setSchedules] = useState<Schedule[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      setError(null);
      const data = await adminService.listSchedules();
      setSchedules(data);
    } catch (e: any) {
      setError(e.message || "Failed to load schedules");
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

  const handleAction = (schedule: Schedule) => {
    const options: { text: string; style?: "cancel" | "destructive"; onPress?: () => void }[] = [
      { text: "Cancel", style: "cancel" },
    ];

    if (schedule.status !== "approved") {
      options.unshift({
        text: "Approve",
        onPress: async () => {
          try {
            await adminService.approveSchedule(schedule.id);
            load();
          } catch (e: any) {
            Alert.alert("Error", e.message || "Could not approve");
          }
        },
      });
    }

    if (schedule.status !== "cancelled") {
      options.unshift({
        text: "Cancel Schedule",
        style: "destructive",
        onPress: async () => {
          try {
            await adminService.cancelSchedule(schedule.id);
            load();
          } catch (e: any) {
            Alert.alert("Error", e.message || "Could not cancel");
          }
        },
      });
    }

    Alert.alert(schedule.title, `Status: ${schedule.status ?? "unknown"}`, options);
  };

  const renderItem = ({ item }: { item: Schedule }) => (
    <View style={styles.row}>
      <View style={styles.rowBody}>
        <Text style={styles.title}>{item.title}</Text>
        <Text style={styles.sub}>
          {item.day_of_week} · {item.start_time} – {item.end_time}
        </Text>
        {item.location ? <Text style={styles.sub}>{item.location}</Text> : null}
        <Text
          style={[
            styles.badge,
            { color: statusColor[item.status ?? "pending"] ?? "#667085" },
          ]}
        >
          {(item.status ?? "pending").toUpperCase()}
        </Text>
      </View>
      <TouchableOpacity
        style={styles.actionBtn}
        onPress={() => handleAction(item)}
      >
        <Text style={styles.actionText}>Action</Text>
      </TouchableOpacity>
    </View>
  );

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color={colors.primary[600]} />
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.center}>
        <Text style={styles.errorText}>{error}</Text>
      </View>
    );
  }

  return (
    <FlatList
      style={styles.container}
      data={schedules}
      keyExtractor={(i) => String(i.id)}
      renderItem={renderItem}
      refreshControl={
        <RefreshControl
          refreshing={refreshing}
          onRefresh={onRefresh}
          colors={[colors.primary[600]]}
        />
      }
      ListEmptyComponent={<Text style={styles.empty}>No schedules found.</Text>}
      contentContainerStyle={{ padding: spacing.md, paddingBottom: 32 }}
    />
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f5f7fb" },
  center: { flex: 1, justifyContent: "center", alignItems: "center" },
  row: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#fff",
    borderRadius: 10,
    marginBottom: 8,
    padding: spacing.md,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06,
    shadowRadius: 2,
    elevation: 1,
  },
  rowBody: { flex: 1 },
  title: {
    fontSize: typography.fontSize.base,
    fontWeight: "700",
    color: "#172033",
  },
  sub: {
    fontSize: typography.fontSize.sm,
    color: "#667085",
    marginTop: 2,
  },
  badge: { fontSize: 11, fontWeight: "700", marginTop: 4 },
  actionBtn: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    backgroundColor: colors.primary[50],
    borderRadius: 8,
  },
  actionText: { color: colors.primary[700], fontWeight: "600", fontSize: 13 },
  empty: {
    color: "#adb5bd",
    textAlign: "center",
    marginTop: 60,
    fontSize: 15,
  },
  errorText: { color: colors.accent[600], fontSize: 15 },
});
