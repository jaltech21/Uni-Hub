import React, { useEffect, useState } from "react";
import * as DocumentPicker from "expo-document-picker";
import { ActivityIndicator, Alert, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import apiClient from "@services/api";

const colors = { ink: "#172033", muted: "#667085", primary: "#3b5bfd", background: "#f5f7fb", surface: "#fff", border: "#e7eaf2", lavender: "#eef0ff" };
const countWords = (value: string) => value.trim() ? value.trim().split(/\s+/).length : 0;

type SummaryResponse = { summary?: string; source_length?: number; source_word_count?: number; hints?: string[]; questions?: unknown[] };
type Progress = {
  status: "critical" | "warning" | "on_track";
  score: number;
  label: string;
  metrics: { upcoming_assignments: number; overdue_assignments: number; pending_submissions: number; average_grade: number | null; recent_notes: number; scheduled_classes: number };
};

export default function AIAssistantScreen() {
  const [question, setQuestion] = useState("");
  const [summary, setSummary] = useState("");
  const [sourceWordCount, setSourceWordCount] = useState(0);
  const [sourceName, setSourceName] = useState("");
  const [selectedFile, setSelectedFile] = useState<DocumentPicker.DocumentPickerAsset | null>(null);
  const [action, setAction] = useState<"assistant" | "summarize" | "hints" | "questions">("assistant");
  const [loading, setLoading] = useState(false);
  const [progress, setProgress] = useState<Progress | null>(null);

  useEffect(() => {
    apiClient.get<Progress>("/ai/progress").then(setProgress).catch(() => undefined);
  }, []);

  const runSummary = async (text = question, file: DocumentPicker.DocumentPickerAsset | null = selectedFile) => {
    if (!text.trim() && !file) {
      Alert.alert("Add study material", "Paste at least 100 characters or upload a PDF.");
      return;
    }
    setLoading(true);
    setSummary("");
    setSourceWordCount(0);
    try {
      let result: SummaryResponse;
      if (file) {
        const formData = new FormData();
        const fileName = file.name || "study-material.pdf";

        if (Platform.OS === "web") {
          const browserFile = (file as DocumentPicker.DocumentPickerAsset & { file?: File | Blob }).file;
          if (browserFile instanceof File && browserFile.size > 0) {
            formData.append("file", browserFile, fileName);
          } else {
            const fileResponse = await fetch(file.uri);
            if (!fileResponse.ok) throw new Error("The selected PDF could not be opened.");
            const blob = await fileResponse.blob();
            if (!blob.size || blob.size === 0) throw new Error("The selected PDF is empty or unavailable.");
            const pdfFile = new File([blob], fileName, { type: blob.type || "application/pdf" });
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
        formData.append("mode", action);
        if (text.trim()) formData.append("text", text);

        result = await apiClient.post<SummaryResponse>("/ai/summarize", formData, {
          headers: { "Content-Type": "multipart/form-data" },
        });
      } else {
        result = await apiClient.post<SummaryResponse>("/ai/summarize", { text, length: "medium", mode: action });
      }
      const responseText = result.summary || (result.hints || []).join("\n\n") || "No answer was returned. Please try again.";
      setSummary(responseText);
      setSourceWordCount(result.source_word_count ?? countWords(text));
    } catch (error: any) {
      Alert.alert("AI request failed", error.message || "Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const choosePdf = async () => {
    const result = await DocumentPicker.getDocumentAsync({ type: "application/pdf", copyToCacheDirectory: true });
    if (result.canceled) return;
    const file = result.assets[0];
    setSelectedFile(file);
    setSourceName(file.name || "PDF study material");
  };

  const useShortcut = async (label: string) => {
    const selectedAction: "assistant" | "summarize" | "questions" =
      label === "Create a study plan" || label === "Explain a difficult topic" ? "assistant" :
      label === "Generate exam questions" ? "questions" : "summarize";
    setAction(selectedAction);
    const prompts: Record<string, string> = {
      "Create a study plan": "Create a concrete study plan for my current courses. Use my schedules, upcoming assignments, and notes from the application context. Organize it by day and include session durations, topics, revision, breaks, and clear priorities.",
      "Explain a difficult topic": "Explain the difficult topic below step by step in simple academic language. Include one worked example, three key points, and one short question to check understanding:\n\n",
      "Generate exam questions": "Upload a PDF or paste study material to generate possible exam questions.",
      "Summarize my notes": "",
    };
    if (label === "Summarize my notes") {
      setLoading(true);
      try {
        const notes = await apiClient.get<Array<{ title?: string; content?: string }>>("/notes");
        const noteText = notes.map((note) => `${note.title || "Note"}\n${note.content || ""}`).join("\n\n");
        setQuestion(noteText);
        if (noteText.length >= 100) await runSummary(noteText);
      } catch (error: any) {
        Alert.alert("Could not load notes", error.message || "Please try again.");
        setLoading(false);
      }
      return;
    }
    setQuestion(prompts[label]);
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.header}><View style={styles.avatar}><Text style={styles.avatarText}>U</Text></View><View><Text style={styles.title}>UniHub AI</Text><Text style={styles.subtitle}>Your personal study assistant</Text></View><View style={styles.online}><Text style={styles.onlineDot}>●</Text><Text style={styles.onlineText}>Ready</Text></View></View>
      <View style={styles.hero}><Text style={styles.heroTitle}>Study smarter, not harder</Text><Text style={styles.heroText}>Get help organising your workload, understanding topics, and summarising study material.</Text></View>
      {progress ? (
        <View style={[styles.progressCard, progress.status === "critical" ? styles.critical : progress.status === "warning" ? styles.warning : styles.onTrack]}>
          <View style={styles.progressTop}><View><Text style={styles.progressEyebrow}>YOUR LEARNING PULSE</Text><Text style={styles.progressTitle}>{progress.label}</Text></View><Text style={styles.progressScore}>{progress.score}</Text></View>
          <View style={styles.progressBar}><View style={[styles.progressFill, progress.status === "critical" ? styles.fillCritical : progress.status === "warning" ? styles.fillWarning : styles.fillOnTrack, { width: `${progress.score}%` }]} /></View>
          <Text style={styles.progressHint}>{progress.metrics.overdue_assignments > 0 ? `${progress.metrics.overdue_assignments} overdue assignment${progress.metrics.overdue_assignments === 1 ? "" : "s"} need attention.` : "Your current activity is building positive momentum."}</Text>
          <View style={styles.metricRow}><Text style={styles.metric}>{progress.metrics.upcoming_assignments} due soon</Text><Text style={styles.metric}>{progress.metrics.pending_submissions} pending</Text><Text style={styles.metric}>{progress.metrics.recent_notes} recent notes</Text></View>
        </View>
      ) : null}
      <Text style={styles.sectionTitle}>What can I help with?</Text>
      <View style={styles.suggestions}>
        {["Create a study plan", "Explain a difficult topic", "Generate exam questions", "Summarize my notes"].map((item) => (
          <Pressable key={item} style={styles.suggestion} onPress={() => useShortcut(item)}><Text style={styles.suggestionText}>{item}</Text><Text style={styles.arrow}>›</Text></Pressable>
        ))}
      </View>
      <Text style={styles.sectionTitle}>Ask UniHub AI</Text>
      <View style={styles.composer}>
        <TextInput multiline value={question} onChangeText={setQuestion} placeholder="Paste notes or ask a study question..." placeholderTextColor="#98a2b3" style={styles.input} />
        <View style={styles.composerActions}>
          <Pressable style={styles.uploadButton} onPress={choosePdf} disabled={loading}><Text style={styles.uploadText}>Upload PDF</Text></Pressable>
          <Pressable style={[styles.askButton, (!question.trim() && !selectedFile || loading) && styles.askButtonDisabled]} disabled={(!question.trim() && !selectedFile) || loading} onPress={() => runSummary()}><Text style={styles.askButtonText}>{loading ? "Working..." : "Ask AI"}</Text></Pressable>
        </View>
      </View>
      {sourceName ? <Text style={styles.fileName}>Selected: {sourceName}</Text> : null}
      {loading ? <ActivityIndicator color={colors.primary} style={styles.loader} /> : null}
      {summary ? (
        <View style={[styles.response, action === "assistant" ? styles.insightResponse : null]}>
          <View style={styles.responseHeader}>
            <View style={styles.responseIcon}><Text style={styles.responseIconText}>{action === "questions" ? "Q" : action === "summarize" ? "S" : "AI"}</Text></View>
            <View><Text style={styles.responseLabel}>{action === "questions" ? "EXAM QUESTIONS" : action === "assistant" ? "UNIHUB AI INSIGHT" : "SUMMARY"}</Text><Text style={styles.responseSubheading}>{action === "assistant" ? "Personalised guidance for your next step" : action === "questions" ? "Practice questions from your study material" : "Key ideas from your notes"}</Text></View>
          </View>
          {action === "summarize" ? (
            <View style={styles.responseStats}>
              <View style={styles.stat}><Text style={styles.statValue}>{sourceWordCount.toLocaleString()}</Text><Text style={styles.statLabel}>Original words</Text></View>
              <View style={styles.statDivider} />
              <View style={styles.stat}><Text style={styles.statValue}>{countWords(summary).toLocaleString()}</Text><Text style={styles.statLabel}>Summary words</Text></View>
            </View>
          ) : null}
          <Text style={styles.responseText}>{summary}</Text>
        </View>
      ) : null}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: 20, paddingBottom: 36 },
  header: { flexDirection: "row", alignItems: "center", marginBottom: 22 },
  avatar: { width: 48, height: 48, borderRadius: 16, backgroundColor: "#172033", alignItems: "center", justifyContent: "center", marginRight: 12 },
  avatarText: { color: "#fff", fontSize: 20, fontWeight: "900" },
  online: { alignItems: "center", flexDirection: "row", marginLeft: "auto" },
  onlineDot: { color: "#18a66a", fontSize: 12, marginRight: 4 },
  onlineText: { color: "#18a66a", fontSize: 11, fontWeight: "700" },
  aiBadge: { width: 48, height: 48, borderRadius: 15, backgroundColor: colors.primary, alignItems: "center", justifyContent: "center", marginRight: 12 },
  aiBadgeText: { color: "#fff", fontSize: 15, fontWeight: "800" },
  title: { color: colors.ink, fontSize: 24, fontWeight: "800" },
  subtitle: { color: colors.muted, fontSize: 13, marginTop: 3 },
  hero: { backgroundColor: colors.primary, borderRadius: 18, padding: 20, marginBottom: 26 },
  heroTitle: { color: "#fff", fontSize: 18, fontWeight: "800" },
  heroText: { color: "#dfe5ff", fontSize: 13, lineHeight: 20, marginTop: 8 },
  progressCard: { borderRadius: 16, padding: 16, marginBottom: 24, borderWidth: 1 },
  critical: { backgroundColor: "#fff1f1", borderColor: "#ffcaca" },
  warning: { backgroundColor: "#fff8ea", borderColor: "#f6d48b" },
  onTrack: { backgroundColor: "#effbf5", borderColor: "#bcebd1" },
  progressTop: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  progressEyebrow: { color: colors.muted, fontSize: 10, fontWeight: "800", letterSpacing: 1 },
  progressTitle: { color: colors.ink, fontSize: 16, fontWeight: "800", marginTop: 4 },
  progressScore: { color: colors.primary, fontSize: 26, fontWeight: "900" },
  progressBar: { backgroundColor: "rgba(23,32,51,0.10)", borderRadius: 5, height: 7, marginTop: 13, overflow: "hidden" },
  progressFill: { backgroundColor: colors.primary, borderRadius: 5, height: 7 },
  fillCritical: { backgroundColor: "#dc4c4c" },
  fillWarning: { backgroundColor: "#e8a11a" },
  fillOnTrack: { backgroundColor: "#18a66a" },
  progressHint: { color: colors.muted, fontSize: 12, lineHeight: 18, marginTop: 10 },
  metricRow: { flexDirection: "row", flexWrap: "wrap", gap: 8, marginTop: 12 },
  metric: { color: colors.ink, fontSize: 11, fontWeight: "700" },
  sectionTitle: { color: colors.ink, fontSize: 17, fontWeight: "800", marginBottom: 10 },
  suggestions: { marginBottom: 25 },
  suggestion: { backgroundColor: colors.surface, borderColor: colors.border, borderWidth: 1, borderRadius: 13, padding: 15, flexDirection: "row", justifyContent: "space-between", marginBottom: 9 },
  suggestionText: { color: colors.ink, fontSize: 14, fontWeight: "600" },
  arrow: { color: colors.primary, fontSize: 22, lineHeight: 16 },
  composer: { backgroundColor: colors.surface, borderColor: colors.border, borderWidth: 1, borderRadius: 15, padding: 12 },
  input: { color: colors.ink, minHeight: 90, textAlignVertical: "top", fontSize: 14 },
  composerActions: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  uploadButton: { borderColor: colors.primary, borderWidth: 1, borderRadius: 9, paddingHorizontal: 12, paddingVertical: 10 },
  uploadText: { color: colors.primary, fontSize: 12, fontWeight: "700" },
  askButton: { backgroundColor: colors.primary, borderRadius: 9, paddingHorizontal: 18, paddingVertical: 10 },
  askButtonDisabled: { opacity: 0.45 },
  askButtonText: { color: "#fff", fontSize: 13, fontWeight: "700" },
  fileName: { color: colors.muted, fontSize: 12, marginTop: 8 },
  loader: { marginTop: 18 },
  response: { backgroundColor: colors.lavender, borderRadius: 14, padding: 16, marginTop: 18 },
  insightResponse: { backgroundColor: colors.surface, borderColor: colors.border, borderWidth: 1 },
  responseHeader: { alignItems: "center", flexDirection: "row", marginBottom: 14 },
  responseIcon: { alignItems: "center", backgroundColor: colors.primary, borderRadius: 11, height: 36, justifyContent: "center", marginRight: 10, width: 36 },
  responseIconText: { color: "#fff", fontSize: 12, fontWeight: "900" },
  responseStats: { alignItems: "center", borderBottomColor: "#DCE1FF", borderBottomWidth: 1, flexDirection: "row", marginBottom: 14, paddingBottom: 13 },
  responseLabel: { color: colors.primary, fontSize: 11, fontWeight: "800", letterSpacing: 1.2, marginBottom: 9 },
  responseSubheading: { color: colors.muted, fontSize: 11, marginTop: -5 },
  stat: { flex: 1 },
  statDivider: { backgroundColor: "#D1D8FA", height: 30, marginHorizontal: 10, width: 1 },
  statValue: { color: colors.primary, fontSize: 17, fontWeight: "800" },
  statLabel: { color: colors.muted, fontSize: 10, marginTop: 3 },
  responseText: { color: colors.ink, fontSize: 14, lineHeight: 21 },
});
