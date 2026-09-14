import React from "react";
import { ScrollView, StyleSheet, Text, View } from "react-native";

export default function AssignmentsScreen() {
  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.eyebrow}>ACADEMIC WORK</Text>
      <Text style={styles.title}>Assignments</Text>
      <Text style={styles.subtitle}>Track deadlines and submit your coursework.</Text>
      <View style={styles.summary}>
        <View><Text style={styles.summaryValue}>0</Text><Text style={styles.summaryLabel}>Due soon</Text></View>
        <View><Text style={styles.summaryValue}>0</Text><Text style={styles.summaryLabel}>Submitted</Text></View>
        <View><Text style={styles.summaryValue}>0</Text><Text style={styles.summaryLabel}>Graded</Text></View>
      </View>
      <View style={styles.emptyCard}>
        <View style={styles.icon}><Text style={styles.iconText}>✓</Text></View>
        <Text style={styles.emptyTitle}>No assignments yet</Text>
        <Text style={styles.emptyText}>New coursework from your enrolled classes will appear here.</Text>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f5f7fb" },
  content: { padding: 20, paddingBottom: 36 },
  eyebrow: { color: "#667085", fontSize: 11, fontWeight: "800", letterSpacing: 1 },
  title: { color: "#172033", fontSize: 27, fontWeight: "800", marginTop: 5 },
  subtitle: { color: "#667085", fontSize: 14, marginTop: 6 },
  summary: { backgroundColor: "#3b5bfd", borderRadius: 17, flexDirection: "row", justifyContent: "space-between", marginVertical: 24, padding: 20 },
  summaryValue: { color: "#fff", fontSize: 24, fontWeight: "800" },
  summaryLabel: { color: "#dfe5ff", fontSize: 11, marginTop: 3 },
  emptyCard: { alignItems: "center", backgroundColor: "#fff", borderColor: "#e7eaf2", borderRadius: 16, borderWidth: 1, padding: 28 },
  icon: { alignItems: "center", backgroundColor: "#e8f8f1", borderRadius: 15, height: 54, justifyContent: "center", width: 54 },
  iconText: { color: "#0e9f6e", fontSize: 26, fontWeight: "800" },
  emptyTitle: { color: "#172033", fontSize: 16, fontWeight: "800", marginTop: 14 },
  emptyText: { color: "#667085", fontSize: 13, lineHeight: 19, marginTop: 6, textAlign: "center" },
});
