/**
 * AdminAnnouncementsScreen
 * View, create, publish/unpublish, and delete announcements.
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
import { Announcement } from "@app/types";
import { colors, spacing, typography } from "@theme/index";

const priorityColor: Record<string, string> = {
  low: "#adb5bd",
  normal: colors.primary[600],
  high: colors.warning[600],
  urgent: colors.accent[600],
};

export default function AdminAnnouncementsScreen() {
  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [newTitle, setNewTitle] = useState("");
  const [newContent, setNewContent] = useState("");

  const load = useCallback(async () => {
    try {
      setError(null);
      const data = await adminService.listAnnouncements();
      setAnnouncements(data);
    } catch (e: any) {
      setError(e.message || "Failed to load announcements");
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
    if (!newTitle.trim() || !newContent.trim()) {
      Alert.alert("Validation", "Title and content are required");
      return;
    }
    try {
      await adminService.createAnnouncement({
        title: newTitle.trim(),
        content: newContent.trim(),
        priority: "normal",
      });
      setNewTitle("");
      setNewContent("");
      setCreating(false);
      load();
    } catch (e: any) {
      Alert.alert("Error", e.message || "Could not create announcement");
    }
  };

  const handleAction = (a: Announcement) => {
    const isPublished = !!a.published_at;
    Alert.alert(a.title, `Priority: ${a.priority}\n${isPublished ? "Published" : "Draft"}`, [
      {
        text: isPublished ? "Unpublish" : "Publish",
        onPress: async () => {
          try {
            if (isPublished) {
              await adminService.unpublishAnnouncement(a.id);
            } else {
              await adminService.publishAnnouncement(a.id);
            }
            load();
          } catch (e: any) {
            Alert.alert("Error", e.message || "Action failed");
          }
        },
      },
      {
        text: "Delete",
        style: "destructive",
        onPress: async () => {
          try {
            await adminService.deleteAnnouncement(a.id);
            load();
          } catch (e: any) {
            Alert.alert("Error", e.message || "Could not delete");
          }
        },
      },
      { text: "Cancel", style: "cancel" },
    ]);
  };

  const renderItem = ({ item }: { item: Announcement }) => (
    <View style={styles.row}>
      <View style={styles.rowBody}>
        <Text style={styles.title}>{item.title}</Text>
        <Text style={styles.sub} numberOfLines={2}>
          {item.content}
        </Text>
        <Text
          style={[styles.badge, { color: priorityColor[item.priority] ?? "#667085" }]}
        >
          {item.priority.toUpperCase()} · {item.published_at ? "Published" : "Draft"}
        </Text>
      </View>
      <TouchableOpacity style={styles.actionBtn} onPress={() => handleAction(item)}>
        <Text style={styles.actionText}>Manage</Text>
      </TouchableOpacity>
    </View>
  );

  return (
    <View style={styles.container}>
      {creating && (
        <View style={styles.createForm}>
          <Text style={styles.formTitle}>New Announcement</Text>
          <TextInput
            style={styles.input}
            placeholder="Title *"
            placeholderTextColor="#adb5bd"
            value={newTitle}
            onChangeText={setNewTitle}
          />
          <TextInput
            style={[styles.input, styles.textArea]}
            placeholder="Content *"
            placeholderTextColor="#adb5bd"
            value={newContent}
            onChangeText={setNewContent}
            multiline
            numberOfLines={4}
            textAlignVertical="top"
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
          <Text style={styles.addBtnText}>+ New Announcement</Text>
        </TouchableOpacity>
      )}

      {loading ? (
        <ActivityIndicator size="large" color={colors.primary[600]} style={styles.loader} />
      ) : error ? (
        <Text style={styles.errorText}>{error}</Text>
      ) : (
        <FlatList
          data={announcements}
          keyExtractor={(i) => String(i.id)}
          renderItem={renderItem}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={onRefresh} colors={[colors.primary[600]]} />
          }
          ListEmptyComponent={<Text style={styles.empty}>No announcements.</Text>}
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
  textArea: { minHeight: 80 },
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
  title: { fontSize: typography.fontSize.base, fontWeight: "700", color: "#172033" },
  sub: { fontSize: typography.fontSize.sm, color: "#667085", marginTop: 2 },
  badge: { fontSize: 11, fontWeight: "700", marginTop: 4 },
  actionBtn: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    backgroundColor: colors.primary[50],
    borderRadius: 8,
  },
  actionText: { color: colors.primary[700], fontWeight: "600", fontSize: 13 },
  loader: { marginTop: 40 },
  errorText: { color: colors.accent[600], textAlign: "center", marginTop: 40, fontSize: 15 },
  empty: { color: "#adb5bd", textAlign: "center", marginTop: 60, fontSize: 15 },
});
