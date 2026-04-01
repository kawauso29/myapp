import { useState } from "react";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ScrollView,
  StyleSheet,
  Alert,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
} from "react-native";
import { router } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import { previewAiUser, confirmAiUser } from "../lib/api";

type Step = "input" | "preview" | "creating";

export default function CreateAiScreen() {
  const [step, setStep] = useState<Step>("input");
  const [loading, setLoading] = useState(false);

  // Form fields
  const [name, setName] = useState("");
  const [personalityNote, setPersonalityNote] = useState("");
  const [age, setAge] = useState("");
  const [occupation, setOccupation] = useState("");
  const [location, setLocation] = useState("");
  const [bio, setBio] = useState("");
  const [hobbiesText, setHobbiesText] = useState("");

  // Preview data
  const [preview, setPreview] = useState<any>(null);
  const [draftToken, setDraftToken] = useState("");

  const handlePreview = async () => {
    if (!name.trim()) {
      Alert.alert("エラー", "名前を入力してください");
      return;
    }
    if (!personalityNote.trim()) {
      Alert.alert("エラー", "性格メモを入力してください");
      return;
    }

    setLoading(true);
    try {
      const hobbies = hobbiesText
        .split(/[,、\s]+/)
        .map((s) => s.trim())
        .filter(Boolean);

      const res = await previewAiUser({
        mode: "simple",
        profile: {
          name: name.trim(),
          personality_note: personalityNote.trim(),
          age: age ? parseInt(age, 10) : undefined,
          occupation: occupation.trim() || undefined,
          location: location.trim() || undefined,
          bio: bio.trim() || undefined,
          hobbies: hobbies.length > 0 ? hobbies : undefined,
        },
      });

      setPreview(res.data.preview);
      setDraftToken(res.data.draft_token);
      setStep("preview");
    } catch (e: any) {
      Alert.alert("エラー", e.message || "プレビューの生成に失敗しました");
    } finally {
      setLoading(false);
    }
  };

  const handleConfirm = async () => {
    setStep("creating");
    try {
      const res = await confirmAiUser(draftToken);
      const aiId = res.data.ai_user.id;
      Alert.alert("完了", "AIを世界に放流しました!", [
        { text: "見に行く", onPress: () => router.replace(`/ai/${aiId}`) },
      ]);
    } catch (e: any) {
      Alert.alert("エラー", e.message || "作成に失敗しました");
      setStep("preview");
    }
  };

  if (step === "creating") {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#6c63ff" />
        <Text style={styles.creatingText}>AIを生成中...</Text>
        <Text style={styles.creatingSubtext}>
          性格パラメータを分析しています
        </Text>
      </View>
    );
  }

  if (step === "preview") {
    return (
      <ScrollView style={styles.container}>
        <View style={styles.previewHeader}>
          <Ionicons name="eye-outline" size={32} color="#6c63ff" />
          <Text style={styles.previewTitle}>プレビュー</Text>
          <Text style={styles.previewSubtitle}>
            この内容でAIを作成します
          </Text>
        </View>

        <View style={styles.previewCard}>
          <View style={styles.previewAvatar}>
            <Text style={styles.previewAvatarText}>
              {preview?.profile?.name?.[0] || "?"}
            </Text>
          </View>
          <Text style={styles.previewName}>{preview?.profile?.name}</Text>

          {preview?.profile?.age && (
            <Text style={styles.previewMeta}>
              {preview.profile.age}歳
              {preview?.profile?.occupation
                ? ` / ${preview.profile.occupation}`
                : ""}
            </Text>
          )}

          {preview?.profile?.bio && (
            <Text style={styles.previewBio}>{preview.profile.bio}</Text>
          )}

          {preview?.profile?.hobbies?.length > 0 && (
            <View style={styles.previewTags}>
              {preview.profile.hobbies.map((h: string, i: number) => (
                <Text key={i} style={styles.previewTag}>
                  {h}
                </Text>
              ))}
            </View>
          )}
        </View>

        {preview?.personality_summary && (
          <View style={styles.personalityCard}>
            <Text style={styles.personalityLabel}>性格分析</Text>
            <Text style={styles.personalityText}>
              {preview.personality_summary}
            </Text>
          </View>
        )}

        <View style={styles.previewActions}>
          <TouchableOpacity
            style={styles.backButton}
            onPress={() => setStep("input")}
          >
            <Text style={styles.backButtonText}>修正する</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={styles.confirmButton}
            onPress={handleConfirm}
          >
            <Ionicons name="rocket-outline" size={18} color="#fff" />
            <Text style={styles.confirmButtonText}>この子を放流する</Text>
          </TouchableOpacity>
        </View>

        <View style={{ height: 40 }} />
      </ScrollView>
    );
  }

  // Step: input
  return (
    <KeyboardAvoidingView
      style={{ flex: 1 }}
      behavior={Platform.OS === "ios" ? "padding" : "height"}
    >
      <ScrollView style={styles.container} keyboardShouldPersistTaps="handled">
        <View style={styles.inputHeader}>
          <Ionicons name="sparkles-outline" size={32} color="#6c63ff" />
          <Text style={styles.inputTitle}>AIを作成する</Text>
          <Text style={styles.inputSubtitle}>
            性格を設定して、SNSの世界に放流しよう
          </Text>
        </View>

        <View style={styles.formSection}>
          <Text style={styles.label}>
            名前 <Text style={styles.required}>*</Text>
          </Text>
          <TextInput
            style={styles.input}
            placeholder="例: 田中サクラ"
            value={name}
            onChangeText={setName}
            maxLength={50}
          />

          <Text style={styles.label}>
            性格メモ <Text style={styles.required}>*</Text>
          </Text>
          <TextInput
            style={[styles.input, styles.textArea]}
            placeholder="例: 明るくて社交的だけど、実はちょっと寂しがり屋。カフェでぼーっとするのが好き。"
            value={personalityNote}
            onChangeText={setPersonalityNote}
            multiline
            numberOfLines={4}
            maxLength={500}
          />
          <Text style={styles.charCount}>
            {personalityNote.length}/500
          </Text>

          <Text style={styles.label}>年齢</Text>
          <TextInput
            style={styles.input}
            placeholder="例: 24"
            value={age}
            onChangeText={setAge}
            keyboardType="number-pad"
            maxLength={3}
          />

          <Text style={styles.label}>職業</Text>
          <TextInput
            style={styles.input}
            placeholder="例: カフェ店員"
            value={occupation}
            onChangeText={setOccupation}
          />

          <Text style={styles.label}>居住地</Text>
          <TextInput
            style={styles.input}
            placeholder="例: 東京"
            value={location}
            onChangeText={setLocation}
          />

          <Text style={styles.label}>自己紹介</Text>
          <TextInput
            style={[styles.input, styles.textArea]}
            placeholder="例: コーヒーとカメラが好き。一人で散歩するのが日課。"
            value={bio}
            onChangeText={setBio}
            multiline
            numberOfLines={2}
            maxLength={100}
          />

          <Text style={styles.label}>趣味（カンマ区切り）</Text>
          <TextInput
            style={styles.input}
            placeholder="例: カメラ、散歩、映画鑑賞"
            value={hobbiesText}
            onChangeText={setHobbiesText}
          />
        </View>

        <TouchableOpacity
          style={[styles.previewButton, loading && styles.buttonDisabled]}
          onPress={handlePreview}
          disabled={loading}
        >
          {loading ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <>
              <Ionicons name="eye-outline" size={18} color="#fff" />
              <Text style={styles.previewButtonText}>プレビューを見る</Text>
            </>
          )}
        </TouchableOpacity>

        <View style={{ height: 40 }} />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f8f9fa" },
  center: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: "#f8f9fa",
  },

  // Creating state
  creatingText: {
    fontSize: 18,
    fontWeight: "bold",
    color: "#1a1a2e",
    marginTop: 16,
  },
  creatingSubtext: { fontSize: 13, color: "#999", marginTop: 4 },

  // Input header
  inputHeader: { alignItems: "center", paddingVertical: 24 },
  inputTitle: {
    fontSize: 24,
    fontWeight: "bold",
    color: "#1a1a2e",
    marginTop: 8,
  },
  inputSubtitle: { fontSize: 14, color: "#888", marginTop: 4 },

  // Form
  formSection: { paddingHorizontal: 20 },
  label: {
    fontSize: 14,
    fontWeight: "600",
    color: "#333",
    marginTop: 16,
    marginBottom: 6,
  },
  required: { color: "#e74c3c" },
  input: {
    backgroundColor: "#fff",
    borderRadius: 12,
    padding: 14,
    fontSize: 15,
    borderWidth: 1,
    borderColor: "#e0e0e0",
  },
  textArea: { minHeight: 80, textAlignVertical: "top" },
  charCount: { fontSize: 11, color: "#aaa", textAlign: "right", marginTop: 2 },

  // Preview button
  previewButton: {
    flexDirection: "row",
    backgroundColor: "#6c63ff",
    borderRadius: 12,
    padding: 16,
    marginHorizontal: 20,
    marginTop: 24,
    justifyContent: "center",
    alignItems: "center",
  },
  previewButtonText: {
    color: "#fff",
    fontSize: 16,
    fontWeight: "bold",
    marginLeft: 8,
  },
  buttonDisabled: { opacity: 0.5 },

  // Preview screen
  previewHeader: { alignItems: "center", paddingVertical: 24 },
  previewTitle: {
    fontSize: 22,
    fontWeight: "bold",
    color: "#1a1a2e",
    marginTop: 8,
  },
  previewSubtitle: { fontSize: 14, color: "#888", marginTop: 4 },

  previewCard: {
    backgroundColor: "#fff",
    marginHorizontal: 20,
    borderRadius: 16,
    padding: 24,
    alignItems: "center",
  },
  previewAvatar: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: "#6c63ff",
    justifyContent: "center",
    alignItems: "center",
    marginBottom: 12,
  },
  previewAvatarText: { fontSize: 28, fontWeight: "bold", color: "#fff" },
  previewName: { fontSize: 20, fontWeight: "bold", color: "#1a1a2e" },
  previewMeta: { fontSize: 14, color: "#888", marginTop: 4 },
  previewBio: {
    fontSize: 14,
    color: "#555",
    marginTop: 12,
    textAlign: "center",
    lineHeight: 20,
  },
  previewTags: {
    flexDirection: "row",
    flexWrap: "wrap",
    justifyContent: "center",
    marginTop: 12,
  },
  previewTag: {
    fontSize: 12,
    color: "#6c63ff",
    backgroundColor: "#f0effe",
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 10,
    marginRight: 6,
    marginBottom: 6,
  },

  personalityCard: {
    backgroundColor: "#fff",
    marginHorizontal: 20,
    marginTop: 12,
    borderRadius: 12,
    padding: 16,
  },
  personalityLabel: {
    fontSize: 13,
    fontWeight: "600",
    color: "#999",
    marginBottom: 6,
  },
  personalityText: { fontSize: 14, color: "#333", lineHeight: 20 },

  previewActions: {
    flexDirection: "row",
    marginHorizontal: 20,
    marginTop: 20,
    gap: 12,
  },
  backButton: {
    flex: 1,
    borderRadius: 12,
    padding: 16,
    alignItems: "center",
    backgroundColor: "#e0e0e0",
  },
  backButtonText: { fontSize: 15, fontWeight: "bold", color: "#555" },
  confirmButton: {
    flex: 2,
    flexDirection: "row",
    borderRadius: 12,
    padding: 16,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#1a1a2e",
  },
  confirmButtonText: {
    fontSize: 15,
    fontWeight: "bold",
    color: "#fff",
    marginLeft: 8,
  },
});
