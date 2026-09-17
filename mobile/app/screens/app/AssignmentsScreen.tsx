/**
 * AssignmentsScreen — live, wired to AssignmentService.
 * Students see their assignments (pending + graded stats).
 * Teachers see all assignments they created.
 * Pull-to-refresh, loading skeleton, and empty states are handled.
 */

import React, { useCallback, useEffect, useState } from "react";
import {
  ActivityIndicator,
  Alert,
  FlatList,
  Modal,
  Pressable,
  RefreshControl,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { useAuth } from "@context/AuthContext";
import assignmentService from "@services/assignments";
import { Assignment, Submission } from "@app/types";

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

const statusColor: Record<string, string> = {
  pending: palette.orange,
  submitted: palette.primary,
  graded: palette.green,
};

const statusLabel: Record<string, string> = {
  pending: "Pending",
  submitted: "Submitted",
  graded: "Graded",
};

function dueLabel(dateStr: string): string {
  const due = new Date(dateStr);
  const now = new Date();
  const diff = Math.ceil((due.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
  if (diff < 0) return "Overdue";
  if (diff === 0) return "Due today";
  if (diff === 1) return "Due tomorrow";
  return `Due in ${diff} days`;
}

function AssignmentCard({
  item,
  isStudent,
  onSubmit,
}: {
  item: Assignment;
  isStudent: boolean;
  onSubmit: (assignment: Assignment) => void;
}) {
  const status = item.status ?? "pending";
  const color = statusColor[status] ?? palette.muted;

  return (
    <View style={styles.card}>
      <View style={styles.cardHeader}>
        <View style={[styles.statusBadge, { backgroundColor: color + "22" }]}>
          <Text style={[styles.statusText, { color }]}>
            {statusLabel[status] ?? status}
          </Text>
        </View>
        {item.due_date ? (
          <Text style={[styles.dueText, { color: status === "pending" ? palette.orange : palette.muted }]}>
            {dueLabel(item.due_date)}
          </Text>
        ) : null}
      </View>

      <Text style={styles.cardTitle}>{item.title}</Text>
      {item.course_name ? (
        <Text style={styles.cardSub}>{item.course_name}</Text>
      ) : null}
      {item.description ? (
        <Text style={styles.cardDesc} numberOfLines={2}>
          {item.description}
        </Text>
      ) : null}

      {isStudent && status === "pending" ? (
        <Pressable
          style={styles.submitBtn}
          onPress={() => onSubmit(item)}
          accessibilityLabel={`Submit ${item.title}`}
        >
          <Text style={styles.submitBtnText}>Submit</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

export default function AssignmentsScreen() {
  const { isStudent, isTeacher } = useAuth();
  const [assignments, setAssignments] = useState<Assignment[]>([]);
  const [submissions, setSubmissions] = useState<Submission[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Submit modal state
  const [submitTarget, setSubmitTarget] = useState<Assignment | null>(null);
  const [submitContent, setSubmitContent] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const load = useCallback(async () => {
    try {
      setError(null);
      const [list, subs] = await Promise.all([
        assignmentService.list(),
        isStudent ? assignmentService.mySubmissions() : Promise.resolve([]),
      ]);
      setAssignments(list);
      setSubmissions(subs);
    } catch (e: any) {
      setError(e.message ?? "Could not load assignments");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [isStudent]);

  useEffect(() => {
    load();
  }, [load]);

  const onRefresh = () => {
    setRefreshing(true);
    load();
  };

  const handleSubmit = async () => {
    if (!submitTarget) return;
    if (!submitContent.trim()) {
      Alert.alert("Validation", "Please enter your submission content.");
      return;
    }
    setSubmitting(true);
    try {
      await assignmentService.submit(submitTarget.id, submitContent.trim());
      setSubmitTarget(null);
      setSubmitContent("");
      load();
    } catch (e: any) {
      Alert.alert("Error", e.message ?? "Submission failed");
    } finally {
      setSubmitting(false);
    }
  };

  // Summary counts
  const dueCount = assignments.filter((a) => a.status === "pending").length;
  const submittedCount = submissions.length;
  const gradedCount = submissions.filter((s) => s.grade !== null && s.grade !== undefined).length;

  const header = (
    <>
      <Text style={styles.eyebrow}>ACADEMIC WORK</Text>
      <Text style={styles.title}>Assignments</Text>
      <Text style={styles.subtitle}>Track deadlines and submit your coursework.</Text>

      {/* Summary bar */}
      <View style={styles.summaryBar}>
        <View style={styles.summaryItem}>
          <Text style={[styles.summaryValue, { color: palette.orange }]}>{dueCount}</Text>
          <Text style={styles.summaryLabel}>Due soon</Text>
        </View>
        <View style={styles.summaryDivider} />
        <View style={styles.summaryItem}>
          <Text style={[styles.summaryValue, { color: palette.primary }]}>{submittedCount}</Text>
          <Text style={styles.summaryLabel}>Submitted</Text>
        </View>
        <View style={styles.summaryDivider} />
        <View style={styles.summaryItem}>
          <Text style={[styles.summaryValue, { color: palette.green }]}>{gradedCount}</Text>
          <Text style={styles.summaryLabel}>Graded</Text>
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
        <Pressable style={styles.retryBtn} onPress={() => { setLoading(true); load(); }}>
          <Text style={styles.retryBtnText}>Retry</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <>
      <FlatList
        style={styles.container}
        contentContainerStyle={styles.content}
        data={assignments}
        keyExtractor={(item) => String(item.id)}
        ListHeaderComponent={header}
        renderItem={({ item }) => (
          <AssignmentCard
            item={item}
            isStudent={!!isStudent}
            onSubmit={(a) => setSubmitTarget(a)}
          />
        )}
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
            <View style={styles.emptyIconWrap}>
              <Text style={styles.emptyIcon}>&#10003;</Text>
            </View>
            <Text style={styles.emptyTitle}>
              {isTeacher ? "No assignments created yet" : "No assignments yet"}
            </Text>
            <Text style={styles.emptyText}>
              {isTeacher
                ? "Assignments you create will appear here."
                : "New coursework from your enrolled classes will appear here."}
            </Text>
          </View>
        }
      />

      {/* Submit modal */}
      <Modal
        visible={!!submitTarget}
        animationType="slide"
        transparent
        onRequestClose={() => setSubmitTarget(null)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalSheet}>
            <Text style={styles.modalTitle}>Submit: {submitTarget?.title}</Text>
            <TextInput
              style={styles.modalInput}
              placeholder="Write your answer here..."
              placeholderTextColor="#adb5bd"
              multiline
              numberOfLines={6}
              value={submitContent}
              onChangeText={setSubmitContent}
              textAlignVertical="top"
            />
            <View style={styles.modalActions}>
              <Pressable
                style={styles.modalCancel}
                onPress={() => { setSubmitTarget(null); setSubmitContent(""); }}
              >
                <Text style={styles.modalCancelText}>Cancel</Text>
              </Pressable>
              <Pressable
                style={[styles.modalSubmit, submitting && styles.modalSubmitDisabled]}
                onPress={handleSubmit}
                disabled={submitting}
              >
                {submitting ? (
                  <ActivityIndicator size="small" color="#fff" />
                ) : (
                  <Text style={styles.modalSubmitText}>Submit</Text>
                )}
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: palette.background },
  content: { padding: 20, paddingBottom: 48 },
  center: { flex: 1, justifyContent: "center", alignItems: "center", backgroundColor: palette.background },
  eyebrow: { color: palette.muted, fontSize: 11, fontWeight: "700", letterSpacing: 1, marginBottom: 4 },
  title: { color: palette.ink, fontSize: 27, fontWeight: "800" },
  subtitle: { color: palette.muted, fontSize: 14, marginTop: 6, marginBottom: 20 },
  summaryBar: {
    flexDirection: "row",
    backgroundColor: palette.primary,
    borderRadius: 16,
    padding: 18,
    marginBottom: 22,
  },
  summaryItem: { flex: 1, alignItems: "center" },
  summaryValue: { fontSize: 24, fontWeight: "800", color: "#fff" },
  summaryLabel: { fontSize: 11, color: "#dfe5ff", marginTop: 3 },
  summaryDivider: { width: 1, backgroundColor: "rgba(255,255,255,0.25)" },
  card: {
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 14,
    borderWidth: 1,
    marginBottom: 12,
    padding: 16,
  },
  cardHeader: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: 8 },
  statusBadge: { borderRadius: 20, paddingHorizontal: 10, paddingVertical: 4 },
  statusText: { fontSize: 11, fontWeight: "700" },
  dueText: { fontSize: 12, fontWeight: "600" },
  cardTitle: { fontSize: 15, fontWeight: "700", color: palette.ink },
  cardSub: { fontSize: 12, color: palette.muted, marginTop: 3 },
  cardDesc: { fontSize: 13, color: "#495057", marginTop: 6, lineHeight: 19 },
  submitBtn: {
    marginTop: 12,
    backgroundColor: palette.primary,
    borderRadius: 8,
    paddingVertical: 9,
    alignItems: "center",
  },
  submitBtnText: { color: "#fff", fontWeight: "700", fontSize: 13 },
  emptyCard: {
    alignItems: "center",
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 16,
    borderWidth: 1,
    padding: 28,
    marginTop: 8,
  },
  emptyIconWrap: { alignItems: "center", backgroundColor: palette.greenSoft, borderRadius: 15, height: 54, justifyContent: "center", width: 54 },
  emptyIcon: { color: palette.green, fontSize: 26, fontWeight: "800" },
  emptyTitle: { color: palette.ink, fontSize: 16, fontWeight: "800", marginTop: 14 },
  emptyText: { color: palette.muted, fontSize: 13, lineHeight: 19, marginTop: 6, textAlign: "center" },
  errorText: { color: palette.accent, fontSize: 15, marginBottom: 12 },
  retryBtn: {
    backgroundColor: palette.primary,
    borderRadius: 8,
    paddingHorizontal: 20,
    paddingVertical: 10,
  },
  retryBtnText: { color: "#fff", fontWeight: "700" },
  // Modal
  modalOverlay: { flex: 1, backgroundColor: "rgba(0,0,0,0.4)", justifyContent: "flex-end" },
  modalSheet: {
    backgroundColor: palette.surface,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: 24,
    paddingBottom: 40,
  },
  modalTitle: { fontSize: 17, fontWeight: "800", color: palette.ink, marginBottom: 14 },
  modalInput: {
    backgroundColor: "#f5f7fb",
    borderRadius: 10,
    borderWidth: 1,
    borderColor: palette.border,
    padding: 12,
    fontSize: 14,
    color: palette.ink,
    minHeight: 130,
    marginBottom: 16,
  },
  modalActions: { flexDirection: "row", gap: 10 },
  modalCancel: {
    flex: 1,
    backgroundColor: "#f1f3f5",
    borderRadius: 10,
    paddingVertical: 13,
    alignItems: "center",
  },
  modalCancelText: { color: "#495057", fontWeight: "700" },
  modalSubmit: {
    flex: 1,
    backgroundColor: palette.primary,
    borderRadius: 10,
    paddingVertical: 13,
    alignItems: "center",
  },
  modalSubmitDisabled: { opacity: 0.6 },
  modalSubmitText: { color: "#fff", fontWeight: "700" },
});
