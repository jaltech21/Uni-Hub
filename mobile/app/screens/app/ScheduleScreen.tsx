import React from "react";
import { ScrollView, StyleSheet, Text, View } from "react-native";

export default function ScheduleScreen() {
  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.eyebrow}>YOUR ACADEMIC CALENDAR</Text>
      <Text style={styles.title}>Schedule</Text>
      <Text style={styles.subtitle}>Plan your classes, events, and study time.</Text>
      <View style={styles.dateCard}>
        <Text style={styles.dateDay}>02</Text>
        <View><Text style={styles.dateMonth}>SEPTEMBER</Text><Text style={styles.dateText}>Wednesday · Today</Text></View>
      </View>
      <View style={styles.emptyCard}>
        <Text style={styles.icon}>□</Text>
        <Text style={styles.emptyTitle}>Your day is clear</Text>
        <Text style={styles.emptyText}>Enroll in classes or add an event to build your schedule.</Text>
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
  dateCard: { alignItems: "center", backgroundColor: "#fff", borderColor: "#e7eaf2", borderRadius: 16, borderWidth: 1, flexDirection: "row", marginVertical: 24, padding: 17 },
  dateDay: { color: "#3b5bfd", fontSize: 34, fontWeight: "800", marginRight: 14 },
  dateMonth: { color: "#667085", fontSize: 11, fontWeight: "800", letterSpacing: 1 },
  dateText: { color: "#172033", fontSize: 14, fontWeight: "700", marginTop: 4 },
  emptyCard: { alignItems: "center", backgroundColor: "#fff", borderRadius: 16, padding: 28 },
  icon: { color: "#3b5bfd", fontSize: 39 },
  emptyTitle: { color: "#172033", fontSize: 16, fontWeight: "800", marginTop: 12 },
  emptyText: { color: "#667085", fontSize: 13, lineHeight: 19, marginTop: 6, textAlign: "center" },
});
