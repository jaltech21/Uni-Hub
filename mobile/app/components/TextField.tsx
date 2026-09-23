/**
 * TextField — labeled input with optional secure toggle, error, and hint.
 */
import React, { useState } from "react";
import {
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  TextInputProps,
  View,
} from "react-native";
import { palette, radius } from "./tokens";

interface TextFieldProps extends TextInputProps {
  label: string;
  error?: string | null;
  help?: string;
}

export default function TextField({ label, error, help, secureTextEntry, ...rest }: TextFieldProps) {
  const [secure, setSecure] = useState(Boolean(secureTextEntry));
  return (
    <View style={styles.wrap}>
      <Text style={styles.label}>{label}</Text>
      <View style={styles.fieldRow}>
        <TextInput
          style={[styles.input, error ? styles.inputError : null]}
          placeholderTextColor="#AAB2C1"
          secureTextEntry={secure}
          {...rest}
        />
        {secureTextEntry ? (
          <Pressable
            style={styles.toggle}
            onPress={() => setSecure((v) => !v)}
            accessibilityLabel={secure ? "Show password" : "Hide password"}
          >
            <Text style={styles.toggleText}>{secure ? "👁" : "🙈"}</Text>
          </Pressable>
        ) : null}
      </View>
      {error ? <Text style={styles.error}>{error}</Text> : null}
      {!error && help ? <Text style={styles.help}>{help}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { marginBottom: 16 },
  label: {
    color: palette.ink,
    fontSize: 12,
    fontWeight: "700",
    marginBottom: 7,
  },
  fieldRow: { position: "relative" },
  input: {
    backgroundColor: "#F7F8FB",
    borderColor: "#E5E9F2",
    borderRadius: radius.sm,
    borderWidth: 1,
    color: palette.ink,
    fontSize: 15,
    height: 48,
    paddingHorizontal: 14,
  },
  inputError: { borderColor: palette.danger, borderWidth: 1.5 },
  toggle: {
    alignItems: "center",
    height: 48,
    justifyContent: "center",
    position: "absolute",
    right: 6,
    top: 0,
    width: 42,
  },
  toggleText: { fontSize: 18 },
  error: { color: palette.danger, fontSize: 12, marginTop: 5 },
  help: { color: palette.mutedLight, fontSize: 12, marginTop: 5 },
});