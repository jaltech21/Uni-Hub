import React from "react";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";

export default function MessagesScreen() {
  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.headingRow}>
        <View><Text style={styles.eyebrow}>STAY CONNECTED</Text><Text style={styles.title}>Messages</Text><Text style={styles.subtitle}>Your conversations in one place.</Text></View>
        <Pressable style={styles.compose}><Text style={styles.composeText}>+</Text></Pressable>
      </View>
      <View style={styles.emptyCard}>
        <View style={styles.icon}><Text style={styles.iconText}>✉</Text></View>
        <Text style={styles.emptyTitle}>No conversations yet</Text>
        <Text style={styles.emptyText}>Message classmates, instructors, and your academic community.</Text>
        <Pressable style={styles.primaryButton}><Text style={styles.primaryText}>Start a conversation</Text></Pressable>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f5f7fb" },
  content: { padding: 20, paddingBottom: 36 },
  headingRow: { alignItems: "center", flexDirection: "row", justifyContent: "space-between", marginBottom: 24 },
  eyebrow: { color: "#667085", fontSize: 11, fontWeight: "800", letterSpacing: 1 },
  title: { color: "#172033", fontSize: 27, fontWeight: "800", marginTop: 5 },
  subtitle: { color: "#667085", fontSize: 14, marginTop: 6 },
  compose: { alignItems: "center", backgroundColor: "#3b5bfd", borderRadius: 15, height: 46, justifyContent: "center", width: 46 },
  composeText: { color: "#fff", fontSize: 27, fontWeight: "300" },
  emptyCard: { alignItems: "center", backgroundColor: "#fff", borderRadius: 16, padding: 28 },
  icon: { alignItems: "center", backgroundColor: "#eef0ff", borderRadius: 15, height: 54, justifyContent: "center", width: 54 },
  iconText: { color: "#3b5bfd", fontSize: 24 },
  emptyTitle: { color: "#172033", fontSize: 16, fontWeight: "800", marginTop: 14 },
  emptyText: { color: "#667085", fontSize: 13, lineHeight: 19, marginTop: 6, textAlign: "center" },
  primaryButton: { backgroundColor: "#3b5bfd", borderRadius: 9, marginTop: 18, paddingHorizontal: 16, paddingVertical: 11 },
  primaryText: { color: "#fff", fontSize: 12, fontWeight: "800" },
});
