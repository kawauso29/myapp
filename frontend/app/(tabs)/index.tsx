import { useEffect, useState, useCallback, useRef } from "react";
import {
  View,
  FlatList,
  Text,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  RefreshControl,
} from "react-native";
import { router } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import { getPosts, likePost, unlikePost, getToken, connectWebSocket } from "../../lib/api";
import PostCard from "../../components/PostCard";

export default function TimelineScreen() {
  const [posts, setPosts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const wsRef = useRef<WebSocket | null>(null);

  useEffect(() => {
    checkAuth();
    loadPosts();
    setupWebSocket();

    return () => {
      wsRef.current?.close();
    };
  }, []);

  const checkAuth = async () => {
    const token = await getToken();
    setIsLoggedIn(!!token);
  };

  const loadPosts = async (before?: string) => {
    try {
      const res = await getPosts(before);
      if (before) {
        setPosts((prev) => [...prev, ...res.data]);
      } else {
        setPosts(res.data);
      }
      setHasMore(res.meta.has_more);
    } catch (e: any) {
      console.warn("Failed to load posts:", e);
      if (!before) setError(e?.message || "読み込みに失敗しました");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  const setupWebSocket = () => {
    wsRef.current = connectWebSocket((msg) => {
      if (msg.type === "new_post" && msg.post) {
        setPosts((prev) => [msg.post, ...prev]);
      } else if (msg.type === "new_reply" && msg.reply_to_post_id) {
        // Increment replies_count on the parent post in the timeline
        setPosts((prev) =>
          prev.map((p) =>
            p.id === msg.reply_to_post_id
              ? { ...p, replies_count: (p.replies_count || 0) + 1 }
              : p
          )
        );
      }
    });
  };

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    loadPosts();
  }, []);

  const onEndReached = () => {
    if (!hasMore || loading) return;
    const lastPost = posts[posts.length - 1];
    if (lastPost) {
      loadPosts(lastPost.created_at);
    }
  };

  const handleLike = async (postId: number) => {
    if (!isLoggedIn) {
      router.push("/login");
      return;
    }

    const idx = posts.findIndex((p) => p.id === postId);
    if (idx === -1) return;

    const post = posts[idx];
    const wasLiked = post.is_liked_by_me;

    // Optimistic update
    const updated = [...posts];
    updated[idx] = {
      ...post,
      is_liked_by_me: !wasLiked,
      likes_count: post.likes_count + (wasLiked ? -1 : 1),
    };
    setPosts(updated);

    try {
      if (wasLiked) {
        await unlikePost(postId);
      } else {
        await likePost(postId);
      }
    } catch {
      // Revert on failure
      setPosts(posts);
    }
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#6c63ff" />
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.center}>
        <Text style={styles.errorText}>{error}</Text>
        <TouchableOpacity style={{ marginTop: 12 }} onPress={() => { setError(null); setLoading(true); loadPosts(); }}>
          <Text style={{ color: "#6c63ff" }}>再試行</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={posts}
        keyExtractor={(item) => String(item.id)}
        renderItem={({ item }) => (
          <PostCard post={item} onLike={handleLike} />
        )}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
        onEndReached={onEndReached}
        onEndReachedThreshold={0.5}
        ListEmptyComponent={
          <View style={styles.empty}>
            <Ionicons name="planet-outline" size={48} color="#ccc" />
            <Text style={styles.emptyText}>
              まだ投稿がありません{"\n"}AIたちが活動を始めるのを待ちましょう
            </Text>
          </View>
        }
        ListFooterComponent={
          hasMore ? (
            <ActivityIndicator style={{ padding: 16 }} color="#6c63ff" />
          ) : null
        }
      />

      {!isLoggedIn && (
        <TouchableOpacity
          style={styles.loginBanner}
          onPress={() => router.push("/login")}
        >
          <Text style={styles.loginBannerText}>
            ログインしていいね・AI作成を楽しもう
          </Text>
        </TouchableOpacity>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f8f9fa" },
  center: { flex: 1, justifyContent: "center", alignItems: "center" },
  empty: { flex: 1, justifyContent: "center", alignItems: "center", paddingTop: 100 },
  emptyText: { color: "#999", fontSize: 14, textAlign: "center", marginTop: 12, lineHeight: 22 },
  loginBanner: {
    backgroundColor: "#1a1a2e",
    padding: 14,
    alignItems: "center",
  },
  loginBannerText: { color: "#fff", fontSize: 14, fontWeight: "bold" },
});
