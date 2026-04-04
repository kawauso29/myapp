import { useEffect, useState } from "react";
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  ActivityIndicator,
  TouchableOpacity,
} from "react-native";
import { useLocalSearchParams, router } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import { getAiUser, getAiUserPosts, toggleFavorite, getToken, likePost, unlikePost } from "../../lib/api";
import { PostCard } from "../../components/PostCard";

export default function AiDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const [ai, setAi] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [posts, setPosts] = useState<any[]>([]);
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [isFavorited, setIsFavorited] = useState(false);
  const [postsLoading, setPostsLoading] = useState(false);
  const [postsCursor, setPostsCursor] = useState<string | undefined>(undefined);
  const [postsHasMore, setPostsHasMore] = useState(true);

  useEffect(() => {
    loadAiUser();
    loadPosts();
    getToken().then(t => setIsLoggedIn(!!t));
  }, [id]);

  const loadAiUser = async () => {
    try {
      const res = await getAiUser(Number(id));
      setAi(res.data);
      setIsFavorited(res.data.is_favorited || false);
    } catch (e) {
      console.warn("Failed to load AI user:", e);
    } finally {
      setLoading(false);
    }
  };

  const loadPosts = async (cursor?: string) => {
    if (postsLoading) return;
    setPostsLoading(true);
    try {
      const res = await getAiUserPosts(Number(id), cursor);
      setPosts((prev) => (cursor ? [...prev, ...res.data] : res.data));
      setPostsCursor(res.meta.next_cursor ?? undefined);
      setPostsHasMore(res.meta.has_more);
    } catch (e) {
      console.warn("Failed to load AI user posts:", e);
    } finally {
      setPostsLoading(false);
    }
  };

  const loadMorePosts = () => {
    if (postsHasMore && postsCursor) {
      loadPosts(postsCursor);
    }
  };

  const handleToggleFavorite = async () => {
    if (!isLoggedIn) { router.push("/login"); return; }
    const next = !isFavorited;
    setIsFavorited(next); // optimistic
    try {
      await toggleFavorite(ai.id);
    } catch {
      setIsFavorited(!next); // revert on error
    }
  };

  const handleLike = async (postId: number) => {
    if (!isLoggedIn) { router.push("/login"); return; }
    const idx = posts.findIndex(p => p.id === postId);
    if (idx === -1) return;
    const post = posts[idx];
    const wasLiked = post.is_liked_by_me;
    const updated = [...posts];
    updated[idx] = { ...post, is_liked_by_me: !wasLiked, likes_count: post.likes_count + (wasLiked ? -1 : 1) };
    setPosts(updated);
    try {
      if (wasLiked) await unlikePost(postId);
      else await likePost(postId);
    } catch {
      setPosts(posts); // revert
    }
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#6c63ff" />
      </View>
    );
  }

  if (!ai) {
    return (
      <View style={styles.center}>
        <Text style={styles.errorText}>AIが見つかりませんでした</Text>
      </View>
    );
  }

  const profile = ai.profile;
  const state = ai.today_state;

  return (
    <ScrollView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <View style={styles.avatarLarge}>
          <Text style={styles.avatarText}>{ai.display_name?.[0] || "?"}</Text>
        </View>
        <Text style={styles.displayName}>{ai.display_name}</Text>
        <Text style={styles.username}>@{ai.username}</Text>
        {profile?.bio ? (
          <Text style={styles.bio}>{profile.bio}</Text>
        ) : null}
        {isLoggedIn && (
          <TouchableOpacity style={styles.favoriteButton} onPress={handleToggleFavorite}>
            <Ionicons
              name={isFavorited ? "star" : "star-outline"}
              size={24}
              color={isFavorited ? "#f0c040" : "#888"}
            />
            <Text style={styles.favoriteButtonText}>
              {isFavorited ? "お気に入り済み" : "お気に入り"}
            </Text>
          </TouchableOpacity>
        )}
      </View>

      {/* Stats */}
      <View style={styles.stats}>
        <StatItem label="投稿" value={ai.posts_count} />
        <StatItem label="フォロワー" value={ai.followers_count} />
        <StatItem label="フォロー" value={ai.following_count} />
        <StatItem label="いいね" value={ai.total_likes} />
      </View>

      {/* Profile Details */}
      {profile && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>プロフィール</Text>
          <InfoRow label="年齢" value={`${profile.age}歳`} />
          <InfoRow label="職業" value={profile.occupation} />
          <InfoRow label="居住地" value={profile.location} />
          <InfoRow label="ライフステージ" value={profile.life_stage} />
          {profile.hobbies?.length > 0 && (
            <InfoRow label="趣味" value={profile.hobbies.join("、")} />
          )}
          {profile.catchphrase && (
            <InfoRow label="口癖" value={`「${profile.catchphrase}」`} />
          )}
        </View>
      )}

      {/* Today's State */}
      {state && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>今日の状態</Text>
          <InfoRow label="体調" value={state.physical} />
          <InfoRow label="気分" value={state.mood} />
          <InfoRow label="忙しさ" value={state.busyness} />
          <InfoRow label="気まぐれ" value={state.daily_whim} />
          <InfoRow label="投稿意欲" value={`${state.post_motivation}/100`} />
          {state.is_drinking && (
            <InfoRow label="飲酒" value={`レベル ${state.drinking_level}/3 🍺`} />
          )}
        </View>
      )}

      {/* Life Events */}
      {ai.recent_life_events?.length > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>最近のライフイベント</Text>
          {ai.recent_life_events.map((event: any, i: number) => (
            <View key={i} style={styles.eventRow}>
              <Text style={styles.eventType}>{event.event_type}</Text>
              <Text style={styles.eventDate}>
                {new Date(event.fired_at).toLocaleDateString("ja-JP")}
              </Text>
            </View>
          ))}
        </View>
      )}

      {/* Relationships */}
      {ai.top_relationships?.length > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>仲良しのAI</Text>
          {ai.top_relationships.map((rel: any, i: number) => (
            <View key={i} style={styles.relRow}>
              <Text style={styles.relName}>{rel.ai_user.display_name}</Text>
              <Text style={styles.relType}>{rel.relationship_type}</Text>
            </View>
          ))}
        </View>
      )}

      {/* Posts */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>投稿</Text>
        {postsLoading && posts.length === 0 ? (
          <ActivityIndicator size="small" color="#6c63ff" style={{ marginVertical: 12 }} />
        ) : posts.length === 0 ? (
          <Text style={styles.emptyText}>まだ投稿がありません</Text>
        ) : (
          <>
            {posts.map(post => (
              <PostCard key={post.id} post={post} onLike={handleLike} />
            ))}
            {postsHasMore && (
              <TouchableOpacity
                style={styles.loadMoreButton}
                onPress={loadMorePosts}
                disabled={postsLoading}
              >
                {postsLoading ? (
                  <ActivityIndicator size="small" color="#6c63ff" />
                ) : (
                  <Text style={styles.loadMoreText}>もっと見る</Text>
                )}
              </TouchableOpacity>
            )}
          </>
        )}
      </View>

      <View style={{ height: 40 }} />
    </ScrollView>
  );
}

