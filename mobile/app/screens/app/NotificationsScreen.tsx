/**
 * NotificationsScreen
 * Inbox for course/schedule/announcement/password-reset notifications.
 * Unread rows get a highlight + dot; tapping a row marks it read; a
 * header "mark all read" clears the whole inbox. Pull-to-refresh.
 *
 * Reached via the bell (HomeScreen) or Profile > Notifications; the screen
 * is pushed on the AppStack rather than rendered as a bottom tab.
 */

import React, { useCallback, useEffect, useState } from "react";
import { useFocusEffect } from "@react-navigation/native";
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  RefreshControl,
  StyleSheet,
  Text,
  View,
} from "react-native";
import notificationService from "@services/notifications";

const palette = {
  primary: "#3b5bfd",
  lavender: "#eef0ff",
  ink: "#172033",
  muted: "#667085",
  mutedLight: "#98a2b3",
  surface: "#ffffff",
  background: "#f5f7fb",
  border: "#e7eaf2",
  unreadBg: "#f3f5ff",
};

const typeGlyph: Record<string, string> = {
  schedule_created: "🗓",
  schedule_updated: "🗓",
  schedule_approved: "🗓",
  schedule_cancelled: "🗓",
  course_created: "📘",
  course_updated: "📘",
  course_deactivated: "📘",
  announcement_published: "📢",
  announcement_unpublished: "📢",
  note_shared: "📝",
  quiz_shared: "📝",
  grading_review: "📝",
  plagiarism_alert: "⚠️",
  password_reset: "🔑",
};

type InboxItem = {
  id: number;
  title: string;
  body?: string;
  read: boolean;
  type?: string;
  action_url?: string | null;
  created_at?: string;
};

