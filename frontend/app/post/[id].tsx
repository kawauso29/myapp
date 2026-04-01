import { useEffect, useState } from "react";
import {
  View,
  FlatList,
  StyleSheet,
  ActivityIndicator,
  Text,
} from "react-native";
import { useLocalSearchParams } from "expo-router";
import { getPost } from "../../lib/api";
import PostCard from "../../components/PostCard";

export default function PostDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const [post, setPost] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadPost();
  }, [id]);

  const loadPost = async () => {
    try {
      const res = await getPost(Number(id));
      setPost(res.data);
    } catch (e) {
      console.warn("Failed to load post:", e);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#6c63ff" />
      </View>
    );
  }

  if (!post) {
    return (
      <View style={styles.center}>
        <Text style={styles.errorText}>投稿が見つかりませんでした</Text>
      </View>
    );
  }

  const replies = post.replies || [];

  return (
    <FlatList
      style={styles.container}
      data={replies}
      keyExtractor={(item) => String(item.id)}
      ListHeaderComponent={
        <View>
          <PostCard post={post} />
          {replies.length > 0 && (
            <View style={styles.repliesHeader}>
              <Text style={styles.repliesTitle}>
                リプライ ({replies.length})
              </Text>
            </View>
          )}
        </View>
      }
      renderItem={({ item }) => (
        <View style={styles.replyWrapper}>
          <View style={styles.replyLine} />
          <PostCard post={item} />
        </View>
      )}
      ListEmptyComponent={
        <View style={styles.noReplies}>
          <Text style={styles.noRepliesText}>まだリプライはありません</Text>
        </View>
      }
    />
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f8f9fa" },
  center: { flex: 1, justifyContent: "center", alignItems: "center" },
  errorText: { color: "#999", fontSize: 16 },
  repliesHeader: { padding: 16, backgroundColor: "#f8f9fa" },
  repliesTitle: { fontSize: 14, fontWeight: "bold", color: "#666" },
  replyWrapper: { flexDirection: "row" },
  replyLine: {
    width: 2, backgroundColor: "#e0e0e0", marginLeft: 36,
  },
  noReplies: { padding: 32, alignItems: "center" },
  noRepliesText: { color: "#ccc", fontSize: 14 },
});
