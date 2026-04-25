import { useEffect, useState, useRef } from "react";
import {
  View,
  FlatList,
  StyleSheet,
  ActivityIndicator,
  Text,
  Animated,
} from "react-native";
import { useLocalSearchParams, router } from "expo-router";
import { getPost, likePost, unlikePost, getToken, connectThreadWebSocket } from "../../lib/api";
import PostCard from "../../components/PostCard";

export default function PostDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const [post, setPost] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [isLive, setIsLive] = useState(false);
  const [newReplyCount, setNewReplyCount] = useState(0);
  const wsRef = useRef<WebSocket | null>(null);
  const livePulse = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    loadPost();
    getToken().then(t => setIsLoggedIn(!!t));

    return () => {
      wsRef.current?.close();
    };
  }, [id]);

  useEffect(() => {
    if (!post?.id) return;

    const postId = Number(id);
    wsRef.current?.close();
    wsRef.current = connectThreadWebSocket(postId, (msg) => {
      if (msg.type === "new_reply" && msg.reply_to_post_id === postId && msg.post) {
        setPost((prev: any) => {
          if (!prev) return prev;
          const alreadyExists = (prev.replies || []).some((r: any) => r.id === msg.post.id);
          if (alreadyExists) return prev;
          setNewReplyCount(c => c + 1);
          return {
            ...prev,
            replies_count: (prev.replies_count || 0) + 1,
            replies: [...(prev.replies || []), msg.post],
          };
        });
      }
    });

    if (wsRef.current) {
      wsRef.current.onopen = () => {
        setIsLive(true);
        startPulse();
      };
      wsRef.current.onclose = () => setIsLive(false);
    }
  }, [id]);

  const startPulse = () => {
    Animated.loop(
      Animated.sequence([
        Animated.timing(livePulse, { toValue: 0.4, duration: 800, useNativeDriver: true }),
        Animated.timing(livePulse, { toValue: 1, duration: 800, useNativeDriver: true }),
      ])
    ).start();
  };

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

  const handleLike = async (postId: number) => {
    if (!isLoggedIn) {
      router.push("/login");
      return;
    }
    if (!post) return;

    // The liked post could be the main post or a reply
    if (post.id === postId) {
      const wasLiked = post.is_liked_by_me;
      setPost({
        ...post,
        is_liked_by_me: !wasLiked,
        likes_count: post.likes_count + (wasLiked ? -1 : 1),
      });
      try {
        if (wasLiked) await unlikePost(postId);
        else await likePost(postId);
      } catch {
        setPost(post); // revert
      }
    } else {
      // It's a reply - find it in post.replies
      const replies = post.replies || [];
      const idx = replies.findIndex((r: any) => r.id === postId);
      if (idx === -1) return;
      const reply = replies[idx];
      const wasLiked = reply.is_liked_by_me;
      const updatedReplies = [...replies];
      updatedReplies[idx] = {
        ...reply,
        is_liked_by_me: !wasLiked,
        likes_count: reply.likes_count + (wasLiked ? -1 : 1),
      };
      setPost({ ...post, replies: updatedReplies });
      try {
        if (wasLiked) await unlikePost(postId);
        else await likePost(postId);
      } catch {
        setPost(post); // revert
      }
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
      onEndReached={() => setNewReplyCount(0)}
      onEndReachedThreshold={0.1}
      ListHeaderComponent={
        <View>
          <PostCard post={post} onLike={handleLike} />
          <View style={styles.threadHeader}>
            <View style={styles.threadHeaderLeft}>
              <Text style={styles.repliesTitle}>
                会話スレッド ({replies.length})
              </Text>
              {newReplyCount > 0 && (
                <View style={styles.newBadge}>
                  <Text style={styles.newBadgeText}>+{newReplyCount} 新着</Text>
                </View>
              )}
            </View>
            {isLive && (
              <View style={styles.liveIndicator}>
                <Animated.View style={[styles.liveDot, { opacity: livePulse }]} />
                <Text style={styles.liveText}>ライブ</Text>
              </View>
            )}
          </View>
        </View>
      }
      renderItem={({ item, index }) => (
        <View style={styles.replyWrapper}>
          <View style={styles.threadLine} />
          <View style={[styles.replyCard, index === replies.length - 1 && styles.replyCardLast]}>
            <PostCard post={item} onLike={handleLike} />
          </View>
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
  threadHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    padding: 16,
    paddingBottom: 8,
    backgroundColor: "#f8f9fa",
    borderBottomWidth: 1,
    borderBottomColor: "#e8e8f0",
  },
  threadHeaderLeft: { flexDirection: "row", alignItems: "center", gap: 8 },
  repliesTitle: { fontSize: 14, fontWeight: "bold", color: "#444" },
  newBadge: {
    backgroundColor: "#6c63ff",
    borderRadius: 10,
    paddingHorizontal: 8,
    paddingVertical: 2,
  },
  newBadgeText: { color: "#fff", fontSize: 11, fontWeight: "bold" },
  liveIndicator: { flexDirection: "row", alignItems: "center", gap: 5 },
  liveDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: "#e74c3c",
  },
  liveText: { fontSize: 12, color: "#e74c3c", fontWeight: "600" },
  replyWrapper: { flexDirection: "row" },
  threadLine: {
    width: 2,
    backgroundColor: "#ddd",
    marginLeft: 36,
    marginTop: 0,
  },
  replyCard: { flex: 1 },
  replyCardLast: {},
  noReplies: { padding: 32, alignItems: "center" },
  noRepliesText: { color: "#ccc", fontSize: 14 },
});

