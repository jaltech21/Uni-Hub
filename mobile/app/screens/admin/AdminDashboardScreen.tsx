/**
 * AdminDashboardScreen
 * Displays aggregate platform statistics for admin users.
 */

import React, { useCallback, useEffect, useState } from "react";
import {
  ActivityIndicator,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import adminService, { AdminDashboard } from "@services/admin";
import { colors, spacing, typography } from "@theme/index";

const StatCard: React.FC<{ label: string; value: number; accent?: string }> = ({
  label,
  value,
  accent = colors.primary[600],
}) => (
  <View style={[styles.card, { borderLeftColor: accent, borderLeftWidth: 4 }]}>
    <Text style={[styles.statValue, { color: accent }]}>{value}</Text>
    <Text style={styles.statLabel}>{label}</Text>
  </View>
);

export default function AdminDashboardScreen() {
  const [stats, setStats] = useState<AdminDashboard | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      setError(null);
      const data = await adminService.dashboard();
      setStats(data);
    } catch (e: any) {
      setError(e.message || "Failed to load dashboard");
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
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
      refreshControl={
        <RefreshControl
          refreshing={refreshing}
          onRefresh={onRefresh}
          colors={[colors.primary[600]]}
        />
      }
    >
      <Text style={styles.sectionTitle}>Users</Text>
      <View style={styles.row}>
        <StatCard label="Total Users" value={stats?.users_count ?? 0} />
        <StatCard
          label="Students"
          value={stats?.students_count ?? 0}
          accent={colors.success[600]}
        />
      </View>
      <View style={styles.row}>
        <StatCard
          label="Teachers"
          value={stats?.teachers_count ?? 0}
          accent={colors.warning[600]}
        />
        <StatCard
          label="Admins"
          value={stats?.admins_count ?? 0}
          accent={colors.accent[600]}
        />
      </View>
      <View style={styles.row}>
        <StatCard
          label="Blacklisted"
          value={stats?.blacklisted_users_count ?? 0}
          accent={colors.accent[500]}
        />
      </View>

      <Text style={styles.sectionTitle}>Academic</Text>
      <View style={styles.row}>
        <StatCard label="Departments" value={stats?.departments_count ?? 0} />
        <StatCard
          label="Courses"
          value={stats?.courses_count ?? 0}
          accent={colors.success[600]}
        />
      </View>
      <View style={styles.row}>
        <StatCard
          label="Active Courses"
          value={stats?.active_courses_count ?? 0}
          accent={colors.success[500]}
        />
        <StatCard
          label="Schedules"
          value={stats?.schedules_count ?? 0}
          accent={colors.warning[600]}
        />
      </View>
      <View style={styles.row}>
        <StatCard label="Enrollments" value={stats?.enrollments_count ?? 0} />
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f5f7fb" },
  content: { padding: spacing.md, paddingBottom: spacing["2xl"] },
  center: { flex: 1, justifyContent: "center", alignItems: "center" },
  sectionTitle: {
    fontSize: typography.fontSize.lg,
    fontWeight: "700",
    color: "#172033",
    marginTop: spacing.md,
    marginBottom: spacing.sm,
  },
  row: {
    flexDirection: "row",
    gap: spacing.sm,
    marginBottom: spacing.sm,
  },
  card: {
    flex: 1,
    backgroundColor: "#ffffff",
    borderRadius: 12,
    padding: spacing.md,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.08,
    shadowRadius: 3,
    elevation: 2,
  },
  statValue: {
    fontSize: typography.fontSize["2xl"],
    fontWeight: "800",
    marginBottom: 2,
  },
  statLabel: {
    fontSize: typography.fontSize.sm,
    color: "#667085",
    fontWeight: "500",
  },
  errorText: { color: colors.accent[600], fontSize: 15 },
});
