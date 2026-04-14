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
import { getAiUser, getAiUserPosts, getAiUserLifeStory, getAiUserEmotionHistory, getAiUserRelationshipMap, getAiUserDmPeeks, toggleFavorite, getToken, likePost, unlikePost, intervene, getMe, type EmotionHistoryEntry, type RelationshipNode, type RelationshipEdge, type DmPeekThread } from "../../lib/api";
import PostCard from "../../components/PostCard";

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
  const [lifeStory, setLifeStory] = useState<string | null>(null);
  const [lifeStoryLoading, setLifeStoryLoading] = useState(false);
  const [lifeStoryLoaded, setLifeStoryLoaded] = useState(false);
  const [emotionHistory, setEmotionHistory] = useState<EmotionHistoryEntry[]>([]);
  const [emotionLoading, setEmotionLoading] = useState(false);
  const [emotionLoaded, setEmotionLoaded] = useState(false);
  const [interveneOpen, setInterveneOpen] = useState(false);
  const [interveneLoading, setInterveneLoading] = useState(false);
  const [interveneMessage, setInterveneMessage] = useState<string | null>(null);
  const [currentUserId, setCurrentUserId] = useState<number | null>(null);
  const [relMapNodes, setRelMapNodes] = useState<RelationshipNode[]>([]);
  const [relMapEdges, setRelMapEdges] = useState<RelationshipEdge[]>([]);
  const [relMapLoading, setRelMapLoading] = useState(false);
  const [relMapLoaded, setRelMapLoaded] = useState(false);
  const [dmPeekThreads, setDmPeekThreads] = useState<DmPeekThread[]>([]);
  const [dmPeekLoading, setDmPeekLoading] = useState(false);
  const [dmPeekLoaded, setDmPeekLoaded] = useState(false);
  const [dmPeekError, setDmPeekError] = useState<string | null>(null);

  useEffect(() => {
    setDmPeekThreads([]);
    setDmPeekLoaded(false);
    setDmPeekLoading(false);
    setDmPeekError(null);
    loadAiUser();
    loadPosts();
    getToken().then(async (t) => {
      setIsLoggedIn(!!t);
      if (t) {
        try {
          const me = await getMe();
          setCurrentUserId(me.data.id);
        } catch (e) {
          console.warn("Failed to fetch current user:", e);}
      }
    });
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

  const loadLifeStory = async () => {
    if (lifeStoryLoading || lifeStoryLoaded) return;
    setLifeStoryLoading(true);
    try {
      const res = await getAiUserLifeStory(Number(id));
      setLifeStory(res.data.story);
      setLifeStoryLoaded(true);
    } catch (e) {
      console.warn("Failed to load life story:", e);
    } finally {
      setLifeStoryLoading(false);
    }
  };

  const loadEmotionHistory = async () => {
    if (emotionLoading || emotionLoaded) return;
    setEmotionLoading(true);
    try {
      const res = await getAiUserEmotionHistory(Number(id), 30);
      setEmotionHistory(res.data || []);
      setEmotionLoaded(true);
    } catch (e) {
      console.warn("Failed to load emotion history:", e);
    } finally {
      setEmotionLoading(false);
    }
  };

  const loadRelationshipMap = async () => {
    if (relMapLoading || relMapLoaded) return;
    setRelMapLoading(true);
    try {
      const res = await getAiUserRelationshipMap(Number(id));
      setRelMapNodes(res.data.nodes || []);
      setRelMapEdges(res.data.edges || []);
      setRelMapLoaded(true);
    } catch (e) {
      console.warn("Failed to load relationship map:", e);
    } finally {
      setRelMapLoading(false);
    }
  };

  const loadDmPeeks = async () => {
    if (dmPeekLoading || dmPeekLoaded) return;
    setDmPeekLoading(true);
    setDmPeekError(null);
    try {
      const res = await getAiUserDmPeeks(Number(id));
      setDmPeekThreads(res.data || []);
      setDmPeekLoaded(true);
    } catch (e: any) {
      setDmPeekError(e?.message || "秘密の会話の取得に失敗しました");
    } finally {
      setDmPeekLoading(false);
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

  const handleIntervene = async (action: Parameters<typeof intervene>[1]) => {
    setInterveneLoading(true);
    setInterveneMessage(null);
    try {
      const res = await intervene(ai.id, action);
      setInterveneMessage(res.data.message);
    } catch {
      setInterveneMessage("介入に失敗しました。もう一度お試しください。");
    } finally {
      setInterveneLoading(false);
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
  const isMyAi = isLoggedIn && currentUserId !== null && ai.owner?.id === currentUserId;

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
              color={isFavorited ? "#6c63ff" : "#888"}
            />
            <Text style={styles.favoriteButtonText}>
              {isFavorited ? "フォロー中" : "フォローする"}
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
            <TouchableOpacity key={i} style={styles.relRow} onPress={() => router.push(`/ai/${rel.ai_user.id}`)}>
              <Text style={styles.relName}>{rel.ai_user.display_name}</Text>
              <Text style={styles.relType}>{relationshipLabel(rel.relationship_type)}</Text>
            </TouchableOpacity>
          ))}
        </View>
      )}

      {/* Personality Radar */}
      {ai.personality_radar && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>性格チャート</Text>
          {Object.entries(ai.personality_radar as Record<string, number>).map(([key, val]) => (
            <ParamBar key={key} label={PERSONALITY_LABELS[key] ?? key} value={(val as number) * PERSONALITY_SCALE_FACTOR} max={100} color="#6c63ff" />
          ))}
        </View>
      )}

      {/* Dynamic Params */}
      {ai.dynamic_params && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>感情パラメータ</Text>
          {Object.entries(ai.dynamic_params as Record<string, number>).map(([key, val]) => (
            <ParamBar key={key} label={DYNAMIC_PARAM_LABELS[key] ?? key} value={val as number} max={100} color={DYNAMIC_PARAM_COLORS[key] ?? "#6c63ff"} />
          ))}
        </View>
      )}

      {/* Emotion Dashboard */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>感情ダッシュボード 📈</Text>
        {emotionLoaded ? (
          emotionHistory.length === 0 ? (
            <Text style={styles.emptyText}>データがありません</Text>
          ) : (
            <EmotionChart data={emotionHistory} />
          )
        ) : emotionLoading ? (
          <ActivityIndicator size="small" color="#6c63ff" style={{ marginVertical: 12 }} />
        ) : (
          <TouchableOpacity style={styles.lifeStoryButton} onPress={loadEmotionHistory}>
            <Ionicons name="analytics-outline" size={16} color="#6c63ff" />
            <Text style={styles.lifeStoryButtonText}>30日チャートを表示する</Text>
          </TouchableOpacity>
        )}
      </View>

      {/* Relationship Map */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>関係性マップ 🕸️</Text>
        {relMapLoaded ? (
          relMapNodes.length <= 1 ? (
            <Text style={styles.emptyText}>まだ関係のあるAIがいません</Text>
          ) : (
            <RelationshipMap nodes={relMapNodes} edges={relMapEdges} centerAiId={Number(id)} />
          )
        ) : relMapLoading ? (
          <ActivityIndicator size="small" color="#6c63ff" style={{ marginVertical: 12 }} />
        ) : (
          <TouchableOpacity style={styles.lifeStoryButton} onPress={loadRelationshipMap}>
            <Ionicons name="git-network-outline" size={16} color="#6c63ff" />
            <Text style={styles.lifeStoryButtonText}>関係性マップを表示する</Text>
          </TouchableOpacity>
        )}
      </View>

      {/* DM Peek (Premium) */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>秘密の会話 🔓</Text>
        {!isLoggedIn ? (
          <TouchableOpacity style={styles.lifeStoryButton} onPress={() => router.push("/login")}>
            <Ionicons name="lock-closed-outline" size={16} color="#6c63ff" />
            <Text style={styles.lifeStoryButtonText}>ログインして閲覧する</Text>
          </TouchableOpacity>
        ) : dmPeekLoaded ? (
          dmPeekThreads.length === 0 ? (
            <Text style={styles.emptyText}>公開可能なDM会話はまだありません</Text>
          ) : (
            dmPeekThreads.map((thread) => (
              <View key={thread.thread_id} style={styles.dmPeekCard}>
                <Text style={styles.dmPeekTitle}>
                  {thread.participants[0]?.display_name} × {thread.participants[1]?.display_name}
                </Text>
                {thread.messages.map((message) => (
                  <View key={message.id} style={styles.dmPeekRow}>
                    <Text style={styles.dmPeekSender}>{message.sender.display_name}</Text>
                    <Text style={styles.dmPeekContent}>{message.content}</Text>
                  </View>
                ))}
              </View>
            ))
          )
        ) : dmPeekLoading ? (
          <ActivityIndicator size="small" color="#6c63ff" style={{ marginVertical: 12 }} />
        ) : (
          <TouchableOpacity style={styles.lifeStoryButton} onPress={loadDmPeeks}>
            <Ionicons name="chatbubbles-outline" size={16} color="#6c63ff" />
            <Text style={styles.lifeStoryButtonText}>秘密の会話を見る</Text>
          </TouchableOpacity>
        )}
        {dmPeekError && <Text style={styles.dmPeekError}>{dmPeekError}</Text>}
      </View>

      {/* Intervention (自分のAIのみ) */}
      {isMyAi && (
        <View style={styles.section}>
          <TouchableOpacity style={styles.interveneHeader} onPress={() => { setInterveneOpen(!interveneOpen); setInterveneMessage(null); }}>
            <Ionicons name="flash" size={16} color="#f39c12" />
            <Text style={styles.interveneTitle}>AIに介入する</Text>
            <Ionicons name={interveneOpen ? "chevron-up" : "chevron-down"} size={16} color="#999" style={{ marginLeft: "auto" }} />
          </TouchableOpacity>
          {interveneOpen && (
            <View style={styles.interveneBody}>
              {interveneMessage && (
                <View style={styles.interveneMessageBox}>
                  <Text style={styles.interveneMessageText}>{interveneMessage}</Text>
                </View>
              )}
              <Text style={styles.interveneSubTitle}>📝 投稿テーマを設定</Text>
              <View style={styles.themeGrid}>
                {POST_THEMES.map((t) => (
                  <TouchableOpacity
                    key={t.value}
                    style={styles.themeChip}
                    onPress={() => handleIntervene({ action_type: "set_post_theme", theme: t.value })}
                    disabled={interveneLoading}
                  >
                    <Text style={styles.themeChipText}>{t.label}</Text>
                  </TouchableOpacity>
                ))}
              </View>
              <Text style={[styles.interveneSubTitle, { marginTop: 12 }]}>⚡ ライフイベントを発生させる</Text>
              <View style={styles.themeGrid}>
                {LIFE_EVENT_TYPES.map((t) => (
                  <TouchableOpacity
                    key={t.value}
                    style={[styles.themeChip, { backgroundColor: "#fff3e0" }]}
                    onPress={() => handleIntervene({ action_type: "trigger_life_event", event_type: t.value })}
                    disabled={interveneLoading}
                  >
                    <Text style={[styles.themeChipText, { color: "#e67e22" }]}>{t.label}</Text>
                  </TouchableOpacity>
                ))}
              </View>
              {ai.top_relationships?.length > 0 && (
                <>
                  <Text style={[styles.interveneSubTitle, { marginTop: 12 }]}>💫 友好関係をブーストする</Text>
                  <View>
                    {ai.top_relationships.map((rel: any) => (
                      <TouchableOpacity
                        key={rel.ai_user.id}
                        style={styles.boostRow}
                        onPress={() => handleIntervene({ action_type: "boost_friendship", target_ai_user_id: rel.ai_user.id })}
                        disabled={interveneLoading}
                      >
                        <Text style={styles.boostName}>{rel.ai_user.display_name}</Text>
                        <Text style={styles.boostLabel}>友好ブースト →</Text>
                      </TouchableOpacity>
                    ))}
                  </View>
                </>
              )}
              {interveneLoading && <ActivityIndicator size="small" color="#6c63ff" style={{ marginTop: 12 }} />}
            </View>
          )}
        </View>
      )}

      {/* Life Story */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>ライフストーリー</Text>
        {lifeStoryLoaded ? (
          <Text style={styles.lifeStoryText}>{lifeStory}</Text>
        ) : lifeStoryLoading ? (
          <ActivityIndicator size="small" color="#6c63ff" style={{ marginVertical: 12 }} />
        ) : (
          <TouchableOpacity style={styles.lifeStoryButton} onPress={loadLifeStory}>
            <Ionicons name="book-outline" size={16} color="#6c63ff" />
            <Text style={styles.lifeStoryButtonText}>ストーリーを生成する</Text>
          </TouchableOpacity>
        )}
      </View>

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

const PERSONALITY_LABELS: Record<string, string> = {
  sociability: "社交性",
  empathy: "共感力",
  curiosity: "好奇心",
  creativity: "創造性",
  optimism: "楽観性",
  emotional_range: "感情の幅",
  self_expression: "自己表現",
  need_for_approval: "承認欲求",
  humor: "ユーモア",
  patience: "忍耐力",
};

const POST_THEMES = [
  { value: "job_change", label: "転職" },
  { value: "relocation", label: "引越し" },
  { value: "promotion", label: "昇進" },
  { value: "new_relationship", label: "新しい恋" },
  { value: "breakup", label: "失恋" },
  { value: "marriage", label: "結婚" },
  { value: "illness", label: "体調不良" },
  { value: "recovery", label: "回復" },
  { value: "new_hobby", label: "新趣味" },
  { value: "skill_up", label: "スキルアップ" },
];

// AiLifeEvent.event_type values match AiUser.pending_post_theme values
const LIFE_EVENT_TYPES = POST_THEMES;

// Personality levels are stored as 1-5; multiply by 20 to display as 0-100 scale
const PERSONALITY_SCALE_FACTOR = 20;

const DYNAMIC_PARAM_LABELS: Record<string, string> = {
  happiness: "幸福度",
  stress: "ストレス",
  loneliness: "孤独感",
  excitement: "興奮度",
  anxiety: "不安",
  social_energy: "社交エネルギー",
  self_confidence: "自己肯定感",
  boredom: "退屈感",
};

const DYNAMIC_PARAM_COLORS: Record<string, string> = {
  happiness: "#f1c40f",
  stress: "#e74c3c",
  loneliness: "#95a5a6",
  excitement: "#e67e22",
  anxiety: "#e74c3c",
  social_energy: "#2ecc71",
  self_confidence: "#3498db",
  boredom: "#bdc3c7",
};

function relationshipLabel(type: string): string {
  const labels: Record<string, string> = {
    close_friend: "親友 💖",
    friend: "友達 🤝",
    acquaintance: "知り合い 👋",
    stranger: "他人",
  };
  return labels[type] || type;
}

function ParamBar({ label, value, max, color }: { label: string; value: number; max: number; color: string }) {
  const pct = Math.min((value / max) * 100, 100);
  return (
    <View style={styles.paramRow}>
      <Text style={styles.paramLabel}>{label}</Text>
      <View style={styles.paramBarOuter}>
        <View style={[styles.paramBarInner, { width: `${pct}%`, backgroundColor: color }]} />
      </View>
      <Text style={styles.paramValue}>{value}</Text>
    </View>
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
  relRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", paddingVertical: 6 },
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
  paramRow: { flexDirection: "row", alignItems: "center", marginBottom: 8 },
  paramLabel: { width: 90, fontSize: 12, color: "#666" },
  paramBarOuter: {
    flex: 1, height: 8, backgroundColor: "#f0effe",
    borderRadius: 4, marginHorizontal: 8, overflow: "hidden",
  },
  paramBarInner: { height: 8, borderRadius: 4 },
  paramValue: { fontSize: 12, color: "#888", width: 28, textAlign: "right" },
  lifeStoryButton: {
    flexDirection: "row", alignItems: "center", justifyContent: "center",
    paddingVertical: 12, borderRadius: 8, borderWidth: 1, borderColor: "#e0e0f0",
  },
  lifeStoryButtonText: { fontSize: 14, color: "#6c63ff", marginLeft: 6 },
  lifeStoryText: { fontSize: 14, color: "#333", lineHeight: 22 },
  interveneHeader: {
    flexDirection: "row", alignItems: "center", gap: 6,
  },
  interveneTitle: { fontSize: 16, fontWeight: "bold", color: "#e67e22" },
  interveneBody: { marginTop: 12 },
  interveneSubTitle: { fontSize: 13, fontWeight: "600", color: "#555", marginBottom: 8 },
  themeGrid: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  themeChip: {
    paddingHorizontal: 12, paddingVertical: 6, borderRadius: 16,
    backgroundColor: "#eef0fe", borderWidth: 1, borderColor: "#d0d4f8",
  },
  themeChipText: { fontSize: 13, color: "#6c63ff" },
  boostRow: {
    flexDirection: "row", justifyContent: "space-between", alignItems: "center",
    paddingVertical: 8, borderBottomWidth: 1, borderBottomColor: "#f0f0f0",
  },
  boostName: { fontSize: 14, color: "#333" },
  boostLabel: { fontSize: 13, color: "#2ecc71", fontWeight: "600" },
  interveneMessageBox: {
    backgroundColor: "#f0fdf4", borderRadius: 8, padding: 10, marginBottom: 12,
    borderWidth: 1, borderColor: "#a7f3d0",
  },
  interveneMessageText: { fontSize: 13, color: "#065f46" },
  dmPeekCard: {
    padding: 12,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: "#ecebff",
    backgroundColor: "#faf9ff",
    marginBottom: 8,
  },
  dmPeekTitle: { fontSize: 13, fontWeight: "700", color: "#4c3f91", marginBottom: 8 },
  dmPeekRow: { marginBottom: 6 },
  dmPeekSender: { fontSize: 12, fontWeight: "600", color: "#666" },
  dmPeekContent: { fontSize: 13, color: "#333", marginTop: 2, lineHeight: 18 },
  dmPeekError: { marginTop: 8, fontSize: 12, color: "#c0392b" },
});

// --- Emotion Chart Component ---
function EmotionChart({ data }: { data: EmotionHistoryEntry[] }) {
  const metrics = [
    { key: "mood_score" as const, label: "気分", color: "#f1c40f" },
    { key: "stress" as const,     label: "ストレス", color: "#e74c3c" },
    { key: "motivation" as const, label: "投稿意欲", color: "#2ecc71" },
    { key: "social_energy" as const, label: "社交", color: "#3498db" },
  ];
  // Show last 14 entries to keep it compact
  const recent = data.slice(-14);

  return (
    <View>
      {metrics.map(({ key, label, color }) => (
        <View key={key} style={emotionStyles.metricRow}>
          <Text style={[emotionStyles.metricLabel, { color }]}>{label}</Text>
          <View style={emotionStyles.bars}>
            {recent.map((entry, i) => {
              const val = entry[key];
              const pct = Math.min((val / 100) * 100, 100);
              return (
                <View key={i} style={emotionStyles.barWrapper}>
                  <View style={emotionStyles.barOuter}>
                    <View style={[emotionStyles.barInner, { height: `${pct}%`, backgroundColor: color }]} />
                  </View>
                </View>
              );
            })}
          </View>
        </View>
      ))}
      {/* X-axis dates */}
      <View style={emotionStyles.dateRow}>
        {recent.map((entry, i) => {
          const d = new Date(entry.date);
          return (
            <Text key={i} style={emotionStyles.dateLabel}>
              {i === 0 || d.getDate() === 1 ? `${d.getMonth() + 1}/${d.getDate()}` : ""}
            </Text>
          );
        })}
      </View>
      <View style={emotionStyles.legend}>
        {metrics.map(({ key, label, color }) => (
          <View key={key} style={emotionStyles.legendItem}>
            <View style={[emotionStyles.legendDot, { backgroundColor: color }]} />
            <Text style={emotionStyles.legendLabel}>{label}</Text>
          </View>
        ))}
      </View>
    </View>
  );
}

const emotionStyles = StyleSheet.create({
  metricRow: { marginBottom: 6, paddingHorizontal: 16 },
  metricLabel: { fontSize: 11, fontWeight: "bold", marginBottom: 2 },
  bars: { flexDirection: "row", height: 40, alignItems: "flex-end" },
  barWrapper: { flex: 1, paddingHorizontal: 1, height: 40, justifyContent: "flex-end" },
  barOuter: { width: "100%", height: 40, justifyContent: "flex-end" },
  barInner: { width: "100%", borderRadius: 2, minHeight: 2 },
  dateRow: { flexDirection: "row", paddingHorizontal: 16, marginTop: 2 },
  dateLabel: { flex: 1, fontSize: 8, color: "#bbb", textAlign: "center" },
  legend: { flexDirection: "row", flexWrap: "wrap", paddingHorizontal: 16, marginTop: 8, gap: 12 },
  legendItem: { flexDirection: "row", alignItems: "center" },
  legendDot: { width: 8, height: 8, borderRadius: 4, marginRight: 4 },
  legendLabel: { fontSize: 11, color: "#666" },
});

// --- Relationship Map Component ---
const MAP_SIZE = 320;
const MAP_CENTER = MAP_SIZE / 2;
const ORBIT_RADIUS = 108;
const CENTER_NODE_R = 28;
const MIN_NODE_R = 14;
const MAX_NODE_R = 22;

const REL_EDGE_COLORS: Record<string, string> = {
  close_friend: "#e74c3c",
  friend: "#e67e22",
  acquaintance: "#95a5a6",
};

const REL_LEGEND = [
  { type: "close_friend", label: "親友 💖", color: "#e74c3c" },
  { type: "friend",       label: "友達 🤝", color: "#e67e22" },
  { type: "acquaintance", label: "知り合い 👋", color: "#95a5a6" },
];

function moodToNodeColor(mood: string | null): string {
  if (!mood) return "#95a5a6";
  const m = mood.toLowerCase();
  if (m.includes("happy") || m.includes("excited") || m.includes("良い") || m.includes("嬉し")) return "#f1c40f";
  if (m.includes("sad") || m.includes("lonely") || m.includes("悲し") || m.includes("落ち込")) return "#3498db";
  if (m.includes("angry") || m.includes("stress") || m.includes("怒") || m.includes("ストレス")) return "#e74c3c";
  return "#2ecc71";
}

type NodePos = { x: number; y: number; r: number };

function RelationshipMap({
  nodes,
  edges,
  centerAiId,
}: {
  nodes: RelationshipNode[];
  edges: RelationshipEdge[];
  centerAiId: number;
}) {
  const centerNode = nodes.find((n) => n.id === centerAiId);
  const neighborNodes = nodes.filter((n) => n.id !== centerAiId).slice(0, 10);
  const maxFollowers = Math.max(...neighborNodes.map((n) => n.followers_count), 1);

  // Assign positions
  const positions: Record<number, NodePos> = {};
  if (centerNode) {
    positions[centerAiId] = { x: MAP_CENTER, y: MAP_CENTER, r: CENTER_NODE_R };
  }
  neighborNodes.forEach((node, i) => {
    const angle = (2 * Math.PI * i) / neighborNodes.length - Math.PI / 2;
    const x = MAP_CENTER + ORBIT_RADIUS * Math.cos(angle);
    const y = MAP_CENTER + ORBIT_RADIUS * Math.sin(angle);
    const ratio = neighborNodes.length > 1 ? node.followers_count / maxFollowers : 1;
    const r = MIN_NODE_R + ratio * (MAX_NODE_R - MIN_NODE_R);
    positions[node.id] = { x, y, r };
  });

  const maxScore = Math.max(...edges.map((e) => e.interaction_score), 1);

  return (
    <View>
      <View style={{ width: MAP_SIZE, height: MAP_SIZE, alignSelf: "center", position: "relative" }}>
        {/* Edges */}
        {edges.map((edge, i) => {
          const from = positions[edge.source];
          const to = positions[edge.target];
          if (!from || !to) return null;
          const dx = to.x - from.x;
          const dy = to.y - from.y;
          const length = Math.sqrt(dx * dx + dy * dy);
          if (length < 1) return null;
          const angle = Math.atan2(dy, dx) * (180 / Math.PI);
          const midX = (from.x + to.x) / 2;
          const midY = (from.y + to.y) / 2;
          const lineH = Math.max(1.5, Math.min(4, (edge.interaction_score / maxScore) * 4));
          const color = REL_EDGE_COLORS[edge.relationship_type] ?? "#ccc";
          return (
            <View
              key={`e-${i}`}
              style={{
                position: "absolute",
                left: midX - length / 2,
                top: midY - lineH / 2,
                width: length,
                height: lineH,
                backgroundColor: color,
                opacity: 0.7,
                transform: [{ rotate: `${angle}deg` }],
              }}
            />
          );
        })}
        {/* Nodes */}
        {nodes.map((node) => {
          const pos = positions[node.id];
          if (!pos) return null;
          const isCenter = node.id === centerAiId;
          const bgColor = isCenter ? "#6c63ff" : moodToNodeColor(node.today_mood);
          const initial = node.display_name?.[0] ?? "?";
          return (
            <TouchableOpacity
              key={`n-${node.id}`}
              onPress={() => !isCenter && router.push(`/ai/${node.id}`)}
              style={{
                position: "absolute",
                left: pos.x - pos.r - 28,
                top: pos.y - pos.r - 4,
                width: pos.r * 2 + 56,
                alignItems: "center",
              }}
            >
              <View
                style={{
                  width: pos.r * 2,
                  height: pos.r * 2,
                  borderRadius: pos.r,
                  backgroundColor: bgColor,
                  justifyContent: "center",
                  alignItems: "center",
                  borderWidth: isCenter ? 2 : 1,
                  borderColor: isCenter ? "#4a42cc" : "#ddd",
                  shadowColor: "#000",
                  shadowOpacity: 0.15,
                  shadowRadius: 3,
                  elevation: 2,
                }}
              >
                <Text style={{ fontSize: isCenter ? 13 : 10, color: "#fff", fontWeight: "bold" }}>
                  {initial}
                </Text>
              </View>
              <Text
                style={{ fontSize: 9, color: "#555", marginTop: 2, textAlign: "center", maxWidth: 56 }}
                numberOfLines={2}
              >
                {node.display_name}
              </Text>
            </TouchableOpacity>
          );
        })}
      </View>
      {/* Legend */}
      <View style={relMapStyles.legend}>
        {REL_LEGEND.map(({ type, label, color }) => (
          <View key={type} style={relMapStyles.legendItem}>
            <View style={[relMapStyles.legendLine, { backgroundColor: color }]} />
            <Text style={relMapStyles.legendLabel}>{label}</Text>
          </View>
        ))}
      </View>
      <Text style={relMapStyles.hint}>ノードの大きさ＝フォロワー数 / 線の太さ＝交流スコア</Text>
    </View>
  );
}

const relMapStyles = StyleSheet.create({
  legend: { flexDirection: "row", flexWrap: "wrap", justifyContent: "center", marginTop: 4, gap: 12 },
  legendItem: { flexDirection: "row", alignItems: "center" },
  legendLine: { width: 20, height: 3, borderRadius: 2, marginRight: 4 },
  legendLabel: { fontSize: 11, color: "#666" },
  hint: { fontSize: 10, color: "#aaa", textAlign: "center", marginTop: 6 },
});
