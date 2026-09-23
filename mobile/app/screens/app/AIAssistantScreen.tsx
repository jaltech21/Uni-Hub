/**
 * AIAssistantScreen — conversational UniHub AI chat + study tools.
 * - Chat tab: persistent conversation via ai.ts (history/send/clear),
 *   quick-prompt chips, retry on first hot-reload failure.
 * - Tools tab: learning pulse, document summarization, hints, questions.
 */

import React, { useCallback, useEffect, useRef, useState } from "react";
import * as DocumentPicker from "expo-document-picker";
import {
  ActivityIndicator,
  Alert,
  FlatList,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import apiClient from "@services/api";
import { useAuth } from "@context/AuthContext";
import aiService, { AiMessage, AiProgress, TutorReportEntry } from "@services/ai";

const colors = {
  ink: "#172033",
  muted: "#667085",
  mutedLight: "#98a2b3",
  primary: "#3b5bfd",
  primarySoft: "#eef0ff",
  background: "#f5f7fb",
  surface: "#fff",
  border: "#e7eaf2",
  green: "#0e9f6e",
  greenSoft: "#e8f8f1",
  orange: "#d97706",
  orangeSoft: "#fff5e6",
  red: "#dc4c4c",
};

const isRateLimited = (error: any) =>
  error?.apiError?.status === 429 || error?.apiError?.code === "RATE_LIMITED";

const countWords = (value: string) =>
  value.trim() ? value.trim().split(/\s+/).length : 0;

type SummaryResult = {
  summary?: string;
  source_length?: number;
  source_word_count?: number;
  hints?: string[];
  questions?: unknown[];
};

type ToolMode = "summarize" | "hints" | "questions";

const PROMPT_CHIPS: Array<{ label: string; prompt: string }> = [
  {
    label: "Study plan",
    prompt:
      "Create a concrete study plan for my current courses. Use my schedules, upcoming assignments, and notes from the application context. Organize it by day and include session durations, topics, revision, breaks, and clear priorities.",
  },
  {
    label: "Explain a topic",
    prompt:
      "Explain a difficult topic step by step in simple academic language. Include one worked example, three key points, and one short question to check understanding.",
  },
  {
    label: "Check my progress",
    prompt:
      "Review my learning pulse and tell me what to prioritise this week based on the metrics you have.",
  },
  {
    label: "Summarize my notes",
    prompt:
      "Summarize my recent notes concisely and highlight the key ideas I should remember.",
  },
];

export default function AIAssistantScreen() {
  const { user, isTeacher } = useAuth();
  const [tab, setTab] = useState<"chat" | "tools">(
    isTeacher ? "tools" : "chat"
  );

  // Chat state
  const [messages, setMessages] = useState<AiMessage[]>([]);
  const [chatInput, setChatInput] = useState("");
  const [chatLoading, setChatLoading] = useState(false);
  const [chatInit, setChatInit] = useState(false);
  const listRef = useRef<FlatList<AiMessage>>(null);

  // Teacher-only tutor report
  const [tutorReport, setTutorReport] = useState<TutorReportEntry[] | null>(null);

  // Tools state
  const [progress, setProgress] = useState<AiProgress | null>(null);
  const [question, setQuestion] = useState("");
  const [summary, setSummary] = useState("");
  const [sourceWordCount, setSourceWordCount] = useState(0);
  const [sourceName, setSourceName] = useState("");
  const [selectedFile, setSelectedFile] =
    useState<DocumentPicker.DocumentPickerAsset | null>(null);
  const [toolMode, setToolMode] = useState<ToolMode>("summarize");
  const [toolLoading, setToolLoading] = useState(false);

  const loadHistory = useCallback(async () => {
    try {
      const history = await aiService.history();
      setMessages(history);
    } catch {
      // Server code reload can drop the first request; chat send retries once.
    } finally {
      setChatInit(true);
    }
  }, []);

  useEffect(() => {
    if (isTeacher) {
      setChatInit(true);
      aiService
        .tutorReport()
        .then(setTutorReport)
        .catch(() => undefined);
    } else {
      loadHistory();
    }
    aiService
      .progress()
      .then(setProgress)
      .catch(() => undefined);
  }, [isTeacher, loadHistory]);

  const scrollToEnd = useCallback(() => {
    requestAnimationFrame(() => listRef.current?.scrollToEnd({ animated: true }));
  }, []);

  const sendChat = useCallback(
    async (text: string) => {
      const content = text.trim();
      if (!content || chatLoading) return;
      setChatInput("");
      setChatLoading(true);
      const previous = messages;
      setMessages((prev) => [
        ...prev,
        { id: -Date.now(), role: "user", content, status: "pending" },
      ]);
      scrollToEnd();
try {
        const result = await aiService.send(content);
        setMessages(result.messages);
      } catch (e: any) {
        setMessages(previous);
        Alert.alert(
          isRateLimited(e) ? "UniHub AI is busy" : "AI request failed",
          isRateLimited(e)
            ? "Too many AI requests right now. Please wait a moment and try again."
            : e.message || "Please try again in a moment."
        );
      } finally {
        setChatLoading(false);
        scrollToEnd();
      }
    },
    [chatLoading, messages, scrollToEnd]
  );

  const clearChat = useCallback(() => {
    Alert.alert("Clear conversation", "This removes the AI chat history for your account.", [
      { text: "Cancel", style: "cancel" },
      {
        text: "Clear",
        style: "destructive",
        onPress: async () => {
          try {
            await aiService.clear();
            setMessages([]);
          } catch {
            Alert.alert("Could not clear", "Please try again.");
          }
        },
      },
    ]);
  }, []);

  const runSummary = useCallback(
    async (text = question, file = selectedFile) => {
      if (!text.trim() && !file) {
        Alert.alert(
          "Add study material",
          "Paste at least 100 characters or upload a PDF."
        );
        return;
      }
      setToolLoading(true);
      setSummary("");
      setSourceWordCount(0);
      try {
        let result: SummaryResult;
        if (file) {
          const formData = new FormData();
          const fileName = file.name || "study-material.pdf";

          if (Platform.OS === "web") {
            const browserFile = (
              file as DocumentPicker.DocumentPickerAsset & {
                file?: File | Blob;
              }
            ).file;
            if (browserFile instanceof File && browserFile.size > 0) {
              formData.append("file", browserFile, fileName);
            } else {
              const fileResponse = await fetch(file.uri);
              if (!fileResponse.ok)
                throw new Error("The selected PDF could not be opened.");
              const blob = await fileResponse.blob();
              if (!blob.size || blob.size === 0)
                throw new Error(
                  "The selected PDF is empty or unavailable."
                );
              const pdfFile = new File([blob], fileName, {
                type: blob.type || "application/pdf",
              });
              formData.append("file", pdfFile);
            }
          } else {
            formData.append("file", {
              uri: file.uri,
              name: fileName,
              type: "application/pdf",
            } as any);
          }

          formData.append("length", "medium");
          formData.append("mode", toolMode);
          if (text.trim()) formData.append("text", text);

          result = await apiClient.post<SummaryResult>("/ai/summarize", formData, {
            headers: { "Content-Type": "multipart/form-data" },
          });
        } else {
          if (text.trim().length < 100) {
            throw new Error(
              "Add at least 100 characters of study material."
            );
          }
          result = await apiClient.post<SummaryResult>("/ai/summarize", {
            text,
            length: "medium",
            mode: toolMode,
          });
        }
        const responseText =
          result.summary ||
          (result.hints || []).join("\n\n") ||
          "No answer was returned. Please try again.";
        setSummary(responseText);
        setSourceWordCount(result.source_word_count ?? countWords(text));
      } catch (error: any) {
        Alert.alert(
          "UniHub AI is busy",
          isRateLimited(error)
            ? "Too many AI requests right now. Please wait a moment and try again."
            : error.message || "Please try again."
        );
      } finally {
        setToolLoading(false);
      }
    },
    [question, selectedFile, toolMode]
  );

  const choosePdf = useCallback(async () => {
    const result = await DocumentPicker.getDocumentAsync({
      type: "application/pdf",
      copyToCacheDirectory: true,
    });
    if (result.canceled) return;
    const file = result.assets[0];
    setSelectedFile(file);
    setSourceName(file.name || "PDF study material");
  }, []);

  const summarizeNotes = useCallback(async () => {
    if (toolLoading) return;
    setToolLoading(true);
    setSummary("");
    try {
      const notes = await apiClient.get<Array<{ title?: string; content?: string }>>(
        "/notes"
      );
      const noteText = notes
        .map((note) => `${note.title || "Note"}\n${note.content || ""}`)
        .join("\n\n");
      setQuestion(noteText);
      if (noteText.trim().length >= 100) {
        const result = await apiClient.post<SummaryResult>("/ai/summarize", {
          text: noteText,
          length: "medium",
          mode: "summarize",
        });
        setSummary(
          result.summary || "No answer was returned. Please try again."
        );
        setSourceWordCount(result.source_word_count ?? countWords(noteText));
      } else {
        setSummary(
          "Your notes are too short to summarise — add a little more content and try again."
        );
      }
    } catch (e: any) {
      Alert.alert("Could not load notes", e.message || "Please try again.");
    } finally {
      setToolLoading(false);
    }
  }, [toolLoading]);

  // ── Chat renderer ────────────────────────────────────────────────
  const renderBubble = ({ item }: { item: AiMessage }) => {
    const isUser = item.role === "user";
    return (
      <View
        style={[
          styles.bubbleRow,
          isUser ? styles.bubbleRowUser : styles.bubbleRowAi,
        ]}
      >
        {!isUser ? (
          <View style={styles.aiBadge}>
            <Text style={styles.aiBadgeText}>U</Text>
          </View>
        ) : null}
        <View
          style={[
            styles.bubble,
            isUser ? styles.bubbleUser : styles.bubbleAi,
          ]}
        >
          <Text style={isUser ? styles.bubbleTextUser : styles.bubbleTextAi}>
            {item.content}
          </Text>
          <Text style={isUser ? styles.bubbleTimeUser : styles.bubbleTimeAi}>
            {item.created_at
              ? new Date(item.created_at).toLocaleTimeString(undefined, {
                  hour: "2-digit",
                  minute: "2-digit",
                })
              : ""}
          </Text>
        </View>
      </View>
    );
  };

  const chatEmpty = (
    <View style={styles.chatIntro}>
      <View style={styles.chatIntroIcon}>
        <Text style={styles.chatIntroIconText}>✦</Text>
      </View>
      <Text style={styles.chatIntroTitle}>Ask UniHub AI anything</Text>
      <Text style={styles.chatIntroText}>
        Study plans, tricky topics, progress checks, or summarising your notes —
        all grounded in your UniHub context.
      </Text>
      <View style={styles.chipWrap}>
        {PROMPT_CHIPS.map((chip) => (
          <Pressable
            key={chip.label}
            style={styles.chip}
            onPress={() => sendChat(chip.prompt)}
            disabled={chatLoading}
          >
            <Text style={styles.chipText}>{chip.label}</Text>
          </Pressable>
        ))}
      </View>
    </View>
  );

  // ── Tools renderer ───────────────────────────────────────────────
  const toolsView = (
    <View>
      {progress ? (
        <Allchunk
          progress={progress}
        />
      ) : null}

      {isTeacher && tutorReport ? <TutorReportView report={tutorReport} /> : null}

      <Text style={styles.sectionTitle}>What can I help with?</Text>
      <View style={styles.suggestions}>
        {[
          { label: "Summarize text", mode: "summarize" as ToolMode },
          { label: "Study hints", mode: "hints" as ToolMode },
          { label: "Exam questions", mode: "questions" as ToolMode },
        ].map((item) => (
          <Pressable
            key={item.mode}
            style={[
              styles.suggestion,
              toolMode === item.mode && styles.suggestionActive,
            ]}
            onPress={() => setToolMode(item.mode)}
          >
            <Text
              style={[
                styles.suggestionText,
                toolMode === item.mode && styles.suggestionTextActive,
              ]}
            >
              {item.label}
            </Text>
          </Pressable>
        ))}
      </View>

      <View style={styles.composer}>
        <TextInput
          multiline
          value={question}
          onChangeText={setQuestion}
          placeholder="Paste notes or study material..."
          placeholderTextColor="#98a2b3"
          style={styles.input}
          editable={!toolLoading}
        />
        <View style={styles.composerActions}>
          <Pressable
            style={styles.uploadButton}
            onPress={choosePdf}
            disabled={toolLoading}
          >
            <Text style={styles.uploadText}>Upload PDF</Text>
          </Pressable>
          <Pressable
            style={[
              styles.askButton,
              (!question.trim() && !selectedFile) && styles.askButtonDisabled,
            ]}
            disabled={(!question.trim() && !selectedFile) || toolLoading}
            onPress={() => runSummary()}
          >
            <Text style={styles.askButtonText}>
              {toolLoading ? "Working..." : "Run"}
            </Text>
          </Pressable>
        </View>
      </View>
      {selectedFile ? (
        <Pressable onPress={choosePdf}>
          <Text style={styles.fileName}>Selected: {sourceName} (tap to change)</Text>
        </Pressable>
      ) : null}

      <View style={styles.toolShortcuts}>
        <Pressable
          style={styles.toolShortcut}
          onPress={summarizeNotes}
          disabled={toolLoading}
        >
          <Text style={styles.toolShortcutText}>Summarize my notes</Text>
        </Pressable>
        <Pressable
          style={styles.toolShortcut}
          onPress={() => setQuestion("Create a concrete study plan for my current courses...")}
          disabled={toolLoading}
        >
          <Text style={styles.toolShortcutText}>Study plan template</Text>
        </Pressable>
      </View>

      {toolLoading ? (
        <ActivityIndicator color={colors.primary} style={styles.loader} />
      ) : null}
      {summary ? (
        <View style={styles.response}>
          <View style={styles.responseHeader}>
            <View style={styles.responseIcon}>
              <Text style={styles.responseIconText}>
                {toolMode === "questions" ? "Q" : toolMode === "hints" ? "H" : "S"}
              </Text>
            </View>
            <View>
              <Text style={styles.responseLabel}>
                {toolMode === "questions"
                  ? "EXAM QUESTIONS"
                  : toolMode === "hints"
                  ? "STUDY HINTS"
                  : "SUMMARY"}
              </Text>
              <Text style={styles.responseSubheading}>
                {summary
                  ? `${sourceWordCount.toLocaleString()} source words · ${countWords(
                      summary
                    ).toLocaleString()} result words`
                  : "Result"}
              </Text>
            </View>
          </View>
          <Text style={styles.responseText}>{summary}</Text>
        </View>
      ) : null}
    </View>
  );

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === "ios" ? "padding" : undefined}
      keyboardVerticalOffset={Platform.OS === "ios" ? 90 : 0}
    >
      {/* Header */}
      <View style={styles.header}>
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>U</Text>
        </View>
        <View style={styles.headerInfo}>
          <Text style={styles.title}>UniHub AI</Text>
          <Text style={styles.subtitle}>
            {user?.first_name ? `Hi ${user.first_name}, ask away` : "Your study assistant"}
          </Text>
        </View>
        {isTeacher ? (
          <View style={styles.roledot} />
        ) : null}
        {!isTeacher ? (
          <Pressable
            style={styles.clearBtn}
            onPress={clearChat}
            accessibilityLabel="Clear conversation"
          >
            <Text style={styles.clearBtnText}>🗑</Text>
          </Pressable>
        ) : null}
      </View>

      {/* Tabs */}
      <View style={styles.tabs}>
        {(isTeacher ? (["tools"] as const) : (["chat", "tools"] as const)).map((t) => (
          <Pressable
            key={t}
            style={[styles.tab, tab === t && styles.tabActive]}
            onPress={() => setTab(t)}
          >
            <Text
              style={[styles.tabText, tab === t && styles.tabTextActive]}
            >
              {t === "chat" ? "Chat" : "Study tools"}
            </Text>
          </Pressable>
        ))}
      </View>

      {tab === "chat" ? (
        <>
          <FlatList
            ref={listRef}
            data={messages}
            keyExtractor={(item, index) =>
              item.id ? String(item.id) : `${item.role}-${index}`
            }
            renderItem={renderBubble}
            contentContainerStyle={styles.chatList}
            ListEmptyComponent={
              chatInit ? (
                chatEmpty
              ) : (
                <ActivityIndicator color={colors.primary} style={styles.chatLoader} />
              )
            }
            onContentSizeChange={scrollToEnd}
            showsVerticalScrollIndicator={false}
          />
          <View style={styles.composerBar}>
            <TextInput
              value={chatInput}
              onChangeText={setChatInput}
              placeholder="Ask UniHub AI..."
              placeholderTextColor="#98a2b3"
              style={styles.chatInput}
              multiline
              editable={!chatLoading}
              onSubmitEditing={() => sendChat(chatInput)}
            />
            <Pressable
              style={[
                styles.chatSend,
                (!chatInput.trim() || chatLoading) && styles.askButtonDisabled,
              ]}
              onPress={() => sendChat(chatInput)}
              disabled={!chatInput.trim() || chatLoading}
              accessibilityLabel="Send message"
            >
              {chatLoading ? (
                <ActivityIndicator size="small" color="#fff" />
              ) : (
                <Text style={styles.chatSendText}>↑</Text>
              )}
            </Pressable>
          </View>
        </>
      ) : (
        <FlatList
          data={[]}
          renderItem={() => null}
          ListHeaderComponent={toolsView}
          contentContainerStyle={styles.toolsList}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        />
      )}
    </KeyboardAvoidingView>
  );
}

