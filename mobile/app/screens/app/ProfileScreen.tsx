/**
 * ProfileScreen — user profile with settings and logout.
 * Displays user info and provides actions for editing profile, changing password, and logout.
 */

import React from "react";
import {
  Alert,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
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

const Icon = ({
  glyph,
  color = palette.primary,
  size = 22,
}: {
  glyph: string;
  color?: string;
  size?: number;
}) => <Text style={{ color, fontSize: size, lineHeight: size + 3 }}>{glyph}</Text>;

export default function ProfileScreen() {
  const { user, logout } = useAuth();

  const handleLogout = async () => {
    Alert.alert(
      "Logout",
      "Are you sure you want to logout?",
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Logout",
          style: "destructive",
          onPress: async () => {
            await logout();
          },
        },
      ],
      { cancelable: true }
    );
  };

  const handleEditProfile = () => {
    Alert.alert("Coming Soon", "Edit profile functionality will be available soon.");
  };

  const handleChangePassword = () => {
    Alert.alert(
      "Coming Soon",
      "Change password functionality will be available soon."
    );
  };

  const handleNotifications = () => {
    Alert.alert(
      "Coming Soon",
      "Notification settings will be available soon."
    );
  };

  const firstName = user?.first_name ?? "";
  const lastName = user?.last_name ?? "";
  const initials = `${firstName.charAt(0)}${lastName.charAt(0)}`.toUpperCase();
  const roleBadgeColor =
    user?.role === "admin"
      ? palette.accent
      : user?.role === "teacher"
      ? palette.orange
      : palette.primary;

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
      showsVerticalScrollIndicator={false}
    >
      {/* Header */}
      <Text style={styles.eyebrow}>YOUR ACCOUNT</Text>
      <Text style={styles.title}>Profile</Text>
      <Text style={styles.subtitle}>Manage your account and preferences.</Text>

      {/* User Info Card */}
      <View style={styles.profileCard}>
        <View style={styles.avatarLarge}>
          <Text style={styles.avatarText}>{initials || "?"}</Text>
        </View>
        <Text style={styles.profileName}>
          {firstName} {lastName}
        </Text>
        <Text style={styles.profileEmail}>{user?.email}</Text>
        <View style={[styles.roleBadge, { backgroundColor: roleBadgeColor }]}>
          <Text style={styles.roleBadgeText}>{user?.role?.toUpperCase()}</Text>
        </View>
      </View>

      {/* Settings Section */}
      <View style={styles.sectionHeader}>
        <Text style={styles.sectionTitle}>Settings</Text>
      </View>
      <View style={styles.card}>
        <Pressable style={styles.settingRow} onPress={handleEditProfile}>
          <View style={styles.settingIconWrap}>
            <Icon glyph="&#9711;" size={20} />
          </View>
          <Text style={styles.settingLabel}>Edit Profile</Text>
          <Icon glyph="›" color={palette.muted} size={22} />
        </Pressable>

        <View style={styles.divider} />

        <Pressable style={styles.settingRow} onPress={handleChangePassword}>
          <View style={styles.settingIconWrap}>
            <Icon glyph="&#128274;" size={18} />
          </View>
          <Text style={styles.settingLabel}>Change Password</Text>
          <Icon glyph="›" color={palette.muted} size={22} />
        </Pressable>

        <View style={styles.divider} />

        <Pressable style={styles.settingRow} onPress={handleNotifications}>
          <View style={styles.settingIconWrap}>
            <Icon glyph="&#128276;" size={18} />
          </View>
          <Text style={styles.settingLabel}>Notifications</Text>
          <Icon glyph="›" color={palette.muted} size={22} />
        </Pressable>
      </View>

      {/* About Section */}
      <View style={styles.sectionHeader}>
        <Text style={styles.sectionTitle}>About</Text>
      </View>
      <View style={styles.card}>
        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Version</Text>
          <Text style={styles.infoValue}>1.0.0</Text>
        </View>
        <View style={styles.divider} />
        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Build</Text>
          <Text style={styles.infoValue}>Preview</Text>
        </View>
      </View>

      {/* Logout Button */}
      <Pressable style={styles.logoutBtn} onPress={handleLogout}>
        <Icon glyph="&#10006;" color="#fff" size={16} />
        <Text style={styles.logoutBtnText}>Logout</Text>
      </Pressable>

      <Text style={styles.footer}>Uni-Hub © 2026</Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: palette.background },
  content: { padding: 20, paddingBottom: 48 },
  eyebrow: {
    color: palette.muted,
    fontSize: 11,
    fontWeight: "700",
    letterSpacing: 1,
    marginBottom: 4,
  },
  title: { color: palette.ink, fontSize: 27, fontWeight: "800" },
  subtitle: { color: palette.muted, fontSize: 14, marginTop: 6, marginBottom: 20 },
  profileCard: {
    alignItems: "center",
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 16,
    borderWidth: 1,
    padding: 24,
    marginBottom: 22,
  },
  avatarLarge: {
    alignItems: "center",
    backgroundColor: palette.primary,
    borderRadius: 48,
    height: 96,
    justifyContent: "center",
    width: 96,
    marginBottom: 16,
  },
  avatarText: { color: "#fff", fontSize: 36, fontWeight: "800" },
  profileName: {
    color: palette.ink,
    fontSize: 22,
    fontWeight: "800",
    marginBottom: 4,
  },
  profileEmail: { color: palette.muted, fontSize: 14, marginBottom: 12 },
  roleBadge: {
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 5,
  },
  roleBadgeText: { color: "#fff", fontSize: 11, fontWeight: "800" },
  sectionHeader: {
    marginBottom: 10,
    marginTop: 2,
  },
  sectionTitle: { color: palette.ink, fontSize: 17, fontWeight: "800" },
  card: {
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: 15,
    borderWidth: 1,
    marginBottom: 22,
    overflow: "hidden",
  },
  settingRow: {
    alignItems: "center",
    flexDirection: "row",
    padding: 14,
  },
  settingIconWrap: {
    alignItems: "center",
    backgroundColor: palette.lavender,
    borderRadius: 10,
    height: 38,
    justifyContent: "center",
    width: 38,
    marginRight: 12,
  },
  settingLabel: {
    flex: 1,
    color: palette.ink,
    fontSize: 15,
    fontWeight: "600",
  },
  divider: { height: 1, backgroundColor: palette.border },
  infoRow: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    padding: 14,
  },
  infoLabel: { color: palette.muted, fontSize: 14, fontWeight: "600" },
  infoValue: { color: palette.ink, fontSize: 14, fontWeight: "700" },
  logoutBtn: {
    alignItems: "center",
    backgroundColor: palette.accent,
    borderRadius: 12,
    flexDirection: "row",
    gap: 8,
    justifyContent: "center",
    paddingVertical: 15,
    marginBottom: 16,
  },
  logoutBtnText: { color: "#fff", fontSize: 15, fontWeight: "800" },
  footer: {
    color: palette.muted,
    fontSize: 12,
    textAlign: "center",
    marginTop: 8,
  },
});
