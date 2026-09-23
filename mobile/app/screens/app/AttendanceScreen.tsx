/**
 * AttendanceScreen — role-aware attendance.
 * - Teachers/tutors: create rosters, see the rotating code, and who has marked
 *   attendance. The code is generated on the backend and only serialized for
 *   teachers.
 * - Students: see upcoming rosters from their department schedules and mark
 *   themselves present with the code shown by the teacher.
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
import attendanceService from "@services/attendance";
import scheduleService from "@services/schedules";
import { AttendanceList, AttendanceRecord, Schedule } from "@app/types";

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

function formatDate(dateStr: string): string {
  try {
    return new Date(dateStr).toLocaleDateString(undefined, {
      weekday: "short",
      month: "short",
      day: "numeric",
    });
  } catch {
    return dateStr;
  }
}

export default function AttendanceScreen() {
  const { isTeacher } = useAuth();
  const teacherMode = !!isTeacher;

  const [lists, setLists] = useState<AttendanceList[]>([]);
  const [records, setRecords] = useState<AttendanceRecord[]>([]);
  const [schedules, setSchedules] = useState<Schedule[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Create list modal (teacher)
  const [createOpen, setCreateOpen] = useState(false);
  const [creating, setCreating] = useState(false);
  const [lfTitle, setLfTitle] = useState("");
  const [lfDate, setLfDate] = useState("");
  const [lfDescription, setLfDescription] = useState("");
  const [lfScheduleId, setLfScheduleId] = useState<number | undefined>(undefined);

  // Mark attendance modal (student)
  const [markTarget, setMarkTarget] = useState<AttendanceList | null>(null);
  const [markCode, setMarkCode] = useState("");
  const [marking, setMarking] = useState(false);

  // View roster modal (teacher)
  const [rosterTarget, setRosterTarget] = useState<AttendanceList | null>(null);

  const load = useCallback(async () => {
    try {
      setError(null);
      const [listData, recordData] = await Promise.all([
        attendanceService.lists(),
        attendanceService.records(),
      ]);
      setLists(listData);
      setRecords(recordData);
    } catch (e: any) {
      setError(e.message ?? "Could not load attendance");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

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

  const openCreate = () => {
    setLfTitle("");
    setLfDate("");
    setLfDescription("");
    setLfScheduleId(schedules[0]?.id ?? undefined);
    setCreateOpen(true);
  };

  const handleCreate = async () => {
    if (!lfTitle.trim() || !lfDate.trim()) {
      Alert.alert("Validation", "Title and date are required.");
      return;
    }
    if (lfDate.trim().length < 10) {
      Alert.alert("Validation", "Enter the date as YYYY-MM-DD.");
      return;
    }
    const parsed = new Date(lfDate.trim());
    if (Number.isNaN(parsed.getTime())) {
      Alert.alert("Validation", "Enter a valid date (YYYY-MM-DD).");
      return;
    }
    setCreating(true);
    try {
      await attendanceService.createList({
        title: lfTitle.trim(),
        description: lfDescription.trim() || undefined,
        date: new Date(lfDate.trim() + "T00:00:00Z").toISOString(),
        schedule_id: lfScheduleId,
      });
      setCreateOpen(false);
      load();
    } catch (e: any) {
      Alert.alert("Error", e.message ?? "Could not create the roster");
    } finally {
      setCreating(false);
    }
  };

  const handleMark = async () => {
    if (!markTarget) return;
    if (!markCode.trim()) {
      Alert.alert("Validation", "Enter the code your teacher shared.");
      return;
    }
    setMarking(true);
    try {
      await attendanceService.mark(markTarget.id, markCode.trim());
      setMarkTarget(null);
      setMarkCode("");
      load();
      Alert.alert("Present", "Your attendance has been marked.");
    } catch (e: any) {
      Alert.alert("Could not mark", e.message ?? "Please try again.");
    } finally {
      setMarking(false);
    }
  };

  const header = (
    <>
      <View style={styles.headerRow}>
        <View style={{ flex: 1 }}>
          <Text style={styles.eyebrow}>CLASS PRESENCE</Text>
          <Text style={styles.title}>Attendance</Text>
          <Text style={styles.subtitle}>
            {teacherMode
              ? "Create rosters and share the rotating code with students."
              : "Mark yourself present in your enrolled classes."}
          </Text>
        </View>
        {teacherMode ? (
          <Pressable style={styles.addBtn} onPress={openCreate}>
            <Text style={styles.addBtnText}>+ New</Text>
          </Pressable>
        ) : null}
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
        data={lists}
        keyExtractor={(item) => String(item.id)}
        ListHeaderComponent={header}
        renderItem={({ item }) => {
          const roster = records.filter((r) => r.attendance_list_id === item.id);
          const alreadyMarked = roster.some((r) => r.student_name);
          return (
            <View style={styles.card}>
              <View style={styles.cardHeader}>
                <Text style={styles.cardTitle}>{item.title}</Text>
                <Text style={styles.cardDate}>{formatDate(item.list_date)}</Text>
              </View>
              {item.description ? (
                <Text style={styles.cardDesc} numberOfLines={2}>{item.description}</Text>
              ) : null}

              {teacherMode ? (
                <>
                  <View style={styles.codeBox}>
                    <Text style={styles.codeLabel}>ATTENDANCE CODE</Text>
                    <Text style={styles.codeValue}>
                      {item.attendance_code || "—"}
                    </Text>
                    <Text style={styles.codeHint}>
                      Rotates every 2 minutes. Share it with students to mark
                      this roster.
                    </Text>
                  </View>
                  <Pressable
                    style={styles.manageBtn}
                    onPress={() => setRosterTarget(item)}
                    disabled={false}
                  >
                    <Text style={styles.manageBtnText}>
                      View roster ({roster.length})
                    </Text>
                  </Pressable>
                </>
              ) : (
                <Pressable
                  style={styles.markBtn}
                  onPress={() => {
                    setMarkTarget(item);
                    setMarkCode("");
                  }}
                >
                  <Text style={styles.markBtnText}>
                    {alreadyMarked ? "Marked ✓" : "Mark present"}
                  </Text>
                </Pressable>
              )}
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
              <Text style={styles.emptyIcon}>&#10004;</Text>
            </View>
            <Text style={styles.emptyTitle}>
              {teacherMode ? "No attendance rosters yet" : "No open rosters"}
            </Text>
            <Text style={styles.emptyText}>
              {teacherMode
                ? "Tap “+ New” to create a roster and generate a code."
                : "Rosters from your classes will appear here."}
            </Text>
          </View>
        }
      />

      {/* Teacher: create roster modal */}
      <Modal
        visible={createOpen}
        animationType="slide"
        transparent
        onRequestClose={() => setCreateOpen(false)}
      >
        <View style={styles.modalOverlay}>
          <ScrollView style={styles.modalSheetScroll} contentContainerStyle={styles.modalSheet}>
            <Text style={styles.modalTitle}>New attendance roster</Text>
            <Text style={styles.modalHint}>
              Create a roster for a class meeting; a rotating code will be
              generated for students to mark.
            </Text>
            <Text style={styles.inputLabel}>Title</Text>
            <TextInput
              style={styles.input}
              value={lfTitle}
              onChangeText={setLfTitle}
              placeholder="e.g. BUS 201 Lecture"
              placeholderTextColor="#adb5bd"
            />
            <Text style={styles.inputLabel}>Date (YYYY-MM-DD)</Text>
            <TextInput
              style={styles.input}
              value={lfDate}
              onChangeText={setLfDate}
              placeholder="2026-09-25"
              placeholderTextColor="#adb5bd"
            />
            {schedules.length > 0 ? (
              <>
                <Text style={styles.inputLabel}>Class</Text>
                <View style={styles.chipWrap}>
                  {schedules.map((s) => (
                    <Pressable
                      key={s.id}
                      style={[styles.chip, lfScheduleId === s.id && styles.chipActive]}
                      onPress={() => setLfScheduleId(s.id)}
                    >
                      <Text
                        style={[styles.chipText, lfScheduleId === s.id && styles.chipTextActive]}
                        numberOfLines={1}
                      >
                        {s.course_name || s.title}
                      </Text>
                    </Pressable>
                  ))}
                </View>
              </>
            ) : (
              <Text style={styles.noCourseHint}>
                No taught classes found — the roster stays unassigned to a
                schedule and students won't be notified.
              </Text>
            )}
            <Text style={styles.inputLabel}>Description (optional)</Text>
            <TextInput
              style={styles.inputArea}
              value={lfDescription}
              onChangeText={setLfDescription}
              placeholder="Room, topic, notes..."
              placeholderTextColor="#adb5bd"
              multiline
              textAlignVertical="top"
            />
            <View style={styles.modalActions}>
              <Pressable style={styles.modalCancel} onPress={() => setCreateOpen(false)}>
                <Text style={styles.modalCancelText}>Cancel</Text>
              </Pressable>
              <Pressable
                style={[styles.modalPrimary, creating && styles.modalDisabled]}
                onPress={handleCreate}
                disabled={creating}
              >
                {creating ? (
                  <ActivityIndicator size="small" color="#fff" />
                ) : (
                  <Text style={styles.modalPrimaryText}>Create</Text>
                )}
              </Pressable>
            </View>
          </ScrollView>
        </View>
      </Modal>

      {/* Student: mark modal */}
      <Modal
        visible={!!markTarget}
        animationType="slide"
        transparent
        onRequestClose={() => setMarkTarget(null)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalSheet}>
            <Text style={styles.modalTitle}>
              Mark present · {markTarget?.title}
            </Text>
            <Text style={styles.modalHint}>
              Enter the code your teacher shared for this roster. Codes rotate
              every 2 minutes.
            </Text>
            <TextInput
              style={styles.codeInput}
              value={markCode}
              onChangeText={setMarkCode}
              placeholder="Enter code"
              placeholderTextColor="#adb5bd"
              autoCapitalize="characters"
              autoCorrect={false}
            />
            <View style={styles.modalActions}>
              <Pressable style={styles.modalCancel} onPress={() => setMarkTarget(null)}>
                <Text style={styles.modalCancelText}>Cancel</Text>
              </Pressable>
              <Pressable
                style={[styles.modalPrimary, marking && styles.modalDisabled]}
                onPress={handleMark}
                disabled={marking}
              >
                {marking ? (
                  <ActivityIndicator size="small" color="#fff" />
                ) : (
                  <Text style={styles.modalPrimaryText}>Mark present</Text>
                )}
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>

      {/* Teacher: roster modal */}
      <Modal
        visible={!!rosterTarget}
        animationType="slide"
        transparent
        onRequestClose={() => setRosterTarget(null)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalSheet}>
            <View style={styles.modalHeaderRow}>
              <View style={{ flex: 1 }}>
                <Text style={styles.modalTitle}>{rosterTarget?.title}</Text>
                <Text style={styles.modalHint}>
                  {rosterTarget ? formatDate(rosterTarget.list_date) : ""} ·{" "}
                  {records.filter((r) => r.attendance_list_id === rosterTarget?.id).length}{" "}
                  present
                </Text>
              </View>
              <Pressable style={styles.closeX} onPress={() => setRosterTarget(null)}>
                <Text style={styles.closeXText}>&#10005;</Text>
              </Pressable>
            </View>
            {records
              .filter((r) => r.attendance_list_id === rosterTarget?.id)
              .map((r) => (
                <View key={r.id} style={styles.presentRow}>
                  <Text style={styles.presentName}>
                    {r.student_name || `Student #${r.student_id}`}
                  </Text>
                  <Text style={styles.presentTag}>Present</Text>
                </View>
              ))}
            {records.filter((r) => r.attendance_list_id === rosterTarget?.id)
              .length === 0 ? (
              <Text style={styles.emptyRoster}>
                No students have marked attendance yet. Share the code shown on
                the roster card.
              </Text>
            ) : null}
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
  headerRow: { flexDirection: "row", alignItems: "flex-start", gap: 10 },
  addBtn: { backgroundColor: palette.primary, borderRadius: 10, paddingHorizontal: 14, paddingVertical: 9, marginTop: 6 },
  addBtnText: { color: "#fff", fontWeight: "800", fontSize: 14 },
  card: { backgroundColor: palette.surface, borderColor: palette.border, borderRadius: 14, borderWidth: 1, marginBottom: 12, padding: 16 },
  cardHeader: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: 6 },
  cardTitle: { fontSize: 15, fontWeight: "700", color: palette.ink, flex: 1 },
  cardDate: { fontSize: 12, fontWeight: "700", color: palette.primary },
  cardDesc: { fontSize: 13, color: "#495057", marginTop: 4, lineHeight: 19 },
  codeBox: { backgroundColor: palette.ink, borderRadius: 12, padding: 14, marginTop: 12, alignItems: "center" },
  codeLabel: { color: "rgba(255,255,255,0.6)", fontSize: 10, fontWeight: "800", letterSpacing: 1.2 },
  codeValue: { color: "#fff", fontSize: 24, fontWeight: "900", letterSpacing: 4, marginTop: 6 },
  codeHint: { color: "rgba(255,255,255,0.55)", fontSize: 11, marginTop: 6, textAlign: "center" },
  manageBtn: { marginTop: 12, backgroundColor: palette.lavender, borderRadius: 8, paddingVertical: 10, alignItems: "center" },
  manageBtnText: { color: palette.primary, fontWeight: "700", fontSize: 13 },
  markBtn: { marginTop: 12, backgroundColor: palette.green, borderRadius: 8, paddingVertical: 10, alignItems: "center" },
  markBtnText: { color: "#fff", fontWeight: "700", fontSize: 13 },
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
  modalHint: { fontSize: 13, color: palette.muted, marginTop: 4, marginBottom: 10, lineHeight: 19 },
  inputLabel: { fontSize: 12, fontWeight: "700", color: palette.ink, marginTop: 14, marginBottom: 6 },
  input: { backgroundColor: "#f5f7fb", borderRadius: 10, borderWidth: 1, borderColor: palette.border, padding: 12, fontSize: 14, color: palette.ink },
  inputArea: { backgroundColor: "#f5f7fb", borderRadius: 10, borderWidth: 1, borderColor: palette.border, padding: 12, fontSize: 14, color: palette.ink, minHeight: 80 },
  codeInput: { backgroundColor: "#f5f7fb", borderRadius: 10, borderWidth: 1, borderColor: palette.border, padding: 14, fontSize: 18, color: palette.ink, letterSpacing: 3, fontWeight: "800" },
  modalActions: { flexDirection: "row", gap: 10, marginTop: 22 },
  modalCancel: { flex: 1, backgroundColor: "#f1f3f5", borderRadius: 10, paddingVertical: 13, alignItems: "center" },
  modalCancelText: { color: "#495057", fontWeight: "700" },
  modalPrimary: { flex: 1, backgroundColor: palette.primary, borderRadius: 10, paddingVertical: 13, alignItems: "center" },
  modalDisabled: { opacity: 0.6 },
  modalPrimaryText: { color: "#fff", fontWeight: "700" },
  chipWrap: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  chip: { backgroundColor: palette.surface, borderColor: palette.border, borderWidth: 1, borderRadius: 18, paddingHorizontal: 14, paddingVertical: 8 },
  chipActive: { backgroundColor: palette.primary, borderColor: palette.primary },
  chipText: { color: palette.ink, fontSize: 13, fontWeight: "700" },
  chipTextActive: { color: "#fff" },
  noCourseHint: { color: palette.muted, fontSize: 12, marginTop: 12, lineHeight: 18 },
  presentRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", borderColor: palette.border, borderWidth: 1, borderRadius: 10, padding: 12, marginBottom: 8 },
  presentName: { color: palette.ink, fontSize: 14, fontWeight: "700" },
  presentTag: { color: palette.green, fontSize: 12, fontWeight: "800" },
  emptyRoster: { color: palette.muted, fontSize: 13, textAlign: "center", padding: 20, lineHeight: 19 },
});