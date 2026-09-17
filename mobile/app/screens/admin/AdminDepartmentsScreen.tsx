/**
 * AdminDepartmentsScreen
 * View, create, toggle-active, and delete departments.
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
import { Department } from "@app/types";
import { colors, spacing, typography } from "@theme/index";

export default function AdminDepartmentsScreen() {
  const [departments, setDepartments] = useState<Department[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [newName, setNewName] = useState("");
  const [newCode, setNewCode] = useState("");

  const load = useCallback(async () => {
    try {
      setError(null);
      const data = await adminService.listDepartments();
      setDepartments(data);
    } catch (e: any) {
      setError(e.message || "Failed to load departments");
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

  const handleCreate = async () => {
    if (!newName.trim()) {
      Alert.alert("Validation", "Department name is required");
      return;
    }
    try {
      await adminService.createDepartment({ name: newName.trim(), code: newCode.trim() || undefined });
      setNewName("");
      setNewCode("");
      setCreating(false);
      load();
    } catch (e: any) {
      Alert.alert("Error", e.message || "Could not create department");
    }
  };

  const handleToggle = async (dept: Department) => {
    try {
      await adminService.toggleDepartmentActive(dept.id);
      load();
    } catch (e: any) {
      Alert.alert("Error", e.message || "Could not toggle department");
    }
  };

  const handleDelete = (dept: Department) => {
    Alert.alert("Delete Department", `Delete "${dept.name}"?`, [
      {
        text: "Delete",
        style: "destructive",
        onPress: async () => {
          try {
            await adminService.deleteDepartment(dept.id);
            load();
          } catch (e: any) {
            Alert.alert("Error", e.message || "Could not delete");
          }
        },
      },
      { text: "Cancel", style: "cancel" },
    ]);
  };

  const renderItem = ({ item }: { item: Department }) => (
    <View style={styles.row}>
      <View style={styles.rowBody}>
        <Text style={styles.name}>{item.name}</Text>
        {item.code ? <Text style={styles.code}>{item.code}</Text> : null}
        <Text
          style={[
            styles.status,
            { color: item.active ? colors.success[600] : colors.accent[500] },
          ]}
        >
          {item.active ? "Active" : "Inactive"}
        </Text>
      </View>
      <View style={styles.actions}>
        <TouchableOpacity
          style={[styles.btn, { backgroundColor: item.active ? colors.warning[50] : colors.success[50] }]}
          onPress={() => handleToggle(item)}
        >
          <Text style={[styles.btnText, { color: item.active ? colors.warning[700] : colors.success[700] }]}>
            {item.active ? "Deactivate" : "Activate"}
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.btn, { backgroundColor: colors.accent[50], marginTop: 4 }]}
          onPress={() => handleDelete(item)}
        >
          <Text style={[styles.btnText, { color: colors.accent[600] }]}>Delete</Text>
        </TouchableOpacity>
      </View>
    </View>
  );

  return (
    <View style={styles.container}>
      {creating && (
        <View style={styles.createForm}>
          <Text style={styles.formTitle}>New Department</Text>
          <TextInput
            style={styles.input}
            placeholder="Name *"
            placeholderTextColor="#adb5bd"
            value={newName}
            onChangeText={setNewName}
          />
          <TextInput
            style={styles.input}
            placeholder="Code (optional)"
            placeholderTextColor="#adb5bd"
            value={newCode}
            onChangeText={setNewCode}
          />
          <View style={styles.formActions}>
            <TouchableOpacity style={styles.cancelBtn} onPress={() => setCreating(false)}>
              <Text style={styles.cancelBtnText}>Cancel</Text>
            </TouchableOpacity>
            <TouchableOpacity style={styles.saveBtn} onPress={handleCreate}>
              <Text style={styles.saveBtnText}>Create</Text>
            </TouchableOpacity>
          </View>
        </View>
      )}

      {!creating && (
        <TouchableOpacity style={styles.addBtn} onPress={() => setCreating(true)}>
          <Text style={styles.addBtnText}>+ Add Department</Text>
        </TouchableOpacity>
      )}

      {loading ? (
        <ActivityIndicator size="large" color={colors.primary[600]} style={styles.loader} />
      ) : error ? (
        <Text style={styles.errorText}>{error}</Text>
      ) : (
        <FlatList
          data={departments}
          keyExtractor={(i) => String(i.id)}
          renderItem={renderItem}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={onRefresh} colors={[colors.primary[600]]} />
          }
          ListEmptyComponent={<Text style={styles.empty}>No departments found.</Text>}
          contentContainerStyle={{ paddingBottom: 32 }}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f5f7fb" },
  addBtn: {
    margin: spacing.md,
    backgroundColor: colors.primary[600],
    borderRadius: 10,
    paddingVertical: 12,
    alignItems: "center",
  },
  addBtnText: { color: "#fff", fontWeight: "700", fontSize: 15 },
  createForm: {
    margin: spacing.md,
    backgroundColor: "#fff",
    borderRadius: 12,
    padding: spacing.md,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.08,
    shadowRadius: 3,
    elevation: 2,
  },
  formTitle: {
    fontSize: typography.fontSize.base,
    fontWeight: "700",
    color: "#172033",
    marginBottom: spacing.sm,
  },
  input: {
    backgroundColor: "#f5f7fb",
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: typography.fontSize.base,
    color: "#172033",
    borderWidth: 1,
    borderColor: "#dee2e6",
    marginBottom: 8,
  },
  formActions: { flexDirection: "row", gap: 8, marginTop: 4 },
  cancelBtn: {
    flex: 1,
    backgroundColor: "#f1f3f5",
    borderRadius: 8,
    paddingVertical: 10,
    alignItems: "center",
  },
  cancelBtnText: { color: "#495057", fontWeight: "600" },
  saveBtn: {
    flex: 1,
    backgroundColor: colors.primary[600],
    borderRadius: 8,
    paddingVertical: 10,
    alignItems: "center",
  },
  saveBtnText: { color: "#fff", fontWeight: "700" },
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
  name: { fontSize: typography.fontSize.base, fontWeight: "700", color: "#172033" },
  code: { fontSize: typography.fontSize.sm, color: "#667085", marginTop: 2 },
  status: { fontSize: 12, fontWeight: "700", marginTop: 4 },
  actions: { alignItems: "flex-end" },
  btn: { paddingHorizontal: 10, paddingVertical: 5, borderRadius: 7 },
  btnText: { fontSize: 12, fontWeight: "700" },
  loader: { marginTop: 40 },
  errorText: { color: colors.accent[600], textAlign: "center", marginTop: 40, fontSize: 15 },
  empty: { color: "#adb5bd", textAlign: "center", marginTop: 60, fontSize: 15 },
});
