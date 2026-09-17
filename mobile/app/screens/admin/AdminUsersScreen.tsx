/**
 * AdminUsersScreen
 * Browse, filter, change roles, blacklist/unblacklist users.
 */

import React, { useCallback, useEffect, useState } from "react";
import {
  ActivityIndicator,
  Alert,
  FlatList,
  RefreshControl,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";
import adminService from "@services/admin";
import { AdminUser } from "@app/types";
import { colors, spacing, typography } from "@theme/index";

const ROLES = ["all", "student", "teacher", "admin"];

const roleColor: Record<string, string> = {
  student: colors.success[600],
  teacher: colors.warning[600],
  admin: colors.accent[600],
};

function UserRow({
  item,
  onAction,
}: {
  item: AdminUser;
  onAction: (user: AdminUser) => void;
}) {
  return (
    <View style={styles.row}>
      <View style={styles.rowBody}>
        <Text style={styles.name}>
          {item.first_name} {item.last_name}
        </Text>
        <Text style={styles.email}>{item.email}</Text>
        <Text style={[styles.badge, { color: roleColor[item.role] ?? "#667085" }]}>
          {item.role.toUpperCase()}
          {item.active === false ? " • BLACKLISTED" : ""}
        </Text>
      </View>
      <TouchableOpacity onPress={() => onAction(item)} style={styles.actionBtn}>
        <Text style={styles.actionText}>Manage</Text>
      </TouchableOpacity>
    </View>
  );
}

export default function AdminUsersScreen() {
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState("all");

  const load = useCallback(async () => {
    try {
      setError(null);
      const data = await adminService.listUsers({
        search: search.trim() || undefined,
        role: roleFilter === "all" ? undefined : roleFilter,
      });
      setUsers(data);
    } catch (e: any) {
      setError(e.message || "Failed to load users");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [search, roleFilter]);

  useEffect(() => {
    load();
  }, [load]);

  const onRefresh = () => {
    setRefreshing(true);
    load();
  };

  const handleAction = (user: AdminUser) => {
    const isBlacklisted = user.active === false;
    Alert.alert(
      `${user.first_name} ${user.last_name}`,
      `Role: ${user.role}\n${isBlacklisted ? "BLACKLISTED" : "Active"}`,
      [
        {
          text: isBlacklisted ? "Unblacklist" : "Blacklist",
          style: isBlacklisted ? "default" : "destructive",
          onPress: async () => {
            try {
              if (isBlacklisted) {
                await adminService.unblacklistUser(user.id);
              } else {
                await adminService.blacklistUser(user.id, "Admin action");
              }
              load();
            } catch (e: any) {
              Alert.alert("Error", e.message || "Action failed");
            }
          },
        },
        {
          text: "Change Role",
          onPress: () => {
            Alert.alert("Change Role", "Select new role", [
              {
                text: "Student",
                onPress: async () => {
                  await adminService.changeUserRole(user.id, "student");
                  load();
                },
              },
              {
                text: "Teacher",
                onPress: async () => {
                  await adminService.changeUserRole(user.id, "teacher");
                  load();
                },
              },
              {
                text: "Admin",
                onPress: async () => {
                  await adminService.changeUserRole(user.id, "admin");
                  load();
                },
              },
              { text: "Cancel", style: "cancel" },
            ]);
          },
        },
        { text: "Cancel", style: "cancel" },
      ]
    );
  };

  return (
    <View style={styles.container}>
      <TextInput
        style={styles.searchInput}
        placeholder="Search by name or email..."
        placeholderTextColor="#adb5bd"
        value={search}
        onChangeText={setSearch}
        onSubmitEditing={load}
        returnKeyType="search"
      />

      <View style={styles.filters}>
        {ROLES.map((r) => (
          <TouchableOpacity
            key={r}
            onPress={() => setRoleFilter(r)}
            style={[
              styles.filterChip,
              roleFilter === r && styles.filterChipActive,
            ]}
          >
            <Text
              style={[
                styles.filterChipText,
                roleFilter === r && styles.filterChipTextActive,
              ]}
            >
              {r.charAt(0).toUpperCase() + r.slice(1)}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      {loading ? (
        <ActivityIndicator
          size="large"
          color={colors.primary[600]}
          style={styles.loader}
        />
      ) : error ? (
        <Text style={styles.errorText}>{error}</Text>
      ) : (
        <FlatList
          data={users}
          keyExtractor={(i) => String(i.id)}
          renderItem={({ item }) => (
            <UserRow item={item} onAction={handleAction} />
          )}
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={onRefresh}
              colors={[colors.primary[600]]}
            />
          }
          ListEmptyComponent={
            <Text style={styles.empty}>No users found.</Text>
          }
          contentContainerStyle={{ paddingBottom: 32 }}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f5f7fb" },
  searchInput: {
    margin: spacing.md,
    backgroundColor: "#fff",
    borderRadius: 10,
    paddingHorizontal: spacing.md,
    paddingVertical: 10,
    fontSize: typography.fontSize.base,
    borderWidth: 1,
    borderColor: "#dee2e6",
    color: "#172033",
  },
  filters: {
    flexDirection: "row",
    paddingHorizontal: spacing.md,
    gap: 8,
    marginBottom: spacing.sm,
  },
  filterChip: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 20,
    backgroundColor: "#fff",
    borderWidth: 1,
    borderColor: "#dee2e6",
  },
  filterChipActive: {
    backgroundColor: colors.primary[600],
    borderColor: colors.primary[600],
  },
  filterChipText: { fontSize: 12, color: "#667085", fontWeight: "600" },
  filterChipTextActive: { color: "#fff" },
  row: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#fff",
    borderRadius: 10,
    marginHorizontal: spacing.md,
    marginBottom: 8,
    padding: spacing.md,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06,
    shadowRadius: 2,
    elevation: 1,
  },
  rowBody: { flex: 1 },
  name: {
    fontSize: typography.fontSize.base,
    fontWeight: "700",
    color: "#172033",
  },
  email: {
    fontSize: typography.fontSize.sm,
    color: "#667085",
    marginTop: 2,
  },
  badge: {
    fontSize: 11,
    fontWeight: "700",
    marginTop: 4,
  },
  actionBtn: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    backgroundColor: colors.primary[50],
    borderRadius: 8,
  },
  actionText: {
    color: colors.primary[700],
    fontWeight: "600",
    fontSize: 13,
  },
  loader: { marginTop: 40 },
  errorText: {
    color: colors.accent[600],
    textAlign: "center",
    marginTop: 40,
    fontSize: 15,
  },
  empty: {
    color: "#adb5bd",
    textAlign: "center",
    marginTop: 60,
    fontSize: 15,
  },
});
