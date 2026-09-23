/**
 * ProfileScreen — user profile with settings and logout.
 * Edit profile and change password are wired to the API through AuthContext.
 */

import React, { useState } from "react";
import {
  ActivityIndicator,
  Alert,
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
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

type ModalKind = "profile" | "password" | "logout" | null;

export default function ProfileScreen({ navigation }: { navigation: any }) {
  const { user, logout, updateProfile, changePassword } = useAuth();
  const [modal, setModal] = useState<ModalKind>(null);
  const [loggingOut, setLoggingOut] = useState(false);
  const [logoutError, setLogoutError] = useState<string | null>(null);

  // Edit profile state
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [email, setEmail] = useState("");
  const [username, setUsername] = useState("");
  const [savingProfile, setSavingProfile] = useState(false);

  // Change password state
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [savingPassword, setSavingPassword] = useState(false);

  const openProfile = () => {
    setFirstName(user?.first_name ?? "");
    setLastName(user?.last_name ?? "");
    setEmail(user?.email ?? "");
    setUsername(user?.username ?? "");
    setModal("profile");
  };

  const openPassword = () => {
    setCurrentPassword("");
    setNewPassword("");
    setConfirmPassword("");
    setModal("password");
  };

  const openLogout = () => {
    setLogoutError(null);
    setModal("logout");
  };

  const handleLogout = async () => {
    // In-app confirmation modal instead of Alert.alert because
    // react-native-web's Alert is a no-op, which made the previous logout
    // confirmation (and the logout itself) silently do nothing on the web
    // build. On success the AuthContext clears the user and this screen
    // unmounts; the modal only closes on failure.
    setLoggingOut(true);
    setLogoutError(null);
    try {
      await logout();
    } catch (e: any) {
      setLogoutError(e.message || "Please try again.");
      setLoggingOut(false);
    }
  };

  const handleSaveProfile = async () => {
    if (!firstName.trim() || !lastName.trim() || !email.trim()) {
      Alert.alert("Validation", "First name, last name and email are required.");
      return;
    }
    setSavingProfile(true);
    try {
      await updateProfile({
        first_name: firstName.trim(),
        last_name: lastName.trim(),
        email: email.trim().toLowerCase(),
        username: username.trim() || undefined,
      });
      setModal(null);
      Alert.alert("Profile updated", "Your profile has been saved.");
    } catch (e: any) {
      Alert.alert("Update failed", e.message || "Please try again.");
    } finally {
      setSavingProfile(false);
    }
  };

  const handleSavePassword = async () => {
    if (!currentPassword) {
      Alert.alert("Validation", "Enter your current password.");
      return;
    }
    if (newPassword.length < 8) {
      Alert.alert("Validation", "New password must be at least 8 characters.");
      return;
    }
    if (newPassword !== confirmPassword) {
      Alert.alert("Validation", "New password and confirmation do not match.");
      return;
    }
    setSavingPassword(true);
    try {
      await changePassword(currentPassword, newPassword);
      setModal(null);
      Alert.alert("Password changed", "Your password has been updated.");
    } catch (e: any) {
      Alert.alert("Change failed", e.message || "Please try again.");
    } finally {
      setSavingPassword(false);
    }
  };

  const handleNotifications = () => {
    navigation?.navigate("Notifications");
  };

  const firstName0 = user?.first_name ?? "";
  const lastName0 = user?.last_name ?? "";
  const initials = `${firstName0.charAt(0)}${lastName0.charAt(0)}`.toUpperCase();
  const roleBadgeColor =
    user?.role === "admin"
      ? palette.accent
      : user?.role === "teacher" || user?.role === "tutor"
      ? palette.orange
      : palette.primary;

  return (
    <>
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
            {firstName0} {lastName0}
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
          <Pressable style={styles.settingRow} onPress={openProfile}>
            <View style={styles.settingIconWrap}>
              <Icon glyph="&#9711;" size={20} />
            </View>
            <Text style={styles.settingLabel}>Edit Profile</Text>
            <Icon glyph="›" color={palette.muted} size={22} />
          </Pressable>

          <View style={styles.divider} />

          <Pressable style={styles.settingRow} onPress={openPassword}>
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
        <Pressable style={styles.logoutBtn} onPress={openLogout}>
          <Icon glyph="&#10006;" color="#fff" size={16} />
          <Text style={styles.logoutBtnText}>Logout</Text>
        </Pressable>

        <Text style={styles.footer}>Uni-Hub © 2026</Text>
      </ScrollView>

      {/* Edit profile modal */}
      <Modal
        visible={modal === "profile"}
        animationType="slide"
        transparent
        onRequestClose={() => setModal(null)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalSheet}>
            <Text style={styles.modalTitle}>Edit Profile</Text>
            <Text style={styles.modalHint}>Update your account details below.</Text>

            <Text style={styles.inputLabel}>First name</Text>
            <TextInput
              style={styles.input}
              value={firstName}
              onChangeText={setFirstName}
              placeholder="First name"
              placeholderTextColor="#adb5bd"
            />
            <Text style={styles.inputLabel}>Last name</Text>
            <TextInput
              style={styles.input}
              value={lastName}
              onChangeText={setLastName}
              placeholder="Last name"
              placeholderTextColor="#adb5bd"
            />
            <Text style={styles.inputLabel}>Email</Text>
            <TextInput
              style={styles.input}
              value={email}
              onChangeText={setEmail}
              placeholder="you@unihub.edu"
              placeholderTextColor="#adb5bd"
              autoCapitalize="none"
              keyboardType="email-address"
            />
            <Text style={styles.inputLabel}>Username</Text>
            <TextInput
              style={styles.input}
              value={username}
              onChangeText={setUsername}
              placeholder="username"
              placeholderTextColor="#adb5bd"
              autoCapitalize="none"
            />

            <View style={styles.modalActions}>
              <Pressable style={styles.modalCancel} onPress={() => setModal(null)}>
                <Text style={styles.modalCancelText}>Cancel</Text>
              </Pressable>
              <Pressable
                style={[styles.modalPrimary, savingProfile && styles.modalDisabled]}
                onPress={handleSaveProfile}
                disabled={savingProfile}
              >
                {savingProfile ? (
                  <ActivityIndicator size="small" color="#fff" />
                ) : (
                  <Text style={styles.modalPrimaryText}>Save</Text>
                )}
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>

      {/* Change password modal */}
      <Modal
        visible={modal === "password"}
        animationType="slide"
        transparent
        onRequestClose={() => setModal(null)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalSheet}>
            <Text style={styles.modalTitle}>Change Password</Text>
            <Text style={styles.modalHint}>
              Use at least 8 characters with a mix of letters, numbers or symbols.
            </Text>

            <Text style={styles.inputLabel}>Current password</Text>
            <TextInput
              style={styles.input}
              value={currentPassword}
              onChangeText={setCurrentPassword}
              secureTextEntry
              placeholder="Current password"
              placeholderTextColor="#adb5bd"
            />
            <Text style={styles.inputLabel}>New password</Text>
            <TextInput
              style={styles.input}
              value={newPassword}
              onChangeText={setNewPassword}
              secureTextEntry
              placeholder="New password"
              placeholderTextColor="#adb5bd"
            />
            <Text style={styles.inputLabel}>Confirm new password</Text>
            <TextInput
              style={styles.input}
              value={confirmPassword}
              onChangeText={setConfirmPassword}
              secureTextEntry
              placeholder="Confirm new password"
              placeholderTextColor="#adb5bd"
            />

            <View style={styles.modalActions}>
              <Pressable style={styles.modalCancel} onPress={() => setModal(null)}>
                <Text style={styles.modalCancelText}>Cancel</Text>
              </Pressable>
              <Pressable
                style={[styles.modalPrimary, savingPassword && styles.modalDisabled]}
                onPress={handleSavePassword}
                disabled={savingPassword}
              >
                {savingPassword ? (
                  <ActivityIndicator size="small" color="#fff" />
                ) : (
                  <Text style={styles.modalPrimaryText}>Update</Text>
                )}
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>

      {/* Logout confirmation modal */}
      <Modal
        visible={modal === "logout"}
        animationType="fade"
        transparent
        onRequestClose={() => {
          if (!loggingOut) setModal(null);
        }}
      >
        <View style={styles.modalOverlayCenter}>
          <View style={styles.logoutCard}>
            <View style={styles.logoutIconWrap}>
              <Text style={styles.logoutIcon}>&#10006;</Text>
            </View>
            <Text style={styles.logoutTitle}>Sign out of Uni-Hub?</Text>
            <Text style={styles.logoutBody}>
              You will need to sign in again to access your courses, notes and
              messages.
            </Text>
            {logoutError ? (
              <Text style={styles.logoutError}>{logoutError}</Text>
            ) : null}
            <View style={styles.modalActions}>
              <Pressable
                style={styles.modalCancel}
                onPress={() => setModal(null)}
                disabled={loggingOut}
              >
                <Text style={styles.modalCancelText}>Cancel</Text>
              </Pressable>
              <Pressable
                style={[styles.logoutConfirm, loggingOut && styles.modalDisabled]}
                onPress={handleLogout}
                disabled={loggingOut}
              >
                {loggingOut ? (
                  <ActivityIndicator size="small" color="#fff" />
                ) : (
                  <Text style={styles.modalPrimaryText}>Logout</Text>
                )}
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>
    </>
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
  sectionHeader: { marginBottom: 10, marginTop: 2 },
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
  // Modal
  modalOverlay: { flex: 1, backgroundColor: "rgba(0,0,0,0.4)", justifyContent: "flex-end" },
  modalOverlayCenter: {
    flex: 1,
    backgroundColor: "rgba(0,0,0,0.4)",
    justifyContent: "center",
    alignItems: "center",
    padding: 24,
  },
  modalSheet: {
    backgroundColor: palette.surface,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: 24,
    paddingBottom: 40,
  },
  modalTitle: { fontSize: 19, fontWeight: "800", color: palette.ink },
  modalHint: { fontSize: 13, color: palette.muted, marginTop: 6, marginBottom: 4, lineHeight: 19 },
  inputLabel: { fontSize: 12, fontWeight: "700", color: palette.ink, marginTop: 14, marginBottom: 6 },
  input: {
    backgroundColor: "#f5f7fb",
    borderRadius: 10,
    borderWidth: 1,
    borderColor: palette.border,
    padding: 12,
    fontSize: 14,
    color: palette.ink,
  },
  modalActions: { flexDirection: "row", gap: 10, marginTop: 22 },
  modalCancel: {
    flex: 1,
    backgroundColor: "#f1f3f5",
    borderRadius: 10,
    paddingVertical: 13,
    alignItems: "center",
  },
  modalCancelText: { color: "#495057", fontWeight: "700" },
  modalPrimary: {
    flex: 1,
    backgroundColor: palette.primary,
    borderRadius: 10,
    paddingVertical: 13,
    alignItems: "center",
  },
  modalDisabled: { opacity: 0.6 },
  modalPrimaryText: { color: "#fff", fontWeight: "700" },
  // Logout confirm card
  logoutCard: {
    backgroundColor: palette.surface,
    borderRadius: 18,
    padding: 24,
    width: "100%",
    maxWidth: 360,
    alignItems: "center",
  },
  logoutIconWrap: {
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: palette.accentSoft,
    alignItems: "center",
    justifyContent: "center",
    marginBottom: 14,
  },
  logoutIcon: { color: palette.accent, fontSize: 24, fontWeight: "800" },
  logoutTitle: { fontSize: 19, fontWeight: "800", color: palette.ink, textAlign: "center" },
  logoutBody: {
    fontSize: 13,
    color: palette.muted,
    lineHeight: 20,
    textAlign: "center",
    marginTop: 6,
  },
  logoutError: {
    fontSize: 13,
    color: palette.accent,
    fontWeight: "600",
    marginTop: 10,
    textAlign: "center",
  },
  logoutConfirm: {
    flex: 1,
    backgroundColor: palette.accent,
    borderRadius: 10,
    paddingVertical: 13,
    alignItems: "center",
  },
});