function Allchunk({ progress }: { progress: AiProgress }) {
  const styles = useAllchunkStyles();
  return (
    <View
      style={[
        styles.card,
        progress.status === "critical"
          ? styles.critical
          : progress.status === "warning"
          ? styles.warning
          : styles.onTrack,
      ]}
    >
      <View style={styles.top}>
        <View>
          <Text style={styles.eyebrow}>YOUR LEARNING PULSE</Text>
          <Text style={styles.title}>{progress.label}</Text>
        </View>
        <Text style={styles.score}>{progress.score}</Text>
      </View>
      <View style={styles.bar}>
        <View
          style={[
            styles.fill,
            progress.status === "critical"
              ? styles.fillCritical
              : progress.status === "warning"
              ? styles.fillWarning
              : styles.fillOnTrack,
            { width: `${Math.max(4, Math.min(100, progress.score))}%` },
          ]}
        />
      </View>
      <Text style={styles.hint}>
        {progress.metrics.overdue_assignments > 0
          ? `${progress.metrics.overdue_assignments} overdue assignment${
              progress.metrics.overdue_assignments === 1 ? "" : "s"
            } need attention.`
          : "Your current activity is building positive momentum."}
      </Text>
      <View style={styles.metrics}>
        <Text style={styles.metric}>
          {progress.metrics.upcoming_assignments} due soon
        </Text>
        <Text style={styles.metric}>
          {progress.metrics.pending_submissions} pending
        </Text>
        <Text style={styles.metric}>
          {progress.metrics.recent_notes} notes
        </Text>
      </View>
    </View>
  );
}

