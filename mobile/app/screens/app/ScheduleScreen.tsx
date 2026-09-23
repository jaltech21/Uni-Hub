/**
 * ScheduleScreen — live wired to ScheduleService.
 * Lists the user's schedules (enrolled or owned) and lets them add a
 * personal event via the add-event modal (POST /schedules).
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
import scheduleService from "@services/schedules";
import { useAuth } from "@context/AuthContext";
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

const DAYS = [
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
  "Sunday",
];

const dayShorthand: Record<string, string> = {
  Sunday: "Sun",
  Monday: "Mon",
  Tuesday: "Tue",
  Wednesday: "Wed",
  Thursday: "Thu",
  Friday: "Fri",
  Saturday: "Sat",
};

function ScheduleCard({ item }: { item: Schedule }) {
  const dayLabel = dayShorthand[item.day_name ?? ""] ?? item.day_name ?? item.day_of_week;
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

function BrowseCard({
  item,
  busy,
  onEnroll,
}: {
  item: Schedule;
  busy: boolean;
  onEnroll: () => void;
}) {
  return (
    <View style={styles.browseCard}>
      <View style={styles.browseCardBody}>
        <Text style={styles.browseCardTitle}>{item.title}</Text>
        {item.course_name ? (
          <Text style={styles.browseCardSub}>{item.course_name}</Text>
        ) : null}
        <Text style={styles.browseCardMeta}>
          {item.day_name ?? ""} · {item.start_time?.slice(0, 5)} –{" "}
          {item.end_time?.slice(0, 5)}
          {item.instructor_name ? ` · ${item.instructor_name}` : ""}
        </Text>
      </View>
      <Pressable
        style={[styles.enrollBtn, busy && styles.modalDisabled]}
        onPress={onEnroll}
        disabled={busy}
      >
        {busy ? (
          <ActivityIndicator size="small" color="#fff" />
        ) : (
          <Text style={styles.enrollBtnText}>Enroll</Text>
        )}
      </Pressable>
    </View>
  );
}

export default function ScheduleScreen() {
  const { isStudent } = useAuth();
  const [schedules, setSchedules] = useState<Schedule[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Add-event modal state
  const [modalOpen, setModalOpen] = useState(false);
  const [form, setForm] = useState({
    title: "",
    course: "",
    day: "Monday",
    start: "09:00",
    end: "10:00",
    room: "",
  });
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  // Browse / enroll state (student only)
  const [browseOpen, setBrowseOpen] = useState(false);
  const [browseList, setBrowseList] = useState<Schedule[]>([]);
  const [browseLoading, setBrowseLoading] = useState(false);
  const [enrollingId, setEnrollingId] = useState<number | null>(null);

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

  const openBrowse = useCallback(async () => {
    setBrowseOpen(true);
    setBrowseLoading(true);
    setBrowseList([]);
    try {
      const data = await scheduleService.browse();
      setBrowseList(data);
    } catch (e: any) {
      Alert.alert("Could not load courses", e.message ?? "Please try again.");
    } finally {
      setBrowseLoading(false);
    }
  }, []);

  const handleEnroll = useCallback(
    async (scheduleId: number) => {
      setEnrollingId(scheduleId);
      try {
        await scheduleService.enroll(scheduleId);
        setBrowseList((prev) => prev.filter((s) => s.id !== scheduleId));
        Alert.alert("Enrolled", "You are now enrolled in this course.");
        await load();
      } catch (e: any) {
        const message =
          e?.apiError?.code === "ALREADY_ENROLLED"
            ? "You are already enrolled in this course."
            : e.message ?? "Could not enroll. Please try again.";
        Alert.alert("Enrollment failed", message);
      } finally {
        setEnrollingId(null);
      }
    },
    [load]
  );


  const onRefresh = () => {
    setRefreshing(true);
    load();
  };

  const openModal = () => {
    setForm({
      title: "",
      course: "",
      day: "Monday",
      start: "09:00",
      end: "10:00",
      room: "",
    });
    setFormError(null);
    setModalOpen(true);
  };

  const isValidTime = (value: string) => /^([01]?\d|2[0-3]):[0-5]\d$/.test(value.trim());

  const handleSave = async () => {
    const title = form.title.trim();
    const start = form.start.trim();
    const end = form.end.trim();
    if (!title) {
      setFormError("Give the event a title.");
      return;
    }
    if (!isValidTime(start) || !isValidTime(end)) {
      setFormError("Use 24-hour times like 09:00 and 10:30.");
      return;
    }
    setSaving(true);
    setFormError(null);
    try {
      const saved = await scheduleService.create({
        title,
        course: form.course.trim() || "Personal",
        day_of_week: form.day,
        start_time: start,
        end_time: end,
        room: form.room.trim() || "Study room",
        recurring: true,
      });
      setModalOpen(false);
      setSchedules((prev) => [saved, ...prev]);
    } catch (e: any) {
      setFormError(e.message ?? "Could not add the event. Please try again.");
    } finally {
      setSaving(false);
    }
  };

  const header = (
    <>
      <View style={styles.headRow}>
        <View style={{ flex: 1 }}>
          <Text style={styles.eyebrow}>YOUR ACADEMIC CALENDAR</Text>
          <Text style={styles.title}>Schedule</Text>
          <Text style={styles.subtitle}>
            Plan your classes, events, and study time.
          </Text>
        </View>
        <Pressable style={styles.addBtn} onPress={openModal} accessibilityLabel="Add event">
          <Text style={styles.addBtnText}>+ Add event</Text>
        </Pressable>
      </View>

      {isStudent ? (
        <Pressable
          style={styles.browseBtn}
          onPress={openBrowse}
          accessibilityLabel="Browse courses to enroll in"
        >
          <Text style={styles.browseBtnText}>Browse courses · Enroll</Text>
        </Pressable>
      ) : null}

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
    <>
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
              Add an event to start building your schedule.
            </Text>
            <Pressable style={styles.emptyBtn} onPress={openModal}>
              <Text style={styles.emptyBtnText}>Add an event</Text>
            </Pressable>
          </View>
        }
      />

      {/* Add-event modal */}
      <Modal
        visible={modalOpen}
        animationType="slide"
        transparent
        onRequestClose={() => setModalOpen(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalSheet}>
            <Text style={styles.modalTitle}>Add Event</Text>

            <Text style={styles.inputLabel}>Title</Text>
            <TextInput
              style={styles.input}
              value={form.title}
              onChangeText={(t) => setForm((f) => ({ ...f, title: t }))}
              placeholder="e.g. Physics revision"
              placeholderTextColor="#adb5bd"
            />

            <Text style={styles.inputLabel}>Course (optional)</Text>
            <TextInput
              style={styles.input}
              value={form.course}
              onChangeText={(t) => setForm((f) => ({ ...f, course: t }))}
              placeholder="e.g. PHY101"
              placeholderTextColor="#adb5bd"
            />

            <Text style={styles.inputLabel}>Day</Text>
            <View style={styles.dayRow}>
              {DAYS.map((day) => {
                const active = form.day === day;
                return (
                  <Pressable
                    key={day}
                    style={[styles.dayChip, active && styles.dayChipActive]}
                    onPress={() => setForm((f) => ({ ...f, day }))}
                  >
                    <Text
                      style={[styles.dayChipText, active && styles.dayChipTextActive]}
                    >
                      {dayShorthand[day]}
                    </Text>
                  </Pressable>
                );
              })}
            </View>

            <View style={styles.timeRow}>
              <View style={styles.timeField}>
                <Text style={styles.inputLabel}>Start (24h)</Text>
                <TextInput
                  style={styles.input}
                  value={form.start}
                  onChangeText={(t) => setForm((f) => ({ ...f, start: t }))}
                  placeholder="09:00"
                  placeholderTextColor="#adb5bd"
                  keyboardType="numbers-and-punctuation"
                  maxLength={5}
                />
              </View>
              <View style={styles.timeField}>
                <Text style={styles.inputLabel}>End (24h)</Text>
                <TextInput
                  style={styles.input}
                  value={form.end}
                  onChangeText={(t) => setForm((f) => ({ ...f, end: t }))}
                  placeholder="10:00"
                  placeholderTextColor="#adb5bd"
                  keyboardType="numbers-and-punctuation"
                  maxLength={5}
                />
              </View>
            </View>

            <Text style={styles.inputLabel}>Room / Location (optional)</Text>
            <TextInput
              style={styles.input}
              value={form.room}
              onChangeText={(t) => setForm((f) => ({ ...f, room: t }))}
              placeholder="e.g. Library, Room B12"
              placeholderTextColor="#adb5bd"
            />

            {formError ? (
              <View style={styles.formErrorWrap}>
                <Text style={styles.formError}>{formError}</Text>
              </View>
            ) : null}

            <View style={styles.modalActions}>
              <Pressable style={styles.modalCancel} onPress={() => setModalOpen(false)}>
                <Text style={styles.modalCancelText}>Cancel</Text>
              </Pressable>
              <Pressable
                style={[styles.modalSave, saving && styles.modalDisabled]}
                onPress={handleSave}
                disabled={saving}
              >
                {saving ? (
                  <ActivityIndicator size="small" color="#fff" />
                ) : (
                  <Text style={styles.modalSaveText}>Save Event</Text>
                )}
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>

      {/* Browse courses modal (student only) */}
      {isStudent ? (
        <Modal
          visible={browseOpen}
          animationType="slide"
          transparent
          onRequestClose={() => setBrowseOpen(false)}
        >
          <View style={styles.modalOverlay}>
            <View style={styles.modalSheet}>
              <View style={styles.browseHead}>
                <Text style={styles.modalTitle}>Browse courses</Text>
                <Pressable
                  style={styles.browseClose}
                  onPress={() => setBrowseOpen(false)}
                  accessibilityLabel="Close browse courses"
                >
                  <Text style={styles.browseCloseText}>Close</Text>
                </Pressable>
              </View>

              {browseLoading ? (
                <View style={styles.browseLoader}>
                  <ActivityIndicator size="large" color={palette.primary} />
                </View>
              ) : browseList.length === 0 ? (
                <View style={styles.browseEmpty}>
                  <Text style={styles.browseEmptyTitle}>No courses available</Text>
                  <Text style={styles.browseEmptyText}>
                    There are no other courses to enroll in right now.
                  </Text>
                </View>
              ) : (
                <FlatList
                  data={browseList}
                  keyExtractor={(item) => String(item.id)}
                  contentContainerStyle={styles.browseList}
                  renderItem={({ item }) => (
                    <BrowseCard
                      item={item}
                      busy={enrollingId === item.id}
                      onEnroll={() => handleEnroll(item.id)}
                    />
                  )}
                />
              )}
            </View>
          </View>
        </Modal>
      ) : null}
    </>
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
  headRow: {
    flexDirection: "row",
    alignItems: "flex-start",
    justifyContent: "space-between",
    marginBottom: 20,
  },
  eyebrow: {
    color: palette.muted,
    fontSize: 11,
    fontWeight: "700",
    letterSpacing: 1,
    marginBottom: 4,
  },
  title: { color: palette.ink, fontSize: 27, fontWeight: "800" },
  subtitle: { color: palette.muted, fontSize: 14, marginTop: 6 },
  addBtn: {
    backgroundColor: palette.primary,
    borderRadius: 11,
    paddingHorizontal: 14,
    paddingVertical: 10,
    marginTop: 6,
  },
  addBtnText: { color: "#fff", fontSize: 13, fontWeight: "800" },
  browseBtn: {
    alignSelf: "flex-start",
    backgroundColor: palette.greenSoft,
    borderColor: "#bcebd1",
    borderWidth: 1,
    borderRadius: 10,
    paddingHorizontal: 13,
    paddingVertical: 9,
    marginBottom: 16,
  },
  browseBtnText: { color: palette.green, fontSize: 13, fontWeight: "700" },
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
  emptyBtn: {
    backgroundColor: palette.primary,
    borderRadius: 9,
    marginTop: 18,
    paddingHorizontal: 16,
    paddingVertical: 11,
  },
  emptyBtnText: { color: "#fff", fontSize: 13, fontWeight: "800" },
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
  modalTitle: { fontSize: 19, fontWeight: "800", color: palette.ink },
  modalHint: { fontSize: 13, color: palette.muted, marginTop: 6, marginBottom: 8, lineHeight: 19 },
  inputLabel: { fontSize: 12, fontWeight: "700", color: palette.ink, marginTop: 14, marginBottom: 6 },
  input: {
    backgroundColor: "#f5f7fb",
    borderRadius: 10,
    borderWidth: 1,
    borderColor: palette.border,
    padding: 12,
    fontSize: 14,
    color: palette.ink,
  },
  dayRow: { flexDirection: "row", flexWrap: "wrap", gap: 7, marginTop: 4 },
  dayChip: {
    backgroundColor: "#f5f7fb",
    borderColor: palette.border,
    borderWidth: 1,
    borderRadius: 16,
    paddingHorizontal: 10,
    paddingVertical: 7,
  },
  dayChipActive: { backgroundColor: palette.primary, borderColor: palette.primary },
  dayChipText: { color: palette.muted, fontSize: 12, fontWeight: "700" },
  dayChipTextActive: { color: "#fff" },
  timeRow: { flexDirection: "row", gap: 12 },
  timeField: { flex: 1 },
  formErrorWrap: {
    backgroundColor: palette.accentSoft,
    borderRadius: 9,
    marginTop: 14,
    padding: 11,
  },
  formError: { color: palette.accent, fontSize: 12, fontWeight: "600" },
  modalActions: { flexDirection: "row", gap: 10, marginTop: 22 },
  modalCancel: {
    flex: 1,
    backgroundColor: "#f1f3f5",
    borderRadius: 10,
    paddingVertical: 13,
    alignItems: "center",
  },
  modalCancelText: { color: "#495057", fontWeight: "700" },
  modalSave: {
    flex: 1,
    backgroundColor: palette.primary,
    borderRadius: 10,
    paddingVertical: 13,
    alignItems: "center",
  },
  modalDisabled: { opacity: 0.6 },
  modalSaveText: { color: "#fff", fontWeight: "700" },
  // Browse modal styles
  browseHead: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 18,
  },
  browseClose: {
    backgroundColor: "#f1f3f5",
    borderRadius: 9,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  browseCloseText: { color: "#495057", fontSize: 13, fontWeight: "700" },
  browseLoader: {
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: 40,
  },
  browseEmpty: {
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: 40,
  },
  browseEmptyTitle: {
    color: palette.ink,
    fontSize: 16,
    fontWeight: "800",
  },
  browseEmptyText: {
    color: palette.muted,
    fontSize: 13,
    lineHeight: 19,
    marginTop: 8,
    textAlign: "center",
  },
  browseList: { paddingBottom: 12 },
  browseCard: {
    flexDirection: "row",
    alignItems: "flex-start",
    justifyContent: "space-between",
    backgroundColor: "#f8f9ff",
    borderColor: palette.border,
    borderRadius: 12,
    borderWidth: 1,
    marginBottom: 10,
    padding: 14,
  },
  browseCardBody: { flex: 1, paddingRight: 12 },
  browseCardTitle: { color: palette.ink, fontSize: 15, fontWeight: "700" },
  browseCardSub: { color: palette.muted, fontSize: 12, marginTop: 3 },
  browseCardMeta: { color: "#6c757d", fontSize: 11, marginTop: 6, lineHeight: 16 },
  enrollBtn: {
    backgroundColor: palette.primary,
    borderRadius: 9,
    paddingHorizontal: 14,
    paddingVertical: 9,
  },
  enrollBtnText: { color: "#fff", fontSize: 12, fontWeight: "800" },
});
