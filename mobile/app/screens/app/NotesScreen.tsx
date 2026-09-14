/**
 * Notes Screen - Placeholder
 */

import React, { useEffect, useState } from "react";
import {
  ActivityIndicator,
  Alert,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import apiClient from "@services/api";
import { Note } from "@app/types";

export default function NotesScreen() {
  const [notes, setNotes] = useState<Note[]>([]);
  const [showEditor, setShowEditor] = useState(false);
  const [title, setTitle] = useState("");
  const [content, setContent] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    apiClient
      .get<Note[]>("/notes")
      .then(setNotes)
      .catch(() => {
        // The empty state remains useful when the notes service is unavailable.
      });
  }, []);

  const createNote = async () => {
    if (!title.trim() || !content.trim()) {
      Alert.alert("Missing details", "Add a title and some note content first.");
      return;
    }

    setSaving(true);
    try {
      const note = await apiClient.post<Note>("/notes", {
        title: title.trim(),
        content: content.trim(),
      });
      setNotes((current) => [note, ...current]);
      setTitle("");
      setContent("");
      setShowEditor(false);
    } catch (error: any) {
      Alert.alert("Could not save note", error.message || "Please try again.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.headingRow}>
        <View>
          <Text style={styles.title}>Notes</Text>
          <Text style={styles.subtitle}>Capture ideas and summarize your learning.</Text>
        </View>
        <Pressable style={styles.newButton} onPress={() => setShowEditor((visible) => !visible)}>
          <Text style={styles.newButtonText}>{showEditor ? "Cancel" : "+ New note"}</Text>
        </Pressable>
      </View>

      {showEditor ? (
        <View style={styles.editor}>
          <TextInput
            value={title}
            onChangeText={setTitle}
            placeholder="Note title"
            placeholderTextColor="#98a2b3"
            style={styles.input}
          />
          <TextInput
            value={content}
            onChangeText={setContent}
            placeholder="Start writing your note..."
            placeholderTextColor="#98a2b3"
            multiline
            textAlignVertical="top"
            style={[styles.input, styles.contentInput]}
          />
          <Pressable style={styles.saveButton} onPress={createNote} disabled={saving}>
            {saving ? <ActivityIndicator color="#fff" /> : <Text style={styles.saveButtonText}>Save note</Text>}
          </Pressable>
        </View>
      ) : null}

      {notes.length ? (
        notes.map((note) => (
          <View style={styles.noteCard} key={note.id}>
            <Text style={styles.noteTitle}>{note.title}</Text>
            <Text style={styles.noteContent} numberOfLines={3}>{note.content}</Text>
          </View>
        ))
      ) : (
        <View style={styles.emptyCard}>
          <Text style={styles.emptyIcon}>▤</Text>
          <Text style={styles.emptyTitle}>No notes yet</Text>
          <Text style={styles.emptyText}>Create your first note to get started.</Text>
          <Pressable onPress={() => setShowEditor(true)}>
            <Text style={styles.emptyLink}>Create a note</Text>
          </Pressable>
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f5f7fb" },
  content: { padding: 20, paddingBottom: 36 },
  headingRow: { alignItems: "center", flexDirection: "row", justifyContent: "space-between", marginBottom: 20 },
  title: { color: "#172033", fontSize: 25, fontWeight: "800" },
  subtitle: { color: "#667085", fontSize: 13, marginTop: 5 },
  newButton: { backgroundColor: "#3b5bfd", borderRadius: 10, paddingHorizontal: 13, paddingVertical: 10 },
  newButtonText: { color: "#fff", fontSize: 12, fontWeight: "800" },
  editor: { backgroundColor: "#fff", borderColor: "#e7eaf2", borderRadius: 15, borderWidth: 1, marginBottom: 18, padding: 14 },
  input: { borderBottomColor: "#e7eaf2", borderBottomWidth: 1, color: "#172033", fontSize: 15, paddingVertical: 10 },
  contentInput: { borderBottomWidth: 0, minHeight: 110 },
  saveButton: { alignItems: "center", backgroundColor: "#3b5bfd", borderRadius: 9, paddingVertical: 12 },
  saveButtonText: { color: "#fff", fontSize: 13, fontWeight: "800" },
  emptyCard: { alignItems: "center", backgroundColor: "#fff", borderRadius: 15, padding: 28 },
  emptyIcon: { color: "#3b5bfd", fontSize: 34, marginBottom: 8 },
  emptyTitle: { color: "#172033", fontSize: 15, fontWeight: "800" },
  emptyText: { color: "#667085", fontSize: 13, marginTop: 7 },
  emptyLink: { color: "#3b5bfd", fontSize: 13, fontWeight: "700", marginTop: 14 },
  noteCard: { backgroundColor: "#fff", borderColor: "#e7eaf2", borderRadius: 15, borderWidth: 1, marginBottom: 12, padding: 16 },
  noteTitle: { color: "#172033", fontSize: 16, fontWeight: "800" },
  noteContent: { color: "#667085", fontSize: 13, lineHeight: 19, marginTop: 7 },
});