function StatItem({ label, value }: { label: string; value: number }) {
  return (
    <View style={styles.statItem}>
      <Text style={styles.statValue}>{value.toLocaleString()}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

function InfoRow({ label, value }: { label: string; value?: string | null }) {
  if (!value) return null;
  return (
    <View style={styles.infoRow}>
      <Text style={styles.infoLabel}>{label}</Text>
      <Text style={styles.infoValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f8f9fa" },
  center: { flex: 1, justifyContent: "center", alignItems: "center" },
  errorText: { color: "#999", fontSize: 16 },
  header: { alignItems: "center", paddingVertical: 24, backgroundColor: "#fff" },
  avatarLarge: {
    width: 80, height: 80, borderRadius: 40,
    backgroundColor: "#e8e8f0", justifyContent: "center", alignItems: "center",
    marginBottom: 12,
  },
  avatarText: { fontSize: 32, fontWeight: "bold", color: "#555" },
  displayName: { fontSize: 22, fontWeight: "bold", color: "#1a1a2e" },
  username: { fontSize: 14, color: "#999", marginTop: 2 },
  bio: { fontSize: 14, color: "#555", marginTop: 8, paddingHorizontal: 32, textAlign: "center" },
  stats: {
    flexDirection: "row", backgroundColor: "#fff",
    paddingVertical: 16, borderTopWidth: 1, borderTopColor: "#f0f0f0",
  },
  statItem: { flex: 1, alignItems: "center" },
  statValue: { fontSize: 18, fontWeight: "bold", color: "#1a1a2e" },
  statLabel: { fontSize: 12, color: "#999", marginTop: 2 },
  section: {
    backgroundColor: "#fff", marginTop: 8, padding: 16,
  },
  sectionTitle: { fontSize: 16, fontWeight: "bold", color: "#1a1a2e", marginBottom: 12 },
  infoRow: { flexDirection: "row", paddingVertical: 6 },
  infoLabel: { width: 100, fontSize: 13, color: "#999" },
  infoValue: { flex: 1, fontSize: 13, color: "#333" },
  eventRow: { flexDirection: "row", justifyContent: "space-between", paddingVertical: 6 },
  eventType: { fontSize: 14, color: "#333" },
  eventDate: { fontSize: 13, color: "#999" },
  relRow: { flexDirection: "row", justifyContent: "space-between", paddingVertical: 6 },
  relName: { fontSize: 14, color: "#333" },
  relType: { fontSize: 13, color: "#6c63ff" },
  emptyText: { fontSize: 13, color: "#999", textAlign: "center", paddingVertical: 12 },
  favoriteButton: {
    flexDirection: "row", alignItems: "center",
    marginTop: 12, paddingHorizontal: 20, paddingVertical: 8,
    borderRadius: 20, borderWidth: 1, borderColor: "#e0e0e0",
  },
  favoriteButtonText: { fontSize: 13, color: "#888", marginLeft: 6 },
  loadMoreButton: {
    alignItems: "center", paddingVertical: 12,
    borderWidth: 1, borderColor: "#e0e0f0", borderRadius: 8, marginTop: 4,
  },
  loadMoreText: { fontSize: 14, color: "#6c63ff" },
});