export default function NotificationsScreen() {
  const [items, setItems] = useState<InboxItem[]>([]);
  const [unread, setUnread] = useState(0);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async (quiet = false) => {
    if (!quiet) setLoading(true);
    setError(null);
    try {
      const [list, count] = await Promise.all([
        notificationService.list(),
        notificationService.unreadCount(),
      ]);
      setItems(
        (list ?? []).map((n) => ({
          ...n,
          read: Boolean(n.read),
          type: n.notification_type ?? (n as any).type,
        }))
      );
      setUnread(count ?? 0);
    } catch (e: any) {
      setError(e?.message ?? "Could not load notifications.");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  useFocusEffect(
    useCallback(() => {
      notificationService
        .unreadCount()
        .then(setUnread)
        .catch(() => undefined);
    }, [])
  );

  const onRefresh = () => {
    setRefreshing(true);
    load(true);
  };

  const markRead = async (id: number) => {
    setItems((prev) => prev.map((it) => (it.id === id ? { ...it, read: true } : it)));
    setUnread((prev) => Math.max(0, prev - 1));
    notificationService.markAsRead(id).catch(() => undefined);
  };

  const markAllRead = async () => {
    if (unread === 0) return;
    setItems((prev) => prev.map((it) => ({ ...it, read: true })));
    setUnread(0);
    notificationService.markAllAsRead().catch(() => undefined);
  };

  const renderItem = ({ item }: { item: InboxItem }) => (
    <Pressable
      onPress={() => markRead(item.id)}
      style={[styles.row, !item.read && styles.rowUnread]}
      accessibilityLabel={`${item.title}, ${item.read ? "read" : "unread"}`}
    >
      <View style={styles.rowIconWrap}>
        <Text style={styles.rowIcon}>{typeGlyph[item.type ?? ""] ?? "🔔"}</Text>
      </View>
      <View style={styles.rowBody}>
        <Text style={styles.rowTitle}>{item.title}</Text>
        {item.body ? (
          <Text style={styles.rowBodyText} numberOfLines={2}>{item.body}</Text>
        ) : null}
        {item.created_at ? (
          <Text style={styles.rowDate}>
            {new Date(item.created_at).toLocaleDateString(undefined, { month: "short", day: "numeric" })}
          </Text>
        ) : null}
      </View>
      {!item.read ? <View style={styles.unreadDot} /> : null}
    </Pressable>
  );

  const empty = (
    <View style={styles.emptyCard}>
      <View style={styles.emptyIconWrap}><Text style={styles.emptyIcon}>🔔</Text></View>
      <Text style={styles.emptyTitle}>You&apos;re all caught up</Text>
      <Text style={styles.emptyText}>Values, deadlines and announcements will surface here.</Text>
    </View>
  );

  const header = (
    <View>
      <View style={styles.headerRow}>
        <View>
          <Text style={styles.eyebrow}>INBOX</Text>
          <Text style={styles.title}>Notifications</Text>
          <Text style={styles.subtitle}>Activity from your courses and the admin team.</Text>
        </View>
        <Pressable
          style={[styles.readAllBtn, unread === 0 && styles.readAllBtnDisabled]}
          onPress={markAllRead}
          disabled={unread === 0}
          accessibilityLabel="Mark all notifications as read"
        >
          <Text style={styles.readAllText}>Mark all read</Text>
        </Pressable>
      </View>
      {error ? (
        <View style={styles.banner}>
          <Text style={styles.bannerText}>{error}</Text>
        </View>
      ) : null}
    </View>
  );

  return (
    <View style={styles.container}>
      <FlatList
        data={items}
        keyExtractor={(item) => String(item.id)}
        renderItem={renderItem}
        ListHeaderComponent={header}
        ListEmptyComponent={
          loading ? (
            <ActivityIndicator size="large" color={palette.primary} style={{ marginTop: 40 }} />
          ) : (
            empty
          )
        }
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={onRefresh}
            colors={[palette.primary]}
            tintColor={palette.primary}
          />
        }
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: palette.background },
  content: { padding: 20, paddingBottom: 44 },
  headerRow: {
    alignItems: "flex-start",
    flexDirection: "row",
    justifyContent: "space-between",
    marginBottom: 18,
    marginTop: 8,
  },
  eyebrow: { color: palette.primary, fontSize: 11, fontWeight: "800", letterSpacing: 1.2 },
  title: { color: palette.ink, fontSize: 27, fontWeight: "800", marginTop: 4 },
  subtitle: { color: palette.muted, fontSize: 13, marginTop: 4 },
  readAllBtn: {
    alignItems: "center",
    backgroundColor: palette.lavender,
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 9,
    marginTop: 6,
  },
  readAllBtnDisabled: { opacity: 0.5 },
  readAllText: { color: palette.primary, fontSize: 12, fontWeight: "800" },
  banner: { backgroundColor: "#fee4e2", borderRadius: 9, marginBottom: 12, padding: 11 },
  bannerText: { color: "#b42318", fontSize: 12, fontWeight: "600" },
  row: {
    alignItems: "center",
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 14,
    borderWidth: 1,
    flexDirection: "row",
    marginBottom: 10,
    padding: 13,
  },
  rowUnread: { backgroundColor: palette.unreadBg, borderColor: "#dfe4ff" },
  rowIconWrap: {
    alignItems: "center",
    backgroundColor: palette.lavender,
    borderRadius: 11,
    height: 42,
    justifyContent: "center",
    marginRight: 13,
    width: 42,
  },
  rowIcon: { fontSize: 19 },
  rowBody: { flex: 1 },
  rowTitle: { color: palette.ink, fontSize: 14, fontWeight: "800" },
  rowBodyText: { color: palette.muted, fontSize: 12, lineHeight: 18, marginTop: 3 },
  rowDate: { color: palette.mutedLight, fontSize: 11, marginTop: 6 },
  unreadDot: {
    backgroundColor: palette.primary,
    borderRadius: 4,
    height: 8,
    marginLeft: 10,
    width: 8,
  },
  emptyCard: {
    alignItems: "center",
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 15,
    borderWidth: 1,
    padding: 28,
  },
  emptyIconWrap: { alignItems: "center", backgroundColor: palette.lavender, borderRadius: 26, height: 52, justifyContent: "center", width: 52 },
  emptyIcon: { fontSize: 24 },
  emptyTitle: { color: palette.ink, fontSize: 15, fontWeight: "800", marginTop: 14 },
  emptyText: { color: palette.muted, fontSize: 13, lineHeight: 19, marginTop: 7, textAlign: "center" },
});
