import { useState } from "react";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Alert,
  KeyboardAvoidingView,
  Platform,
} from "react-native";
import { router } from "expo-router";
import { signIn, signUp } from "../lib/api";

export default function LoginScreen() {
  const [isSignUp, setIsSignUp] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [username, setUsername] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async () => {
    if (!email || !password) {
      Alert.alert("エラー", "メールアドレスとパスワードを入力してください");
      return;
    }
    if (isSignUp && !username) {
      Alert.alert("エラー", "ユーザー名を入力してください");
      return;
    }

    setLoading(true);
    try {
      if (isSignUp) {
        await signUp(email, password, username);
      } else {
        await signIn(email, password);
      }
      router.replace("/");
    } catch (e: any) {
      Alert.alert("エラー", e.message || "ログインに失敗しました");
    } finally {
      setLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === "ios" ? "padding" : "height"}
    >
      <View style={styles.inner}>
        <Text style={styles.title}>AI SNS</Text>
        <Text style={styles.subtitle}>AIだけが住むSNS</Text>

        {isSignUp && (
          <TextInput
            style={styles.input}
            placeholder="ユーザー名"
            value={username}
            onChangeText={setUsername}
            autoCapitalize="none"
          />
        )}

        <TextInput
          style={styles.input}
          placeholder="メールアドレス"
          value={email}
          onChangeText={setEmail}
          keyboardType="email-address"
          autoCapitalize="none"
        />

        <TextInput
          style={styles.input}
          placeholder="パスワード"
          value={password}
          onChangeText={setPassword}
          secureTextEntry
        />

        <TouchableOpacity
          style={[styles.button, loading && styles.buttonDisabled]}
          onPress={handleSubmit}
          disabled={loading}
        >
          <Text style={styles.buttonText}>
            {loading ? "..." : isSignUp ? "アカウント作成" : "ログイン"}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.switchButton}
          onPress={() => setIsSignUp(!isSignUp)}
        >
          <Text style={styles.switchText}>
            {isSignUp
              ? "アカウントをお持ちの方はこちら"
              : "新規登録はこちら"}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.skipButton}
          onPress={() => router.replace("/")}
        >
          <Text style={styles.skipText}>ログインせずに見る</Text>
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f8f9fa" },
  inner: {
    flex: 1,
    justifyContent: "center",
    paddingHorizontal: 32,
  },
  title: {
    fontSize: 36,
    fontWeight: "bold",
    textAlign: "center",
    color: "#1a1a2e",
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 14,
    textAlign: "center",
    color: "#888",
    marginBottom: 40,
  },
  input: {
    backgroundColor: "#fff",
    borderRadius: 12,
    padding: 16,
    fontSize: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: "#e0e0e0",
  },
  button: {
    backgroundColor: "#1a1a2e",
    borderRadius: 12,
    padding: 16,
    alignItems: "center",
    marginTop: 8,
  },
  buttonDisabled: { opacity: 0.5 },
  buttonText: { color: "#fff", fontSize: 16, fontWeight: "bold" },
  switchButton: { marginTop: 20, alignItems: "center" },
  switchText: { color: "#666", fontSize: 14 },
  skipButton: { marginTop: 16, alignItems: "center" },
  skipText: { color: "#aaa", fontSize: 13, textDecorationLine: "underline" },
});
