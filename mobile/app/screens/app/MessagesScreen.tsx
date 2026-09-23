/**
 * MessagesScreen — professional messaging redesign.
 * - Conversation list with unread badges and tidy metadata.
 * - Tap a conversation to open the full thread (bubbles, timestamps,
 *   read receipts) and reply inline.
 * - Compose new messages to any user via search.
 */

import React, { useCallback, useEffect, useRef, useState } from "react";
import {
  ActivityIndicator,
  Alert,
  FlatList,
  KeyboardAvoidingView,
  Modal,
  Platform,
  Pressable,
  RefreshControl,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import messageService, { SearchUser } from "@services/messages";
import { Conversation, Message } from "@app/types";
import { useAuth } from "@context/AuthContext";

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

function formatRelative(value: string): string {
  const date = new Date(value);
  const diff = Date.now() - date.getTime();
  const minutes = Math.floor(diff / 60000);
  if (minutes < 1) return "now";
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h`;
  return date.toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

function ConversationCard({
  item,
  onPress,
}: {
  item: Conversation;
  onPress: () => void;
}) {
  return (
    <Pressable style={styles.card} onPress={onPress}>
      <View style={styles.avatar}>
        <Text style={styles.avatarText}>{item.user.name.charAt(0).toUpperCase()}</Text>
        {item.unread_count > 0 ? <View style={styles.avatarDot} /> : null}
      </View>
      <View style={styles.cardBody}>
        <View style={styles.cardTop}>
          <Text style={styles.cardName} numberOfLines={1}>{item.user.name}</Text>
          {item.last_message_at ? (
            <Text style={styles.cardTime}>{formatRelative(item.last_message_at)}</Text>
          ) : null}
        </View>
        <View style={styles.cardBottom}>
          <Text style={styles.cardSnippet} numberOfLines={1}>
            {item.last_message ?? "No messages yet"}
          </Text>
          {item.unread_count > 0 ? (
            <View style={styles.unreadBadge}>
              <Text style={styles.unreadText}>
                {item.unread_count > 99 ? "99+" : item.unread_count}
              </Text>
            </View>
          ) : null}
        </View>
      </View>
    </Pressable>
  );
}

export default function MessagesScreen() {
  const { user } = useAuth();
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Thread state
  const [activeUser, setActiveUser] = useState<{
    id: number;
    name: string;
  } | null>(null);
  const [thread, setThread] = useState<Message[]>([]);
  const [threadLoading, setThreadLoading] = useState(false);
  const [reply, setReply] = useState("");
  const [sending, setSending] = useState(false);
  const threadListRef = useRef<FlatList<Message>>(null);

  // Compose modal state
  const [composeVisible, setComposeVisible] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<SearchUser[]>([]);
  const [searching, setSearching] = useState(false);
  const [selectedUser, setSelectedUser] = useState<SearchUser | null>(null);
  const [messageContent, setMessageContent] = useState("");

  const load = useCallback(async () => {
    try {
      setError(null);
      const data = await messageService.conversations();
      setConversations(data);
    } catch (e: any) {
      setError(e.message ?? "Could not load conversations");
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

  const openThread = useCallback(async (item: Conversation) => {
    setActiveUser({ id: item.user.id, name: item.user.name });
    setThreadLoading(true);
    setThread([]);
    try {
      const messages = await messageService.thread(item.user.id);
      setThread(messages);
    } catch (e: any) {
      Alert.alert("Could not load conversation", e.message || "Please try again.");
    } finally {
      setThreadLoading(false);
    }
  }, []);

  const sendReply = useCallback(async () => {
    if (!activeUser || !reply.trim() || sending) return;
    const content = reply.trim();
    setReply("");
    setSending(true);
    const optimistic: Message = {
      id: -Date.now(),
      sender_id: user?.id ?? -1,
      recipient_id: activeUser.id,
      content,
      read: false,
      sender_name: user ? `${user.first_name} ${user.last_name}` : undefined,
      created_at: new Date().toISOString(),
    };
    setThread((prev) => [...prev, optimistic]);
    try {
      const sent = await messageService.send(activeUser.id, content);
      setThread((prev) => prev.map((m) => (m.id === optimistic.id ? sent : m)));
      setConversations((prev) =>
        prev.map((c) =>
          c.user.id === activeUser.id
            ? { ...c, last_message: content, last_message_at: new Date().toISOString() }
            : c
        )
      );
    } catch (e: any) {
      setThread((prev) => prev.filter((m) => m.id !== optimistic.id));
      setReply(content);
      Alert.alert("Message failed to send", e.message || "Please try again.");
    } finally {
      setSending(false);
    }
  }, [activeUser, reply, sending, user]);

  useEffect(() => {
    if (threadListRef.current && thread.length > 0) {
      requestAnimationFrame(() =>
        threadListRef.current?.scrollToEnd({ animated: true })
      );
    }
  }, [thread, threadLoading]);

  const handleCompose = () => {
    setComposeVisible(true);
    setSearchQuery("");
    setSearchResults([]);
    setSelectedUser(null);
    setMessageContent("");
  };

  const handleSearch = useCallback(async (query: string) => {
    if (!query.trim()) {
      setSearchResults([]);
      return;
    }
    setSearching(true);
    try {
      const results = await messageService.searchUsers(query.trim());
      setSearchResults(results);
    } catch {
      setSearchResults([]);
    } finally {
      setSearching(false);
    }
  }, []);

  useEffect(() => {
    const timer = setTimeout(() => {
      if (searchQuery.trim()) {
        handleSearch(searchQuery);
      } else {
        setSearchResults([]);
      }
    }, 400);
    return () => clearTimeout(timer);
  }, [searchQuery, handleSearch]);

  const handleSend = async () => {
    if (!selectedUser || !messageContent.trim()) {
      Alert.alert("Validation", "Please select a recipient and write a message.");
      return;
    }
    setSending(true);
    try {
      await messageService.send(selectedUser.id, messageContent.trim());
      setComposeVisible(false);
      load();
    } catch (e: any) {
      Alert.alert("Error", e.message ?? "Message failed to send");
    } finally {
      setSending(false);
    }
  };

  // ── Thread header ──────────────────────────────────────────────
  const threadHeader = (
    <View style={styles.threadHeader}>
      <Pressable
        style={styles.backBtn}
        onPress={() => setActiveUser(null)}
        accessibilityLabel="Back to conversations"
      >
        <Text style={styles.backBtnText}>‹</Text>
      </Pressable>
      <View style={styles.threadAvatar}>
        <Text style={styles.threadAvatarText}>
          {activeUser?.name.charAt(0).toUpperCase() ?? "?"}
        </Text>
      </View>
      <View style={{ flex: 1 }}>
        <Text style={styles.threadName}>{activeUser?.name}</Text>
        <Text style={styles.threadStatus}>Conversation</Text>
      </View>
      <Pressable style={styles.headerCompose} onPress={handleCompose}>
        <Text style={styles.headerComposeText}>+</Text>
      </Pressable>
    </View>
  );

  const renderBubble = ({ item }: { item: Message }) => {
    const mine = item.sender_id === user?.id;
    return (
      <View style={[styles.bubbleRow, mine ? styles.bubbleRowMine : styles.bubbleRowTheirs]}>
        <View style={[styles.bubble, mine ? styles.bubbleMine : styles.bubbleTheirs]}>
          <Text style={mine ? styles.bubbleTextMine : styles.bubbleTextTheirs}>
            {item.content}
          </Text>
          <View style={styles.bubbleMeta}>
            <Text style={mine ? styles.bubbleTimeMine : styles.bubbleTimeTheirs}>
              {item.created_at
                ? new Date(item.created_at).toLocaleTimeString(undefined, {
                    hour: "2-digit",
                    minute: "2-digit",
                  })
                : ""}
            </Text>
            {mine ? (
              <Text style={styles.readReceipt}>{item.read ? "✓✓" : "✓"}</Text>
            ) : null}
          </View>
        </View>
      </View>
    );
  };

  // ── Thread view ────────────────────────────────────────────────
  if (activeUser) {
    return (
      <KeyboardAvoidingView
        style={styles.container}
        behavior={Platform.OS === "ios" ? "padding" : undefined}
        keyboardVerticalOffset={Platform.OS === "ios" ? 90 : 0}
      >
        {threadHeader}
        {threadLoading ? (
          <View style={styles.center}>
            <ActivityIndicator size="large" color={palette.primary} />
          </View>
        ) : (
          <FlatList
            ref={threadListRef}
            style={styles.threadList}
            contentContainerStyle={styles.threadContent}
            data={thread}
            keyExtractor={(item) => String(item.id)}
            renderItem={renderBubble}
            ListEmptyComponent={
              <View style={styles.emptyThread}>
                <Text style={styles.emptyThreadTitle}>Say hello 👋</Text>
                <Text style={styles.emptyThreadText}>
                  Start the conversation with {activeUser.name}.
                </Text>
              </View>
            }
            showsVerticalScrollIndicator={false}
          />
        )}
        <View style={styles.composerBar}>
          <TextInput
            style={styles.replyInput}
            value={reply}
            onChangeText={setReply}
            placeholder={`Message ${activeUser.name}...`}
            placeholderTextColor="#adb5bd"
            multiline
            editable={!sending}
          />
          <Pressable
            style={[styles.sendBtn, (!reply.trim() || sending) && styles.sendBtnDisabled]}
            onPress={sendReply}
            disabled={!reply.trim() || sending}
            accessibilityLabel="Send message"
          >
            {sending ? (
              <ActivityIndicator size="small" color="#fff" />
            ) : (
              <Text style={styles.sendBtnText}>↑</Text>
            )}
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    );
  }

  // ── Conversation list ──────────────────────────────────────────
  const header = (
    <View style={styles.headingRow}>
      <View style={{ flex: 1 }}>
        <Text style={styles.eyebrow}>STAY CONNECTED</Text>
        <Text style={styles.title}>Messages</Text>
        <Text style={styles.subtitle}>Your conversations in one place.</Text>
      </View>
      <Pressable style={styles.compose} onPress={handleCompose}>
        <Text style={styles.composeText}>+</Text>
      </Pressable>
    </View>
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
        data={conversations}
        keyExtractor={(item) => String(item.id)}
        ListHeaderComponent={header}
        renderItem={({ item }) => (
          <ConversationCard item={item} onPress={() => openThread(item)} />
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
              <Text style={styles.emptyIcon}>&#9993;</Text>
            </View>
            <Text style={styles.emptyTitle}>No conversations yet</Text>
            <Text style={styles.emptyText}>
              Message classmates, instructors, and your academic community.
            </Text>
            <Pressable style={styles.emptyBtn} onPress={handleCompose}>
              <Text style={styles.emptyBtnText}>Start a conversation</Text>
            </Pressable>
          </View>
        }
      />

      {/* Compose modal */}
      <Modal
        visible={composeVisible}
        animationType="slide"
        transparent
        onRequestClose={() => setComposeVisible(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalSheet}>
            <Text style={styles.modalTitle}>New Message</Text>

            {!selectedUser ? (
              <>
                <TextInput
                  style={styles.searchInput}
                  placeholder="Search users..."
                  placeholderTextColor="#adb5bd"
                  value={searchQuery}
                  onChangeText={setSearchQuery}
                  autoFocus
                />
                {searching ? (
                  <ActivityIndicator size="small" color={palette.primary} style={{ marginTop: 12 }} />
                ) : searchResults.length > 0 ? (
                  <View style={styles.searchResults}>
                    {searchResults.map((u) => (
                      <Pressable
                        key={u.id}
                        style={styles.searchRow}
                        onPress={() => { setSelectedUser(u); setSearchQuery(""); setSearchResults([]); }}
                      >
                        <View style={styles.searchAvatar}>
                          <Text style={styles.searchAvatarText}>{u.name.charAt(0).toUpperCase()}</Text>
                        </View>
                        <View style={{ flex: 1 }}>
                          <Text style={styles.searchName}>{u.name}</Text>
                          <Text style={styles.searchSub}>{u.email}</Text>
                        </View>
                      </Pressable>
                    ))}
                  </View>
                ) : null}
              </>
            ) : (
              <>
                <View style={styles.selectedUser}>
                  <Text style={styles.selectedUserLabel}>To:</Text>
                  <View style={styles.selectedUserChip}>
                    <Text style={styles.selectedUserName}>{selectedUser.name}</Text>
                    <Pressable onPress={() => setSelectedUser(null)}>
                      <Text style={styles.selectedUserClose}>✕</Text>
                    </Pressable>
                  </View>
                </View>

                <TextInput
                  style={[styles.searchInput, { minHeight: 120 }]}
                  placeholder="Write your message..."
                  placeholderTextColor="#adb5bd"
                  multiline
                  numberOfLines={5}
                  value={messageContent}
                  onChangeText={setMessageContent}
                  textAlignVertical="top"
                />

                <View style={styles.modalActions}>
                  <Pressable style={styles.modalCancel} onPress={() => setComposeVisible(false)}>
                    <Text style={styles.modalCancelText}>Cancel</Text>
                  </Pressable>
                  <Pressable
                    style={[styles.modalSend, sending && styles.modalSendDisabled]}
                    onPress={handleSend}
                    disabled={sending}
                  >
                    {sending ? (
                      <ActivityIndicator size="small" color="#fff" />
                    ) : (
                      <Text style={styles.modalSendText}>Send</Text>
                    )}
                  </Pressable>
                </View>
              </>
            )}
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
  headingRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 22,
  },
  eyebrow: { color: palette.muted, fontSize: 11, fontWeight: "700", letterSpacing: 1, marginBottom: 4 },
  title: { color: palette.ink, fontSize: 27, fontWeight: "800" },
  subtitle: { color: palette.muted, fontSize: 14, marginTop: 6 },
  compose: {
    alignItems: "center",
    backgroundColor: palette.primary,
    borderRadius: 15,
    height: 46,
    justifyContent: "center",
    width: 46,
  },
  composeText: { color: "#fff", fontSize: 27, fontWeight: "300" },
  card: {
    flexDirection: "row",
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 14,
    borderWidth: 1,
    marginBottom: 10,
    padding: 14,
  },
  avatar: {
    alignItems: "center",
    backgroundColor: palette.primary,
    borderRadius: 24,
    height: 48,
    justifyContent: "center",
    position: "relative",
    width: 48,
  },
  avatarText: { color: "#fff", fontSize: 18, fontWeight: "800" },
  avatarDot: {
    position: "absolute",
    right: 0,
    top: 0,
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: palette.accent,
    borderWidth: 2,
    borderColor: "#fff",
  },
  cardBody: { flex: 1, marginLeft: 12 },
  cardTop: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  cardName: { fontSize: 15, fontWeight: "700", color: palette.ink, flex: 1, marginRight: 8 },
  cardTime: { fontSize: 11, color: "#adb5bd" },
  cardBottom: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginTop: 3,
  },
  cardSnippet: { fontSize: 13, color: palette.muted, lineHeight: 18, flex: 1, marginRight: 8 },
  unreadBadge: {
    backgroundColor: palette.accent,
    borderRadius: 10,
    minWidth: 20,
    alignItems: "center",
    paddingHorizontal: 6,
    paddingVertical: 2,
  },
  unreadText: { color: "#fff", fontSize: 11, fontWeight: "800" },

  // Thread
  threadHeader: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: palette.surface,
    borderBottomColor: palette.border,
    borderBottomWidth: 1,
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  backBtn: {
    alignItems: "center",
    height: 40,
    justifyContent: "center",
    marginRight: 6,
    width: 40,
  },
  backBtnText: { color: palette.primary, fontSize: 34, lineHeight: 34, fontWeight: "700" },
  threadAvatar: {
    alignItems: "center",
    backgroundColor: palette.primary,
    borderRadius: 22,
    height: 44,
    justifyContent: "center",
    marginRight: 12,
    width: 44,
  },
  threadAvatarText: { color: "#fff", fontSize: 17, fontWeight: "800" },
  threadName: { color: palette.ink, fontSize: 16, fontWeight: "800" },
  threadStatus: { color: palette.muted, fontSize: 12, marginTop: 2 },
  headerCompose: {
    alignItems: "center",
    backgroundColor: palette.lavender,
    borderRadius: 12,
    height: 40,
    justifyContent: "center",
    width: 40,
  },
  headerComposeText: { color: palette.primary, fontSize: 22, fontWeight: "400" },
  threadList: { flex: 1 },
  threadContent: { padding: 16, paddingBottom: 16 },
  bubbleRow: { flexDirection: "row", marginBottom: 10 },
  bubbleRowMine: { justifyContent: "flex-end" },
  bubbleRowTheirs: { justifyContent: "flex-start" },
  bubble: { maxWidth: "78%", borderRadius: 16, paddingHorizontal: 14, paddingVertical: 9 },
  bubbleMine: {
    backgroundColor: palette.primary,
    borderBottomRightRadius: 4,
  },
  bubbleTheirs: {
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderWidth: 1,
    borderBottomLeftRadius: 4,
  },
  bubbleTextMine: { color: "#fff", fontSize: 14, lineHeight: 20 },
  bubbleTextTheirs: { color: palette.ink, fontSize: 14, lineHeight: 20 },
  bubbleMeta: { flexDirection: "row", alignItems: "center", justifyContent: "flex-end", marginTop: 4 },
  bubbleTimeMine: { color: "rgba(255,255,255,0.7)", fontSize: 10 },
  bubbleTimeTheirs: { color: palette.muted, fontSize: 10 },
  readReceipt: { color: "rgba(255,255,255,0.85)", fontSize: 11, marginLeft: 5, fontWeight: "700" },
  emptyThread: { alignItems: "center", paddingTop: 60 },
  emptyThreadTitle: { color: palette.ink, fontSize: 16, fontWeight: "800" },
  emptyThreadText: { color: palette.muted, fontSize: 13, marginTop: 6 },
  composerBar: {
    flexDirection: "row",
    alignItems: "flex-end",
    backgroundColor: palette.surface,
    borderTopColor: palette.border,
    borderTopWidth: 1,
    paddingHorizontal: 12,
    paddingVertical: 10,
    gap: 8,
  },
  replyInput: {
    flex: 1,
    backgroundColor: palette.background,
    borderColor: palette.border,
    borderRadius: 20,
    borderWidth: 1,
    color: palette.ink,
    fontSize: 14,
    maxHeight: 110,
    paddingHorizontal: 14,
    paddingVertical: 9,
  },
  sendBtn: {
    alignItems: "center",
    backgroundColor: palette.primary,
    borderRadius: 21,
    height: 42,
    justifyContent: "center",
    width: 42,
  },
  sendBtnDisabled: { opacity: 0.5 },
  sendBtnText: { color: "#fff", fontSize: 20, fontWeight: "900" },

  emptyCard: {
    alignItems: "center",
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 16,
    borderWidth: 1,
    padding: 28,
    marginTop: 8,
  },
  emptyIconWrap: { alignItems: "center", backgroundColor: palette.lavender, borderRadius: 15, height: 54, justifyContent: "center", width: 54 },
  emptyIcon: { color: palette.primary, fontSize: 24 },
  emptyTitle: { color: palette.ink, fontSize: 16, fontWeight: "800", marginTop: 14 },
  emptyText: { color: palette.muted, fontSize: 13, lineHeight: 19, marginTop: 6, textAlign: "center" },
  emptyBtn: { backgroundColor: palette.primary, borderRadius: 9, marginTop: 18, paddingHorizontal: 16, paddingVertical: 11 },
  emptyBtnText: { color: "#fff", fontSize: 13, fontWeight: "800" },
  errorText: { color: palette.accent, fontSize: 15, marginBottom: 12 },
  retryBtn: { backgroundColor: palette.primary, borderRadius: 8, paddingHorizontal: 20, paddingVertical: 10 },
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
  searchInput: {
    backgroundColor: "#f5f7fb",
    borderRadius: 10,
    borderWidth: 1,
    borderColor: palette.border,
    padding: 12,
    fontSize: 14,
    color: palette.ink,
    marginBottom: 12,
  },
  searchResults: { maxHeight: 300 },
  searchRow: {
    flexDirection: "row",
    alignItems: "center",
    padding: 10,
    backgroundColor: "#f8f9fa",
    borderRadius: 8,
    marginBottom: 6,
  },
  searchAvatar: {
    alignItems: "center",
    backgroundColor: palette.primary,
    borderRadius: 20,
    height: 40,
    justifyContent: "center",
    width: 40,
    marginRight: 10,
  },
  searchAvatarText: { color: "#fff", fontSize: 15, fontWeight: "800" },
  searchName: { fontSize: 14, fontWeight: "700", color: palette.ink },
  searchSub: { fontSize: 12, color: palette.muted, marginTop: 2 },
  selectedUser: { flexDirection: "row", alignItems: "center", marginBottom: 14 },
  selectedUserLabel: { fontSize: 14, fontWeight: "600", color: palette.muted, marginRight: 8 },
  selectedUserChip: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: palette.lavender,
    borderRadius: 20,
    paddingHorizontal: 12,
    paddingVertical: 5,
  },
  selectedUserName: { fontSize: 13, fontWeight: "600", color: palette.primary, marginRight: 6 },
  selectedUserClose: { fontSize: 13, color: palette.primary, fontWeight: "700" },
  modalActions: { flexDirection: "row", gap: 10, marginTop: 16 },
  modalCancel: {
    flex: 1,
    backgroundColor: "#f1f3f5",
    borderRadius: 10,
    paddingVertical: 13,
    alignItems: "center",
  },
  modalCancelText: { color: "#495057", fontWeight: "700" },
  modalSend: {
    flex: 1,
    backgroundColor: palette.primary,
    borderRadius: 10,
    paddingVertical: 13,
    alignItems: "center",
  },
  modalSendDisabled: { opacity: 0.6 },
  modalSendText: { color: "#fff", fontWeight: "700" },
});
