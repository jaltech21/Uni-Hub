/**
 * AssignmentsScreen — role-aware academic work.
 * - Students: see their visible assignments (pending + graded stats) and submit.
 * - Teachers/tutors: see the assignments they created, create new ones,
 *   review submissions, and grade with feedback.
 */

import React, { useCallback, useEffect, useState } from "react";
import {
  ActivityIndicator,
  Alert,
  FlatList,
  Modal,
  Pressable,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { useAuth } from "@context/AuthContext";
import assignmentService from "@services/assignments";
import scheduleService from "@services/schedules";
import { Assignment, Schedule, Submission } from "@app/types";

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

const CATEGORIES = ["homework", "project", "quiz", "exam"] as const;

function dueLabel(dateStr: string): string {
  const due = new Date(dateStr);
  const now = new Date();
  const diff = Math.ceil((due.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
  if (diff < 0) return "Overdue";
  if (diff === 0) return "Due today";
  if (diff === 1) return "Due tomorrow";
  return `Due in ${diff} days`;
}

export default function AssignmentsScreen() {
  const { isStudent, isTeacher } = useAuth();
  const teacherMode = !!isTeacher;

  const [assignments, setAssignments] = useState<Assignment[]>([]);
  const [submissions, setSubmissions] = useState<Submission[]>([]);
  const [schedules, setSchedules] = useState<Schedule[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Submit modal state (student)
  const [submitTarget, setSubmitTarget] = useState<Assignment | null>(null);
  const [submitContent, setSubmitContent] = useState("");
  const [submitting, setSubmitting] = useState(false);

  // Create modal state (teacher/tutor)
  const [createOpen, setCreateOpen] = useState(false);
  const [creating, setCreating] = useState(false);
  const [cfTitle, setCfTitle] = useState("");
  const [cfDescription, setCfDescription] = useState("");
  const [cfDueDate, setCfDueDate] = useState("");
  const [cfPoints, setCfPoints] = useState("100");
  const [cfCategory, setCfCategory] = useState<string>("homework");
  const [cfCourseName, setCfCourseName] = useState("");
  const [cfScheduleId, setCfScheduleId] = useState<number | undefined>(undefined);
  const [cfCriteria, setCfCriteria] = useState("");
  const [allowResubmission, setAllowResubmission] = useState(true);

  // Manage/grading state (teacher/tutor)
  const [manageTarget, setManageTarget] = useState<Assignment | null>(null);
  const [manageRows, setManageRows] = useState<Submission[]>([]);
  const [gradingId, setGradingId] = useState<number | null>(null);

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

  useEffect(() => {
    if (teacherMode) {
      scheduleService
        .list()
        .then(setSchedules)
        .catch(() => undefined);
    }
  }, [teacherMode]);

  const onRefresh = () => {
    setRefreshing(true);
    load();
  };

  // ── Student submit ─────────────────────────────────────────────
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

  // ── Teacher create ─────────────────────────────────────────────
  const openCreate = () => {
    setCfTitle("");
    setCfDescription("");
    setCfDueDate("");
    setCfPoints("100");
    setCfCategory("homework");
    setCfCourseName("");
    setCfScheduleId(schedules[0]?.id ?? undefined);
    setCfCriteria("");
    setAllowResubmission(true);
    setCreateOpen(true);
  };

  const handleCreate = async () => {
    if (!cfTitle.trim() || !cfDescription.trim() || !cfDueDate.trim()) {
      Alert.alert("Validation", "Title, description and due date are required.");
      return;
    }
    const points = Number(cfPoints);
    if (Number.isNaN(points) || points < 0) {
      Alert.alert("Validation", "Points must be a non-negative number.");
      return;
    }
    let due: Date;
    try {
      due = new Date(cfDueDate);
      if (Number.isNaN(due.getTime())) {
        throw new Error("bad date");
      }
    } catch {
      Alert.alert("Validation", "Due date must be a valid date (YYYY-MM-DD).");
      return;
    }
    setCreating(true);
    try {
      await assignmentService.create({
        title: cfTitle.trim(),
        description: cfDescription.trim(),
        due_date: due.toISOString(),
        points,
        category: cfCategory,
        grading_criteria: cfCriteria.trim() || undefined,
        allow_resubmission: allowResubmission,
        course_name: cfCourseName.trim() || undefined,
        schedule_id: cfScheduleId,
      });
      setCreateOpen(false);
      load();
    } catch (e: any) {
      Alert.alert("Error", e.message ?? "Could not create assignment");
    } finally {
      setCreating(false);
    }
  };

  // ── Teacher manage / grade ─────────────────────────────────────
  const openManage = async (assignment: Assignment) => {
    setManageTarget(assignment);
    setManageRows([]);
    setGradingId(null);
    try {
      const rows = await assignmentService.submissions(assignment.id);
      setManageRows(rows);
    } catch (e: any) {
      Alert.alert("Error", e.message ?? "Could not load submissions");
    }
  };

  const updateRow = (id: number, patch: Partial<Submission>) => {
    setManageRows((prev) =>
      prev.map((row) => (row.id === id ? { ...row, ...patch } : row))
    );
  };

  const gradeRow = async (row: Submission) => {
    const grade = Number(row.grade);
    if (Number.isNaN(grade) || String(row.grade).trim() === "") {
      Alert.alert("Validation", "Enter a numeric grade.");
      return;
    }
    setGradingId(row.id);
    try {
      await assignmentService.grade(row.id, grade, row.feedback ?? undefined);
      updateRow(row.id, { status: "graded", graded_at: new Date().toISOString() });
      load();
    } catch (e: any) {
      Alert.alert("Grade failed", e.message ?? "Could not grade this submission");
    } finally {
      setGradingId(null);
    }
  };

  // ── Summary ────────────────────────────────────────────────────
  const dueCount = assignments.filter((a) => a.status === "pending").length;
  const submittedCount = submissions.length;
  const gradedCount = submissions.filter(
    (s) => s.grade !== null && s.grade !== undefined
  ).length;
  const createdCount = assignments.length;
  const withSubmissions = assignments.filter((a) => a.status !== "pending").length;
  const gradedAssignments = assignments.filter((a) => a.status === "graded").length;

  let summary: Array<{ value: number; label: string; color: string }>;
  if (isStudent) {
    summary = [
      { value: dueCount, label: "Due soon", color: palette.orange },
      { value: submittedCount, label: "Submitted", color: palette.primary },
      { value: gradedCount, label: "Graded", color: palette.green },
    ];
  } else {
    summary = [
      { value: createdCount, label: "Created", color: palette.primary },
      { value: withSubmissions, label: "Submitted", color: palette.orange },
      { value: gradedAssignments, label: "Graded", color: palette.green },
    ];
  }

  const header = (
    <>
      <View style={styles.headerRow}>
        <View style={{ flex: 1 }}>
          <Text style={styles.eyebrow}>ACADEMIC WORK</Text>
          <Text style={styles.title}>Assignments</Text>
          <Text style={styles.subtitle}>
            {teacherMode
              ? "Create assignments and grade submissions."
              : "Track deadlines and submit your coursework."}
          </Text>
        </View>
        {teacherMode ? (
          <Pressable style={styles.addBtn} onPress={openCreate}>
            <Text style={styles.addBtnText}>+ New</Text>
          </Pressable>
        ) : null}
      </View>

      <View style={styles.summaryBar}>
        {summary.map((s, i) => (
          <React.Fragment key={s.label}>
            {i > 0 ? <View style={styles.summaryDivider} /> : null}
            <View style={styles.summaryItem}>
              <Text style={[styles.summaryValue, { color: s.color }]}>{s.value}</Text>
              <Text style={styles.summaryLabel}>{s.label}</Text>
            </View>
          </React.Fragment>
        ))}
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
        renderItem={({ item }) => {
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
              {item.course_name ? <Text style={styles.cardSub}>{item.course_name}</Text> : null}
              {item.category ? <Text style={styles.cardCat}>{item.category}</Text> : null}
              {item.description ? (
                <Text style={styles.cardDesc} numberOfLines={2}>{item.description}</Text>
              ) : null}

              {isStudent && status === "pending" ? (
                <Pressable style={styles.submitBtn} onPress={() => setSubmitTarget(item)}>
                  <Text style={styles.submitBtnText}>Submit</Text>
                </Pressable>
              ) : null}
              {teacherMode ? (
                <Pressable style={styles.manageBtn} onPress={() => openManage(item)}>
                  <Text style={styles.manageBtnText}>Review submissions</Text>
                </Pressable>
              ) : null}
            </View>
          );
        }}
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
              {teacherMode ? "No assignments created yet" : "No assignments yet"}
            </Text>
            <Text style={styles.emptyText}>
              {teacherMode
                ? "Tap “+ New” to create your first assignment."
                : "New coursework from your enrolled classes will appear here."}
            </Text>
          </View>
        }
      />

      {/* Student: Submit modal */}
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
              <Pressable style={styles.modalCancel} onPress={() => { setSubmitTarget(null); setSubmitContent(""); }}>
                <Text style={styles.modalCancelText}>Cancel</Text>
              </Pressable>
              <Pressable
                style={[styles.modalSubmit, submitting && styles.modalDisabled]}
                onPress={handleSubmit}
                disabled={submitting}
              >
                {submitting ? <ActivityIndicator size="small" color="#fff" /> : <Text style={styles.modalSubmitText}>Submit</Text>}
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>

      {/* Teacher: Create modal */}
      <Modal
        visible={createOpen}
        animationType="slide"
        transparent
        onRequestClose={() => setCreateOpen(false)}
      >
        <View style={styles.modalOverlay}>
          <ScrollView style={styles.modalSheetScroll} contentContainerStyle={styles.modalSheet}>
            <Text style={styles.modalTitle}>New Assignment</Text>
            <Text style={styles.modalHint}>Publish coursework for your class.</Text>

            <Text style={styles.inputLabel}>Title</Text>
            <TextInput style={styles.input} value={cfTitle} onChangeText={setCfTitle} placeholder="e.g. Week 5 problem set" placeholderTextColor="#adb5bd" />
            <Text style={styles.inputLabel}>Description</Text>
            <TextInput style={styles.inputArea} value={cfDescription} onChangeText={setCfDescription} placeholder="Instructions for students…" placeholderTextColor="#adb5bd" multiline textAlignVertical="top" />
            <Text style={styles.inputLabel}>Due date (YYYY-MM-DD)</Text>
            <TextInput style={styles.input} value={cfDueDate} onChangeText={setCfDueDate} placeholder="2026-12-01" placeholderTextColor="#adb5bd" />
            <Text style={styles.inputLabel}>Points</Text>
            <TextInput style={styles.input} value={cfPoints} onChangeText={setCfPoints} keyboardType="numeric" placeholder="100" placeholderTextColor="#adb5bd" />
            <Text style={styles.inputLabel}>Category</Text>
            <View style={styles.chipWrap}>
              {CATEGORIES.map((cat) => (
                <Pressable key={cat} style={[styles.chip, cfCategory === cat && styles.chipActive]} onPress={() => setCfCategory(cat)}>
                  <Text style={[styles.chipText, cfCategory === cat && styles.chipTextActive]}>{cat}</Text>
                </Pressable>
              ))}
            </View>

            {schedules.length > 0 ? (
              <>
                <Text style={styles.inputLabel}>Class</Text>
                <View style={styles.chipWrap}>
                  {schedules.map((s) => (
                    <Pressable key={s.id} style={[styles.chip, cfScheduleId === s.id && styles.chipActive]} onPress={() => setCfScheduleId(s.id)}>
                      <Text style={[styles.chipText, cfScheduleId === s.id && styles.chipTextActive]} numberOfLines={1}>
                        {s.course_name || s.title}
                      </Text>
                    </Pressable>
                  ))}
                </View>
              </>
            ) : (
              <Text style={styles.noCourseHint}>
                No taught classes found — add a course name below instead.
              </Text>
            )}
            <Text style={styles.inputLabel}>Course name (optional)</Text>
            <TextInput style={styles.input} value={cfCourseName} onChangeText={setCfCourseName} placeholder="e.g. BUS 201" placeholderTextColor="#adb5bd" />

            <Text style={styles.inputLabel}>Grading criteria (optional)</Text>
            <TextInput style={styles.inputArea} value={cfCriteria} onChangeText={setCfCriteria} placeholder="e.g. Clarity, depth, references…" placeholderTextColor="#adb5bd" multiline textAlignVertical="top" />

            <View style={styles.switchRow}>
              <Text style={styles.switchLabel}>Allow resubmission</Text>
              <Pressable
                style={[styles.switchTrack, allowResubmission && styles.switchTrackOn]}
                onPress={() => setAllowResubmission((v) => !v)}
              >
                <View style={[styles.switchKnob, allowResubmission && styles.switchKnobOn]} />
              </Pressable>
            </View>

            <View style={styles.modalActions}>
              <Pressable style={styles.modalCancel} onPress={() => setCreateOpen(false)}>
                <Text style={styles.modalCancelText}>Cancel</Text>
              </Pressable>
              <Pressable style={[styles.modalSubmit, creating && styles.modalDisabled]} onPress={handleCreate} disabled={creating}>
                {creating ? <ActivityIndicator size="small" color="#fff" /> : <Text style={styles.modalSubmitText}>Create</Text>}
              </Pressable>
            </View>
          </ScrollView>
        </View>
      </Modal>

      {/* Teacher: Manage submissions modal */}
      <Modal
        visible={!!manageTarget}
        animationType="slide"
        transparent
        onRequestClose={() => setManageTarget(null)}
      >
        <View style={styles.modalOverlay}>
          <ScrollView style={styles.modalSheetScroll} contentContainerStyle={styles.modalSheet}>
            <View style={styles.modalHeaderRow}>
              <View style={{ flex: 1 }}>
                <Text style={styles.modalTitle}>{manageTarget?.title}</Text>
                <Text style={styles.modalHint}>
                  {manageRows.length === 0
                    ? "No submissions yet."
                    : `${manageRows.length} submission${manageRows.length === 1 ? "" : "s"} to grade.`}
                </Text>
              </View>
              <Pressable style={styles.closeX} onPress={() => setManageTarget(null)}>
                <Text style={styles.closeXText}>&#10005;</Text>
              </Pressable>
            </View>

            {manageRows.map((row) => (
              <View key={row.id} style={styles.rowCard}>
                <Text style={styles.rowName}>{row.student_name || `Student #${row.student_id}`}</Text>
                {row.content ? <Text style={styles.rowContent} numberOfLines={4}>{row.content}</Text> : null}
                <View style={styles.gradeRow}>
                  <TextInput
                    style={[styles.input, styles.gradeInput]}
                    value={row.grade !== null && row.grade !== undefined ? String(row.grade) : ""}
                    onChangeText={(t) => updateRow(row.id, { grade: t === "" ? null : Number(t) })}
                    keyboardType="numeric"
                    placeholder="Grade"
                    placeholderTextColor="#adb5bd"
                  />
                  <Text style={styles.gradeStatus}>
                    {row.grade !== null && row.grade !== undefined ? "Graded" : "Pending"}
                  </Text>
                </View>
                <Text style={styles.inputLabel}>Feedback</Text>
                <TextInput
                  style={styles.inputArea}
                  value={row.feedback ?? ""}
                  onChangeText={(t) => updateRow(row.id, { feedback: t })}
                  placeholder="Notes for the student…"
                  placeholderTextColor="#adb5bd"
                  multiline
                  textAlignVertical="top"
                />
                <Pressable
                  style={[styles.submitBtn, gradingId === row.id && styles.modalDisabled]}
                  onPress={() => gradeRow(row)}
                  disabled={gradingId === row.id}
                >
                  {gradingId === row.id ? (
                    <ActivityIndicator size="small" color="#fff" />
                  ) : (
                    <Text style={styles.submitBtnText}>
                      {row.grade !== null && row.grade !== undefined ? "Update grade" : "Save grade"}
                    </Text>
                  )}
                </Pressable>
              </View>
            ))}

            {manageTarget ? (
              <View style={styles.modalActions}>
                <Pressable style={styles.modalSubmit} onPress={() => setManageTarget(null)}>
                  <Text style={styles.modalSubmitText}>Close</Text>
                </Pressable>
              </View>
            ) : null}
          </ScrollView>
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
  headerRow: { flexDirection: "row", alignItems: "flex-start", gap: 10 },
  addBtn: { backgroundColor: palette.primary, borderRadius: 10, paddingHorizontal: 14, paddingVertical: 9, marginTop: 6 },
  addBtnText: { color: "#fff", fontWeight: "800", fontSize: 14 },
  summaryBar: { flexDirection: "row", backgroundColor: palette.primary, borderRadius: 16, padding: 18, marginBottom: 22 },
  summaryItem: { flex: 1, alignItems: "center" },
  summaryValue: { fontSize: 24, fontWeight: "800", color: "#fff" },
  summaryLabel: { fontSize: 11, color: "#dfe5ff", marginTop: 3 },
  summaryDivider: { width: 1, backgroundColor: "rgba(255,255,255,0.25)" },
  card: { backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 14, borderWidth: 1, marginBottom: 12, padding: 16 },
  cardHeader: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: 8 },
  statusBadge: { borderRadius: 20, paddingHorizontal: 10, paddingVertical: 4 },
  statusText: { fontSize: 11, fontWeight: "700" },
  dueText: { fontSize: 12, fontWeight: "600" },
  cardTitle: { fontSize: 15, fontWeight: "700", color: palette.ink },
  cardSub: { fontSize: 12, color: palette.muted, marginTop: 3 },
  cardCat: { fontSize: 11, fontWeight: "700", color: palette.muted, textTransform: "uppercase", marginTop: 4 },
  cardDesc: { fontSize: 13, color: "#495057", marginTop: 6, lineHeight: 19 },
  submitBtn: { marginTop: 12, backgroundColor: palette.primary, borderRadius: 8, paddingVertical: 9, alignItems: "center" },
  submitBtnText: { color: "#fff", fontWeight: "700", fontSize: 13 },
  manageBtn: { marginTop: 12, backgroundColor: palette.lavender, borderRadius: 8, paddingVertical: 9, alignItems: "center" },
  manageBtnText: { color: palette.primary, fontWeight: "700", fontSize: 13 },
  emptyCard: { alignItems: "center", backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 16, borderWidth: 1, padding: 28, marginTop: 8 },
  emptyIconWrap: { alignItems: "center", backgroundColor: palette.greenSoft, borderRadius: 15, height: 54, justifyContent: "center", width: 54 },
  emptyIcon: { color: palette.green, fontSize: 26, fontWeight: "800" },
  emptyTitle: { color: palette.ink, fontSize: 16, fontWeight: "800", marginTop: 14 },
  emptyText: { color: palette.muted, fontSize: 13, lineHeight: 19, marginTop: 6, textAlign: "center" },
  errorText: { color: palette.accent, fontSize: 15, marginBottom: 12 },
  retryBtn: { backgroundColor: palette.primary, borderRadius: 8, paddingHorizontal: 20, paddingVertical: 10 },
  retryBtnText: { color: "#fff", fontWeight: "700" },
  // Modal
  modalOverlay: { flex: 1, backgroundColor: "rgba(0,0,0,0.4)", justifyContent: "flex-end" },
  modalSheet: { backgroundColor: palette.surface, borderTopLeftRadius: 20, borderTopRightRadius: 20, padding: 24, paddingBottom: 40 },
  modalSheetScroll: { backgroundColor: palette.surface, borderTopLeftRadius: 20, borderTopRightRadius: 20, maxHeight: "90%" },
  modalHeaderRow: { flexDirection: "row", alignItems: "center", gap: 12 },
  closeX: { width: 34, height: 34, borderRadius: 17, backgroundColor: "#f1f3f5", alignItems: "center", justifyContent: "center" },
  closeXText: { color: "#495057", fontSize: 16, fontWeight: "800" },
  modalTitle: { fontSize: 17, fontWeight: "800", color: palette.ink },
  modalHint: { fontSize: 13, color: palette.muted, marginTop: 4, marginBottom: 8, lineHeight: 19 },
  inputLabel: { fontSize: 12, fontWeight: "700", color: palette.ink, marginTop: 14, marginBottom: 6 },
  input: { backgroundColor: "#f5f7fb", borderRadius: 10, borderWidth: 1, borderColor: palette.border, padding: 12, fontSize: 14, color: palette.ink },
  inputArea: { backgroundColor: "#f5f7fb", borderRadius: 10, borderWidth: 1, borderColor: palette.border, padding: 12, fontSize: 14, color: palette.ink, minHeight: 80 },
  modalInput: { backgroundColor: "#f5f7fb", borderRadius: 10, borderWidth: 1, borderColor: palette.border, padding: 12, fontSize: 14, color: palette.ink, minHeight: 130, marginBottom: 16, marginTop: 14 },
  modalActions: { flexDirection: "row", gap: 10, marginTop: 22 },
  modalCancel: { flex: 1, backgroundColor: "#f1f3f5", borderRadius: 10, paddingVertical: 13, alignItems: "center" },
  modalCancelText: { color: "#495057", fontWeight: "700" },
  modalSubmit: { flex: 1, backgroundColor: palette.primary, borderRadius: 10, paddingVertical: 13, alignItems: "center" },
  modalDisabled: { opacity: 0.6 },
  modalSubmitText: { color: "#fff", fontWeight: "700" },
  chipWrap: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  chip: { backgroundColor: palette.surface, borderColor: palette.border, borderWidth: 1, borderRadius: 18, paddingHorizontal: 14, paddingVertical: 8 },
  chipActive: { backgroundColor: palette.primary, borderColor: palette.primary },
  chipText: { color: palette.ink, fontSize: 13, fontWeight: "700" },
  chipTextActive: { color: "#fff" },
  noCourseHint: { color: palette.muted, fontSize: 12, marginTop: 12, lineHeight: 18 },
  switchRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", marginTop: 16 },
  switchLabel: { color: palette.ink, fontSize: 14, fontWeight: "700" },
  switchTrack: { width: 46, height: 26, borderRadius: 13, backgroundColor: "#e7eaf2", justifyContent: "center", paddingHorizontal: 3 },
  switchTrackOn: { backgroundColor: palette.primary },
  switchKnob: { width: 20, height: 20, borderRadius: 10, backgroundColor: "#fff" },
  switchKnobOn: { alignSelf: "flex-end" },
  rowCard: { borderColor: palette.border, borderWidth: 1, borderRadius: 12, padding: 14, marginBottom: 12 },
  rowName: { color: palette.ink, fontSize: 14, fontWeight: "800" },
  rowContent: { color: "#495057", fontSize: 13, marginTop: 4, lineHeight: 18 },
  gradeRow: { flexDirection: "row", alignItems: "center", marginTop: 12, gap: 10 },
  gradeInput: { maxWidth: 110 },
  gradeStatus: { color: palette.primary, fontSize: 13, fontWeight: "800" },
});