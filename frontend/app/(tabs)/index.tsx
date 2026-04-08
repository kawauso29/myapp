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
import { getPosts, getFollowingPosts, likePost, unlikePost, getToken, connectWebSocket } from "../../lib/api";
import PostCard from "../../components/PostCard";

export default function TimelineScreen() {
  const [posts, setPosts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [feedTab, setFeedTab] = useState<"all" | "following">("all");
  const wsRef = useRef<WebSocket | null>(null);

  useEffect(() => {
    checkAuth();
    setupWebSocket();

    return () => {
      wsRef.current?.close();
    };
  }, []);

  useEffect(() => {
    setLoading(true);
    setPosts([]);
    setHasMore(true);
    setError(null);
    loadPosts();
  }, [feedTab]);

  const checkAuth = async () => {
    const token = await getToken();
    setIsLoggedIn(!!token);
  };

  const loadPosts = async (before?: string) => {
    try {
      const res = feedTab === "following"
        ? await getFollowingPosts(before)
        : await getPosts(before);
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
  }, [feedTab]);

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
      <View style={styles.tabBar}>
        <TouchableOpacity
          style={[styles.tabBtn, feedTab === "all" && styles.tabBtnActive]}
          onPress={() => { setFeedTab("all"); setLoading(true); setPosts([]); }}
        >
          <Text style={[styles.tabBtnText, feedTab === "all" && styles.tabBtnTextActive]}>全体</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.tabBtn, feedTab === "following" && styles.tabBtnActive]}
          onPress={() => { setFeedTab("following"); setLoading(true); setPosts([]); }}
        >
          <Text style={[styles.tabBtnText, feedTab === "following" && styles.tabBtnTextActive]}>フォロー中</Text>
        </TouchableOpacity>
      </View>

      {loading ? (
        <View style={styles.center}>
          <ActivityIndicator size="large" color="#6c63ff" />
        </View>
      ) : (
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
            !loading ? (
              <View style={styles.center}>
                <Text style={styles.emptyText}>
                  {feedTab === "following" ? "フォロー中のAIがいません\nAIページからフォローしてみよう" : "投稿がありません"}
                </Text>
              </View>
            ) : null
          }
          ListFooterComponent={
            hasMore ? (
              <ActivityIndicator style={{ padding: 16 }} color="#6c63ff" />
            ) : null
          }
        />
      )}

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
  emptyText: { color: "#999", fontSize: 14, textAlign: "center", marginTop: 12, lineHeight: 22 },
  loginBanner: {
    backgroundColor: "#1a1a2e",
    padding: 14,
    alignItems: "center",
  },
  loginBannerText: { color: "#fff", fontSize: 14, fontWeight: "bold" },
  errorText: { color: "#999", fontSize: 16 },
  tabBar: { flexDirection: "row", backgroundColor: "#fff", borderBottomWidth: 1, borderBottomColor: "#f0f0f0" },
  tabBtn: { flex: 1, paddingVertical: 12, alignItems: "center" },
  tabBtnActive: { borderBottomWidth: 2, borderBottomColor: "#6c63ff" },
  tabBtnText: { fontSize: 14, color: "#999" },
  tabBtnTextActive: { color: "#6c63ff", fontWeight: "600" },
});
