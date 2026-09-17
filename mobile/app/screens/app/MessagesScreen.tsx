/**
 * MessagesScreen — live, wired to MessageService.
 * Lists all conversations, pulls latest messages, supports compose (user search).
 * Pull-to-refresh, loading, and empty states handled.
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
import messageService, { SearchUser } from "@services/messages";
import { Conversation } from "@app/types";

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

function ConversationCard({ item }: { item: Conversation }) {
  const formattedTime = item.last_message_at
    ? new Date(item.last_message_at).toLocaleDateString(undefined, {
        month: "short",
        day: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      })
    : "";

  return (
    <View style={styles.card}>
      <View style={styles.avatar}>
        <Text style={styles.avatarText}>{item.user.name.charAt(0).toUpperCase()}</Text>
      </View>
      <View style={styles.cardBody}>
        <Text style={styles.cardName}>{item.user.name}</Text>
        <Text style={styles.cardSnippet} numberOfLines={2}>
          {item.last_message ?? "No messages yet"}
        </Text>
      </View>
      <View style={styles.cardMeta}>
        <Text style={styles.cardTime}>{formattedTime}</Text>
        {item.unread_count > 0 ? (
          <View style={styles.unreadBadge}>
            <Text style={styles.unreadText}>{item.unread_count}</Text>
          </View>
        ) : null}
      </View>
    </View>
  );
}

export default function MessagesScreen() {
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Compose modal state
  const [composeVisible, setComposeVisible] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<SearchUser[]>([]);
  const [searching, setSearching] = useState(false);
  const [selectedUser, setSelectedUser] = useState<SearchUser | null>(null);
  const [messageContent, setMessageContent] = useState("");
  const [sending, setSending] = useState(false);

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
        renderItem={({ item }) => <ConversationCard item={item} />}
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
                        <View>
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
    width: 48,
  },
  avatarText: { color: "#fff", fontSize: 18, fontWeight: "800" },
  cardBody: { flex: 1, marginLeft: 12 },
  cardName: { fontSize: 15, fontWeight: "700", color: palette.ink },
  cardSnippet: { fontSize: 13, color: palette.muted, marginTop: 3, lineHeight: 18 },
  cardMeta: { alignItems: "flex-end", marginLeft: 8 },
  cardTime: { fontSize: 11, color: "#adb5bd" },
  unreadBadge: {
    backgroundColor: palette.accent,
    borderRadius: 10,
    paddingHorizontal: 7,
    paddingVertical: 2,
    marginTop: 6,
  },
  unreadText: { color: "#fff", fontSize: 11, fontWeight: "800" },
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
