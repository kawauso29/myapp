import { View, Text, TouchableOpacity, StyleSheet } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { router } from "expo-router";

type Props = {
  post: any;
  onLike?: (postId: number) => void;
};

export default function PostCard({ post, onLike }: Props) {
  const aiUser = post.ai_user;
  const timeAgo = formatTimeAgo(post.created_at);

  return (
    <View style={styles.card}>
      <TouchableOpacity
        style={styles.header}
        onPress={() => router.push(`/ai/${aiUser.id}`)}
      >
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>
            {aiUser.display_name?.[0] || "?"}
          </Text>
        </View>
        <View style={styles.headerInfo}>
          <Text style={styles.displayName}>{aiUser.display_name}</Text>
          <Text style={styles.meta}>
            @{aiUser.username} · {timeAgo}
          </Text>
        </View>
        {aiUser.is_drinking && (
          <Text style={styles.drinkingBadge}>🍺</Text>
        )}
      </TouchableOpacity>

      <TouchableOpacity onPress={() => router.push(`/post/${post.id}`)}>
        <Text style={styles.content}>{post.content}</Text>
      </TouchableOpacity>

      {post.tags?.length > 0 && (
        <View style={styles.tags}>
          {post.tags.slice(0, 3).map((tag: string, i: number) => (
            <Text key={i} style={styles.tag}>
              #{tag}
            </Text>
          ))}
        </View>
      )}

      <View style={styles.actions}>
        <TouchableOpacity
          style={styles.actionButton}
          onPress={() => onLike?.(post.id)}
        >
          <Ionicons
            name={post.is_liked_by_me ? "heart" : "heart-outline"}
            size={18}
            color={post.is_liked_by_me ? "#e74c3c" : "#888"}
          />
          <Text style={styles.actionCount}>{post.likes_count}</Text>
        </TouchableOpacity>

        <View style={styles.actionButton}>
          <Ionicons name="chatbubble-outline" size={18} color="#888" />
          <Text style={styles.actionCount}>{post.replies_count}</Text>
        </View>

        <View style={styles.moodBadge}>
          <Text style={styles.moodText}>
            {moodEmoji(post.mood_expressed)}
          </Text>
        </View>
      </View>
    </View>
  );
}

function moodEmoji(mood: string): string {
  switch (mood) {
    case "positive": return "😊";
    case "negative": return "😔";
    default: return "😐";
  }
}

function formatTimeAgo(dateStr: string): string {
  const now = Date.now();
  const then = new Date(dateStr).getTime();
  const diff = Math.floor((now - then) / 1000);

  if (diff < 60) return `${diff}秒前`;
  if (diff < 3600) return `${Math.floor(diff / 60)}分前`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}時間前`;
  return `${Math.floor(diff / 86400)}日前`;
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: "#fff",
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: "#f0f0f0",
  },
  header: { flexDirection: "row", alignItems: "center", marginBottom: 10 },
  avatar: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: "#e8e8f0",
    justifyContent: "center",
    alignItems: "center",
    marginRight: 10,
  },
  avatarText: { fontSize: 18, fontWeight: "bold", color: "#555" },
  headerInfo: { flex: 1 },
  displayName: { fontSize: 15, fontWeight: "bold", color: "#1a1a2e" },
  meta: { fontSize: 12, color: "#999", marginTop: 1 },
  drinkingBadge: { fontSize: 18 },
  content: { fontSize: 15, lineHeight: 22, color: "#333", marginBottom: 8 },
  tags: { flexDirection: "row", flexWrap: "wrap", marginBottom: 8 },
  tag: {
    fontSize: 12,
    color: "#6c63ff",
    marginRight: 8,
    backgroundColor: "#f0effe",
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 10,
  },
  actions: { flexDirection: "row", alignItems: "center" },
  actionButton: { flexDirection: "row", alignItems: "center", marginRight: 20 },
  actionCount: { fontSize: 13, color: "#888", marginLeft: 4 },
  moodBadge: { marginLeft: "auto" },
  moodText: { fontSize: 16 },
});
