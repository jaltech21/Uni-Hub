import React, { useEffect, useState } from "react";
import {
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { useAuth } from "@context/AuthContext";

const BLUE = "#2858E8";
const INK = "#17233D";
const MUTED = "#6F7A91";
const ONBOARDING_KEY = "@unihub/onboarding-complete";

function UniHubMark({ inverted = false }: { inverted?: boolean }) {
  return (
    <View style={styles.brandRow}>
      <View style={[styles.mark, inverted && styles.markInverted]}>
        <View style={[styles.markPage, styles.markPageBack]} />
        <View style={[styles.markPage, styles.markPageFront]} />
        <View style={styles.markSpine} />
      </View>
      <Text style={[styles.brandName, inverted && styles.brandNameInverted]}>UniHub</Text>
    </View>
  );
}

function StudentAvatar({ variant = "primary" }: { variant?: "primary" | "secondary" }) {
  const isSecondary = variant === "secondary";
  return (
    <View style={styles.avatarScene} accessibilityLabel="Illustration of a UniHub student">
      <View style={[styles.sun, isSecondary && styles.sunSecondary]} />
      <View style={[styles.avatarShadow, isSecondary && styles.avatarShadowSecondary]} />
      <View style={[styles.backpack, isSecondary && styles.backpackSecondary]} />
      <View style={[styles.avatarBody, isSecondary && styles.avatarBodySecondary]} />
      <View style={[styles.avatarArm, isSecondary && styles.avatarArmSecondary]} />
      <View style={[styles.avatarHand, isSecondary && styles.avatarHandSecondary]} />
      <View style={[styles.avatarNeck, isSecondary && styles.avatarNeckSecondary]} />
      <View style={[styles.avatarFace, isSecondary && styles.avatarFaceSecondary]}>
        <View style={[styles.avatarHair, isSecondary && styles.avatarHairSecondary]} />
        <View style={styles.avatarEyeLeft} />
        <View style={styles.avatarEyeRight} />
        <View style={styles.avatarSmile} />
      </View>
      <View style={[styles.book, isSecondary && styles.bookSecondary]} />
      <View style={[styles.bookPage, isSecondary && styles.bookPageSecondary]} />
    </View>
  );
}

function WelcomeScreen({ onNext }: { onNext: () => void }) {
  return (
    <View style={styles.blueScreen}>
      <View style={styles.welcomeGlow} />
      <View style={styles.welcomeTop}>
        <UniHubMark inverted />
        <Text style={styles.welcomeKicker}>YOUR CAMPUS, CONNECTED</Text>
      </View>
      <View style={styles.welcomeCenter}>
        <View style={styles.logoOrbit}>
          <View style={styles.logoOrbitInner}><UniHubMark inverted /></View>
        </View>
        <Text style={styles.welcomeTitle}>Learn. Connect.{`\n`}Achieve.</Text>
        <Text style={styles.welcomeText}>Everything you need for a better student journey, in one friendly space.</Text>
      </View>
      <Pressable style={styles.whiteButton} onPress={onNext}>
        <Text style={styles.whiteButtonText}>Get Started</Text>
        <Text style={styles.buttonArrow}>→</Text>
      </Pressable>
    </View>
  );
}

function DiscoverScreen({ onNext }: { onNext: () => void }) {
  return (
    <View style={styles.blueScreen}>
      <View style={styles.discoverHeader}>
        <UniHubMark inverted />
        <Text style={styles.skip} onPress={onNext}>Skip</Text>
      </View>
      <View style={styles.discoverArtwork}>
        <StudentAvatar />
      </View>
      <View style={styles.discoverCopy}>
        <Text style={styles.discoverTitle}>Study with{`\n`}confidence.</Text>
        <Text style={styles.discoverText}>Keep notes, assignments, schedules and support close at every step.</Text>
      </View>
      <View style={styles.onboardingFooter}>
        <View style={styles.dots}>
          <View style={[styles.dot, styles.dotActive]} /><View style={styles.dot} /><View style={styles.dot} />
        </View>
        <Pressable style={styles.whiteButton} onPress={onNext}>
          <Text style={styles.whiteButtonText}>Continue</Text>
          <Text style={styles.buttonArrow}>→</Text>
        </Pressable>
      </View>
    </View>
  );
}

export default function LoginScreen({ navigation }: any) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [page, setPage] = useState<number | null>(null);
  const { login, loading } = useAuth();

  useEffect(() => {
    AsyncStorage.getItem(ONBOARDING_KEY).then((complete) => setPage(complete ? 2 : 0));
  }, []);

  const openLogin = async () => {
    await AsyncStorage.setItem(ONBOARDING_KEY, "true");
    setPage(2);
  };

  const handleLogin = async () => {
    setError("");
    if (!email.trim() || !password) {
      setError("Enter your university email and password to continue.");
      return;
    }
    try {
      await login(email.trim(), password);
    } catch (err: any) {
      setError(err.message || "Unable to sign in. Please check your academic account.");
    }
  };

  if (page === null) return <View style={styles.loadingScreen}><ActivityIndicator color={BLUE} /></View>;
  if (page === 0) return <WelcomeScreen onNext={() => setPage(1)} />;
  if (page === 1) return <DiscoverScreen onNext={openLogin} />;

  return (
    <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : "height"} style={styles.loginScreen}>
      <ScrollView contentContainerStyle={styles.loginContent} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
        <View style={styles.loginBrand}><UniHubMark /><Text style={styles.secureLabel}>STUDENT PORTAL</Text></View>
        <View style={styles.loginArtwork}><StudentAvatar variant="secondary" /></View>
        <View style={styles.form}>
          <Text style={styles.loginTitle}>Welcome back</Text>
          <Text style={styles.loginSubtitle}>Sign in to continue your UniHub journey.</Text>
          {error ? <View style={styles.error}><Text style={styles.errorText}>{error}</Text></View> : null}
          <Text style={styles.label}>University email</Text>
          <TextInput style={styles.input} autoCapitalize="none" autoCorrect={false} keyboardType="email-address" value={email} onChangeText={setEmail} editable={!loading} placeholder="you@unimtech.edu" placeholderTextColor="#AAB2C1" accessibilityLabel="University email" />
          <Text style={styles.label}>Password</Text>
          <TextInput style={styles.input} secureTextEntry value={password} onChangeText={setPassword} editable={!loading} placeholder="Enter your password" placeholderTextColor="#AAB2C1" accessibilityLabel="Password" />
          <Pressable style={styles.forgot}><Text style={styles.forgotText}>Forgot password?</Text></Pressable>
          <Pressable style={[styles.loginButton, loading && styles.buttonDisabled]} onPress={handleLogin} disabled={loading}>
            {loading ? <ActivityIndicator color="#fff" /> : <Text style={styles.loginButtonText}>Sign In</Text>}
          </Pressable>
          <View style={styles.footer}><Text style={styles.footerText}>New to UniHub?</Text><Pressable onPress={() => navigation.navigate("Register")} disabled={loading}><Text style={styles.link}> Create an account</Text></Pressable></View>
          <Text style={styles.terms}>By continuing, you agree to UniHub&apos;s Terms of Service and Privacy Policy.</Text>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  loadingScreen: { alignItems: "center", backgroundColor: "#fff", flex: 1, justifyContent: "center" },
  blueScreen: { backgroundColor: BLUE, flex: 1, overflow: "hidden", padding: 28 },
  welcomeGlow: { backgroundColor: "#4775F0", borderRadius: 220, height: 440, opacity: 0.55, position: "absolute", right: -130, top: -100, width: 440 },
  welcomeTop: { alignItems: "flex-start", paddingTop: 24 },
  brandRow: { alignItems: "center", flexDirection: "row" },
  brandName: { color: BLUE, fontSize: 22, fontWeight: "800", letterSpacing: -0.5, marginLeft: 9 },
  brandNameInverted: { color: "#fff" },
  mark: { alignItems: "center", backgroundColor: "#E7EDFF", borderRadius: 10, height: 37, justifyContent: "center", overflow: "hidden", width: 37 },
  markInverted: { backgroundColor: "#fff" },
  markPage: { borderColor: BLUE, borderWidth: 1.5, height: 20, position: "absolute", top: 8, width: 12 },
  markPageBack: { left: 8, transform: [{ rotate: "-8deg" }] },
  markPageFront: { right: 8, transform: [{ rotate: "8deg" }] },
  markSpine: { backgroundColor: BLUE, height: 20, position: "absolute", width: 1.5 },
  welcomeKicker: { color: "#D8E2FF", fontSize: 10, fontWeight: "700", letterSpacing: 2, marginTop: 19 },
  welcomeCenter: { alignItems: "center", flex: 1, justifyContent: "center", marginTop: -25 },
  logoOrbit: { alignItems: "center", borderColor: "rgba(255,255,255,0.28)", borderRadius: 78, borderWidth: 1, height: 156, justifyContent: "center", width: 156 },
  logoOrbitInner: { alignItems: "center", backgroundColor: "rgba(255,255,255,0.14)", borderRadius: 58, height: 116, justifyContent: "center", width: 116 },
  welcomeTitle: { color: "#fff", fontSize: 38, fontWeight: "800", letterSpacing: -1, lineHeight: 43, marginTop: 28, textAlign: "center" },
  welcomeText: { color: "#DCE5FF", fontSize: 15, lineHeight: 23, marginTop: 16, maxWidth: 310, textAlign: "center" },
  whiteButton: { alignItems: "center", backgroundColor: "#fff", borderRadius: 11, flexDirection: "row", justifyContent: "center", minHeight: 53, paddingHorizontal: 19 },
  whiteButtonText: { color: BLUE, fontSize: 15, fontWeight: "800" },
  buttonArrow: { color: BLUE, fontSize: 20, marginLeft: 13 },
  discoverHeader: { alignItems: "center", flexDirection: "row", justifyContent: "space-between", paddingTop: 24 },
  skip: { color: "#D8E2FF", fontSize: 13, fontWeight: "700" },
  discoverArtwork: { flex: 1, justifyContent: "center", marginTop: 10 },
  discoverCopy: { marginBottom: 22 },
  discoverTitle: { color: "#fff", fontSize: 37, fontWeight: "800", lineHeight: 42 },
  discoverText: { color: "#DCE5FF", fontSize: 15, lineHeight: 23, marginTop: 12, maxWidth: 320 },
  onboardingFooter: { paddingBottom: 9 },
  dots: { flexDirection: "row", marginBottom: 16 },
  dot: { backgroundColor: "rgba(255,255,255,0.3)", borderRadius: 4, height: 7, marginRight: 7, width: 7 },
  dotActive: { backgroundColor: "#fff", width: 24 },
  loginScreen: { backgroundColor: "#F7F9FD", flex: 1 },
  loginContent: { flexGrow: 1, paddingBottom: 34 },
  loginBrand: { alignItems: "flex-start", flexDirection: "row", justifyContent: "space-between", paddingHorizontal: 25, paddingTop: 26 },
  secureLabel: { color: MUTED, fontSize: 9, fontWeight: "800", letterSpacing: 1.3, marginTop: 13 },
  loginArtwork: { alignSelf: "center", height: 180, marginTop: 2, width: 250 },
  form: { backgroundColor: "#fff", borderTopLeftRadius: 30, borderTopRightRadius: 30, paddingHorizontal: 27, paddingTop: 25 },
  loginTitle: { color: INK, fontSize: 29, fontWeight: "800", letterSpacing: -0.5 },
  loginSubtitle: { color: MUTED, fontSize: 14, marginTop: 6 },
  error: { backgroundColor: "#FFF1F0", borderColor: "#FFD6D2", borderRadius: 9, borderWidth: 1, marginTop: 15, padding: 10 },
  errorText: { color: "#B42318", fontSize: 12 },
  label: { color: INK, fontSize: 12, fontWeight: "700", marginBottom: 7, marginTop: 19 },
  input: { backgroundColor: "#F7F8FB", borderColor: "#E5E9F2", borderRadius: 9, borderWidth: 1, color: INK, fontSize: 15, height: 48, paddingHorizontal: 14 },
  forgot: { alignSelf: "flex-end", marginTop: 10 },
  forgotText: { color: BLUE, fontSize: 12, fontWeight: "700" },
  loginButton: { alignItems: "center", backgroundColor: BLUE, borderRadius: 10, justifyContent: "center", marginTop: 22, minHeight: 50 },
  buttonDisabled: { opacity: 0.65 },
  loginButtonText: { color: "#fff", fontSize: 15, fontWeight: "800" },
  footer: { alignItems: "center", flexDirection: "row", justifyContent: "center", marginTop: 19 },
  footerText: { color: MUTED, fontSize: 13 },
  link: { color: BLUE, fontSize: 13, fontWeight: "800" },
  terms: { color: "#9AA3B4", fontSize: 10, lineHeight: 15, marginTop: 23, textAlign: "center" },
  avatarScene: { alignSelf: "center", height: 300, position: "relative", width: 300 },
  sun: { backgroundColor: "#6D8DF2", borderRadius: 70, height: 140, opacity: 0.55, position: "absolute", right: 18, top: 22, width: 140 },
  sunSecondary: { backgroundColor: "#D9E3FF", height: 120, right: 78, top: 4, width: 120 },
  avatarShadow: { backgroundColor: "#1747CF", borderRadius: 70, bottom: 21, height: 28, left: 54, opacity: 0.45, position: "absolute", width: 195 },
  avatarShadowSecondary: { backgroundColor: "#BFCBE4", bottom: 12 },
  backpack: { backgroundColor: "#162A61", borderRadius: 28, bottom: 48, height: 142, left: 148, position: "absolute", transform: [{ rotate: "10deg" }], width: 75 },
  backpackSecondary: { backgroundColor: "#35518D" },
  avatarBody: { backgroundColor: "#F2A765", borderRadius: 45, bottom: 30, height: 147, left: 76, position: "absolute", width: 130 },
  avatarBodySecondary: { backgroundColor: "#7B8FE0" },
  avatarArm: { backgroundColor: "#F2A765", borderRadius: 19, bottom: 53, height: 92, left: 173, position: "absolute", transform: [{ rotate: "-35deg" }], width: 38 },
  avatarArmSecondary: { backgroundColor: "#7B8FE0" },
  avatarHand: { backgroundColor: "#D98B5D", borderRadius: 13, bottom: 106, height: 29, left: 213, position: "absolute", width: 26 },
  avatarHandSecondary: { backgroundColor: "#C88461" },
  avatarNeck: { backgroundColor: "#D98B5D", borderRadius: 12, height: 27, left: 126, position: "absolute", top: 110, width: 35 },
  avatarNeckSecondary: { backgroundColor: "#C88461" },
  avatarFace: { backgroundColor: "#D98B5D", borderRadius: 42, height: 94, left: 94, position: "absolute", top: 35, width: 83 },
  avatarFaceSecondary: { backgroundColor: "#C88461" },
  avatarHair: { backgroundColor: "#342B3B", borderRadius: 41, height: 43, left: -2, position: "absolute", top: -7, width: 87 },
  avatarHairSecondary: { backgroundColor: "#4A3028" },
  avatarEyeLeft: { backgroundColor: "#2A2631", borderRadius: 3, height: 5, left: 24, position: "absolute", top: 48, width: 5 },
  avatarEyeRight: { backgroundColor: "#2A2631", borderRadius: 3, height: 5, left: 55, position: "absolute", top: 48, width: 5 },
  avatarSmile: { borderBottomColor: "#773E45", borderBottomWidth: 2, borderRadius: 8, bottom: 18, height: 9, left: 33, position: "absolute", width: 18 },
  book: { backgroundColor: "#fff", borderRadius: 4, bottom: 41, height: 15, left: 45, position: "absolute", transform: [{ rotate: "-7deg" }], width: 155 },
  bookSecondary: { backgroundColor: "#DCE5FF", bottom: 24 },
  bookPage: { backgroundColor: "#263F8B", borderRadius: 4, bottom: 57, height: 14, left: 54, position: "absolute", transform: [{ rotate: "4deg" }], width: 139 },
  bookPageSecondary: { backgroundColor: "#6F84D4", bottom: 40 },
});