function useAllchunkStyles() {
  return StyleSheet.create({
    card: { borderRadius: 16, padding: 16, marginBottom: 24, borderWidth: 1 },
    critical: { backgroundColor: "#fff1f1", borderColor: "#ffcaca" },
    warning: { backgroundColor: "#fff8ea", borderColor: "#f6d48b" },
    onTrack: { backgroundColor: "#effbf5", borderColor: "#bcebd1" },
    top: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
    eyebrow: { color: colors.muted, fontSize: 10, fontWeight: "800", letterSpacing: 1 },
    title: { color: colors.ink, fontSize: 16, fontWeight: "800", marginTop: 4 },
    score: { color: colors.primary, fontSize: 26, fontWeight: "900" },
    bar: {
      backgroundColor: "rgba(23,32,51,0.10)",
      borderRadius: 5,
      height: 7,
      marginTop: 13,
      overflow: "hidden",
    },
    fill: { backgroundColor: colors.primary, borderRadius: 5, height: 7 },
    fillCritical: { backgroundColor: "#dc4c4c" },
    fillWarning: { backgroundColor: "#e8a11a" },
    fillOnTrack: { backgroundColor: "#18a66a" },
    hint: { color: colors.muted, fontSize: 12, lineHeight: 18, marginTop: 10 },
    metrics: { flexDirection: "row", flexWrap: "wrap", gap: 8, marginTop: 12 },
    metric: { color: colors.ink, fontSize: 11, fontWeight: "700" },
  });
}

function TutorReportView({ report }: { report: TutorReportEntry[] }) {
  if (!report.length) {
    return (
      <View style={styles.tutorEmpty}>
        <Text style={styles.tutorEmptyText}>
          No taught schedules yet — your tutor report will appear here once
          students are enrolled in your courses.
        </Text>
      </View>
    );
  }
  return (
    <View style={styles.tutorWrap}>
      <Text style={styles.sectionTitle}>Tutor report</Text>
      {report.map((entry) => (
        <View key={entry.schedule_id} style={styles.tutorCard}>
          <Text style={styles.tutorCardTitle}>
            {entry.course_code ? `${entry.course_code} · ` : ""}
            {entry.schedule_title || entry.schedule_title_raw || "Course"}
          </Text>
          {entry.students.length === 0 ? (
            <Text style={styles.tutorCardMuted}>No students enrolled yet.</Text>
          ) : (
            entry.students.map((student) => (
              <View key={student.student_id} style={styles.tutorRow}>
                <View style={styles.tutorRowMain}>
                  <Text style={styles.tutorStudent}>{student.student_name}</Text>
                  <Text style={styles.tutorMeta}>
                    {student.submitted_count}/{student.assignments_count} submitted ·{" "}
                    {student.graded_count} graded
                    {student.average_grade != null
                      ? ` · avg ${student.average_grade}%`
                      : ""}
                  </Text>
                </View>
                <View style={styles.tutorScoreWrap}>
                  <Text style={styles.tutorScore}>{student.progress_score}%</Text>
                  <View style={styles.tutorBar}>
                    <View
                      style={[
                        styles.tutorBarFill,
                        {
                          width: `${Math.max(4, Math.min(100, student.progress_score))}%`,
                        },
                      ]}
                    />
                  </View>
                </View>
              </View>
            ))
          )}
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  header: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 20,
    paddingTop: 14,
    paddingBottom: 10,
  },
  avatar: {
    width: 44,
    height: 44,
    borderRadius: 14,
    backgroundColor: "#172033",
    alignItems: "center",
    justifyContent: "center",
    marginRight: 11,
  },
  avatarText: { color: "#fff", fontSize: 18, fontWeight: "900" },
  headerInfo: { flex: 1 },
  title: { color: colors.ink, fontSize: 19, fontWeight: "800" },
  subtitle: { color: colors.muted, fontSize: 12, marginTop: 2 },
  clearBtn: {
    width: 38,
    height: 38,
    borderRadius: 11,
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderWidth: 1,
    alignItems: "center",
    justifyContent: "center",
  },
  clearBtnText: { fontSize: 16 },
  roledot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: colors.green,
    marginRight: 10,
  },
  tabs: {
    flexDirection: "row",
    marginHorizontal: 20,
    backgroundColor: colors.surface,
    borderRadius: 11,
    padding: 4,
    borderColor: colors.border,
    borderWidth: 1,
    marginBottom: 10,
  },
  tab: { flex: 1, alignItems: "center", paddingVertical: 9, borderRadius: 8 },
  tabActive: { backgroundColor: colors.primarySoft },
  tabText: { color: colors.muted, fontSize: 13, fontWeight: "700" },
  tabTextActive: { color: colors.primary },

  // Chat
  chatList: { paddingHorizontal: 20, paddingBottom: 12 },
  chatLoader: { marginTop: 40 },
  chatIntro: { alignItems: "center", paddingTop: 28 },
  chatIntroIcon: {
    width: 54,
    height: 54,
    borderRadius: 18,
    backgroundColor: colors.primarySoft,
    alignItems: "center",
    justifyContent: "center",
    marginBottom: 14,
  },
  chatIntroIconText: { color: colors.primary, fontSize: 24, fontWeight: "800" },
  chatIntroTitle: { color: colors.ink, fontSize: 17, fontWeight: "800" },
  chatIntroText: {
    color: colors.muted,
    fontSize: 13,
    lineHeight: 20,
    textAlign: "center",
    marginTop: 8,
    maxWidth: 300,
  },
  chipWrap: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 9,
    justifyContent: "center",
    marginTop: 18,
  },
  chip: {
    backgroundColor: colors.surface,
    borderColor: colors.primary,
    borderWidth: 1,
    borderRadius: 20,
    paddingHorizontal: 14,
    paddingVertical: 8,
  },
  chipText: { color: colors.primary, fontSize: 13, fontWeight: "700" },

  bubbleRow: { flexDirection: "row", marginBottom: 12, alignItems: "flex-end" },
  bubbleRowUser: { justifyContent: "flex-end" },
  bubbleRowAi: { justifyContent: "flex-start" },
  aiBadge: {
    width: 30,
    height: 30,
    borderRadius: 10,
    backgroundColor: "#172033",
    alignItems: "center",
    justifyContent: "center",
    marginRight: 8,
  },
  aiBadgeText: { color: "#fff", fontSize: 12, fontWeight: "900" },
  bubble: { maxWidth: "78%", borderRadius: 16, paddingHorizontal: 14, paddingVertical: 10 },
  bubbleUser: {
    backgroundColor: colors.primary,
    borderBottomRightRadius: 4,
  },
  bubbleAi: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderWidth: 1,
    borderBottomLeftRadius: 4,
  },
  bubbleTextUser: { color: "#fff", fontSize: 14, lineHeight: 20 },
  bubbleTextAi: { color: colors.ink, fontSize: 14, lineHeight: 20 },
  bubbleTimeUser: { color: "rgba(255,255,255,0.72)", fontSize: 10, marginTop: 5, textAlign: "right" },
  bubbleTimeAi: { color: colors.mutedLight, fontSize: 10, marginTop: 5, textAlign: "left" },

  composerBar: {
    flexDirection: "row",
    alignItems: "flex-end",
    paddingHorizontal: 14,
    paddingVertical: 9,
    backgroundColor: colors.surface,
    borderTopColor: colors.border,
    borderTopWidth: 1,
    gap: 8,
  },
  chatInput: {
    flex: 1,
    backgroundColor: colors.background,
    borderColor: colors.border,
    borderWidth: 1,
    borderRadius: 20,
    paddingHorizontal: 14,
    paddingVertical: 10,
    color: colors.ink,
    fontSize: 14,
    maxHeight: 110,
  },
  chatSend: {
    width: 42,
    height: 42,
    borderRadius: 21,
    backgroundColor: colors.primary,
    alignItems: "center",
    justifyContent: "center",
  },
  chatSendText: { color: "#fff", fontSize: 19, fontWeight: "900" },

  // Tools
  toolsList: { padding: 20, paddingBottom: 40 },
  sectionTitle: { color: colors.ink, fontSize: 17, fontWeight: "800", marginBottom: 10 },
  suggestions: { flexDirection: "row", gap: 8, marginBottom: 16, flexWrap: "wrap" },
  suggestion: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderWidth: 1,
    borderRadius: 20,
    paddingHorizontal: 14,
    paddingVertical: 9,
  },
  suggestionActive: { backgroundColor: colors.primary },
  suggestionText: { color: colors.ink, fontSize: 13, fontWeight: "700" },
  suggestionTextActive: { color: "#fff" },
  composer: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderWidth: 1,
    borderRadius: 15,
    padding: 12,
    marginBottom: 12,
  },
  input: {
    color: colors.ink,
    minHeight: 90,
    textAlignVertical: "top",
    fontSize: 14,
  },
  composerActions: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  uploadButton: {
    borderColor: colors.primary,
    borderWidth: 1,
    borderRadius: 9,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  uploadText: { color: colors.primary, fontSize: 12, fontWeight: "700" },
  askButton: {
    backgroundColor: colors.primary,
    borderRadius: 9,
    paddingHorizontal: 20,
    paddingVertical: 10,
  },
  askButtonDisabled: { opacity: 0.45 },
  askButtonText: { color: "#fff", fontSize: 13, fontWeight: "700" },
  fileName: { color: colors.muted, fontSize: 12, marginBottom: 10 },
  toolShortcuts: { flexDirection: "row", gap: 8, marginBottom: 8, flexWrap: "wrap" },
  toolShortcut: {
    backgroundColor: colors.greenSoft,
    borderColor: "#bcebd1",
    borderWidth: 1,
    borderRadius: 10,
    paddingHorizontal: 13,
    paddingVertical: 9,
  },
  toolShortcutText: { color: colors.green, fontSize: 12, fontWeight: "700" },
  loader: { marginTop: 16 },
  response: {
    backgroundColor: colors.primarySoft,
    borderRadius: 14,
    padding: 16,
    marginTop: 10,
  },
  responseHeader: { flexDirection: "row", alignItems: "center", marginBottom: 12 },
  responseIcon: {
    width: 36,
    height: 36,
    borderRadius: 11,
    backgroundColor: colors.primary,
    alignItems: "center",
    justifyContent: "center",
    marginRight: 10,
  },
  responseIconText: { color: "#fff", fontSize: 12, fontWeight: "900" },
  responseLabel: {
    color: colors.primary,
    fontSize: 11,
    fontWeight: "800",
    letterSpacing: 1.2,
  },
  responseSubheading: { color: colors.muted, fontSize: 11, marginTop: 4 },
  responseText: { color: colors.ink, fontSize: 14, lineHeight: 21 },

  // Tutor report
  tutorWrap: { marginBottom: 20 },
  tutorEmpty: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderWidth: 1,
    borderRadius: 14,
    padding: 16,
    marginBottom: 20,
  },
  tutorEmptyText: { color: colors.muted, fontSize: 13, lineHeight: 20 },
  tutorCard: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderWidth: 1,
    borderRadius: 14,
    padding: 14,
    marginBottom: 10,
  },
  tutorCardTitle: { color: colors.ink, fontSize: 14, fontWeight: "800", marginBottom: 8 },
  tutorCardMuted: { color: colors.muted, fontSize: 12 },
  tutorRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    borderTopColor: colors.border,
    borderTopWidth: 1,
    paddingTop: 8,
    marginTop: 8,
    gap: 10,
  },
  tutorRowMain: { flex: 1 },
  tutorStudent: { color: colors.ink, fontSize: 13, fontWeight: "700" },
  tutorMeta: { color: colors.muted, fontSize: 11, marginTop: 2 },
  tutorScoreWrap: { width: 88, alignItems: "flex-end" },
  tutorScore: { color: colors.primary, fontSize: 13, fontWeight: "800" },
  tutorBar: {
    backgroundColor: "rgba(23,32,51,0.10)",
    borderRadius: 4,
    height: 5,
    marginTop: 4,
    width: 88,
    overflow: "hidden",
  },
  tutorBarFill: { backgroundColor: colors.primary, borderRadius: 4, height: 5 },
});
