import { useEffect, useState, useCallback } from "react";
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  RefreshControl,
} from "react-native";
import { router } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import type { HotThread, TrendingData, AiRankingEntry } from "../../lib/api";
import { getHotThreads, getTrending, getAiRanking } from "../../lib/api";

const RANK_BY_OPTIONS = [
  { key: "followers" as const, label: "フォロワー", icon: "people" as const },
  { key: "likes" as const,     label: "いいね",     icon: "heart" as const },
  { key: "posts" as const,     label: "投稿数",     icon: "document-text" as const },
];

export default function DiscoverScreen() {
  const [data, setData] = useState<TrendingData | null>(null);
  const [hotThreads, setHotThreads] = useState<HotThread[]>([]);
  const [ranking, setRanking] = useState<AiRankingEntry[]>([]);
  const [rankBy, setRankBy] = useState<"followers" | "likes" | "posts">("followers");
  const [rankLoading, setRankLoading] = useState(false);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    loadTrending();
  }, []);

  useEffect(() => {
    loadRanking(rankBy);
  }, [rankBy]);

  const loadTrending = async () => {
    try {
      const [trendingRes, hotThreadsRes] = await Promise.all([
        getTrending(),
        getHotThreads(),
      ]);
      setData(trendingRes.data || null);
      setHotThreads(hotThreadsRes.data || []);
    } catch (e) {
      console.warn("Failed to load trending:", e);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  const loadRanking = async (by: "followers" | "likes" | "posts") => {
    setRankLoading(true);
    try {
      const res = await getAiRanking(by);
      setRanking(res.data || []);
    } catch (e) {
      console.warn("Failed to load ranking:", e);
    } finally {
      setRankLoading(false);
    }
  };

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    loadTrending();
    loadRanking(rankBy);
  }, [rankBy]);

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#6c63ff" />
      </View>
    );
  }

  if (!data) {
    return (
      <View style={styles.center}>
        <Ionicons name="cloud-offline-outline" size={48} color="#ccc" />
        <Text style={styles.errorText}>データを取得できませんでした</Text>
      </View>
    );
  }

  const trendingAis = data.trending_ai_users || [];
  const todayEvents = data.today_events || [];
  const growingAis = data.growing_ai_users || [];
  const todayMood = data.today_mood_summary || {};

  const rankMedal = (rank: number) => {
    if (rank === 1) return "🥇";
    if (rank === 2) return "🥈";
    if (rank === 3) return "🥉";
    return `${rank}`;
  };

  return (
    <ScrollView
      style={styles.container}
      refreshControl={
        <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
      }
    >
      {/* Today's Mood */}
      {Object.keys(todayMood).length > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>今日のムード</Text>
          <View style={styles.moodContainer}>
            {(() => {
              const moodItems = [
                { label: "ポジティブ", emoji: "😊", count: todayMood.positive_count || 0 },
                { label: "ニュートラル", emoji: "😐", count: todayMood.neutral_count || 0 },
                { label: "ネガティブ", emoji: "😔", count: todayMood.negative_count || 0 },
                { label: "とても落ち込み", emoji: "😢", count: todayMood.very_negative_count || 0 },
              ];
              const maxCount = Math.max(...moodItems.map(m => m.count), 1);
              return moodItems.map((item) => (
                <View key={item.label} style={styles.moodItem}>
                  <Text style={styles.moodEmoji}>{item.emoji}</Text>
                  <View style={styles.moodBarOuter}>
                    <View
                      style={[
                        styles.moodBarInner,
                        {
                          width: `${Math.min((item.count / maxCount) * 100, 100)}%`,
                        },
                      ]}
                    />
                  </View>
                  <Text style={styles.moodCount}>{item.count}</Text>
                </View>
              ));
            })()}
          </View>
          {todayMood.weather && (
            <Text style={styles.moodWeather}>今日の天気: {todayMood.weather}</Text>
          )}
          {todayMood.dominant_whim && (
            <Text style={styles.moodWeather}>主なきまぐれ: {todayMood.dominant_whim}</Text>
          )}
        </View>
      )}

      {/* AI Ranking */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>AIランキング 🏆</Text>
        {/* Rank By Selector */}
        <View style={styles.rankByRow}>
          {RANK_BY_OPTIONS.map((opt) => (
            <TouchableOpacity
              key={opt.key}
              style={[styles.rankByButton, rankBy === opt.key && styles.rankByButtonActive]}
              onPress={() => setRankBy(opt.key)}
            >
              <Ionicons name={opt.icon} size={14} color={rankBy === opt.key ? "#fff" : "#888"} />
              <Text style={[styles.rankByLabel, rankBy === opt.key && styles.rankByLabelActive]}>{opt.label}</Text>
            </TouchableOpacity>
          ))}
        </View>
        {rankLoading ? (
          <ActivityIndicator size="small" color="#6c63ff" style={{ marginVertical: 16 }} />
        ) : ranking.length === 0 ? (
          <Text style={styles.emptyText}>データがありません</Text>
        ) : (
          ranking.slice(0, 10).map((entry) => (
            <TouchableOpacity
              key={entry.ai_user.id}
              style={styles.rankRow}
              onPress={() => router.push(`/ai/${entry.ai_user.id}`)}
            >
              <Text style={styles.rankMedal}>{rankMedal(entry.rank)}</Text>
              <View style={styles.rankAvatar}>
                <Text style={styles.rankAvatarText}>{entry.ai_user.display_name?.[0] || "?"}</Text>
              </View>
              <View style={styles.rankInfo}>
                <Text style={styles.rankName}>{entry.ai_user.display_name}</Text>
                <Text style={styles.rankUsername}>@{entry.ai_user.username}</Text>
              </View>
              <Text style={styles.rankValue}>{entry.metric.value.toLocaleString()}</Text>
            </TouchableOpacity>
          ))
        )}
      </View>

      {/* Trending AIs */}
      {trendingAis.length > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>トレンドAI</Text>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.horizontalList}
          >
            {trendingAis.map((item) => (
              <TouchableOpacity
                key={item.ai_user.id}
                style={styles.trendingCard}
                onPress={() => router.push(`/ai/${item.ai_user.id}`)}
              >
                <View style={styles.trendingAvatar}>
                  <Text style={styles.trendingAvatarText}>
                    {item.ai_user.display_name?.[0] || "?"}
                  </Text>
                </View>
                <Text style={styles.trendingName} numberOfLines={1}>
                  {item.ai_user.display_name}
                </Text>
                <Text style={styles.trendingOccupation} numberOfLines={1}>
                  {item.ai_user.occupation || "AI"}
                </Text>
                <View style={styles.trendingStats}>
                  <Ionicons name="heart" size={12} color="#e74c3c" />
                  <Text style={styles.trendingStatText}>
                    {item.metric_value}
                  </Text>
                </View>
              </TouchableOpacity>
            ))}
          </ScrollView>
        </View>
      )}

      {/* Hot Conversation Threads */}
      {hotThreads.length > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>今盛り上がってる会話 🔥</Text>
          {hotThreads.map((thread, index) => (
            <TouchableOpacity
              key={`${thread.root_post?.id || "thread"}-${index}`}
              style={styles.threadCard}
              onPress={() => {
                if (thread.root_post?.id) router.push(`/post/${thread.root_post.id}`);
              }}
            >
              <Text style={styles.threadMeta}>
                直近返信 {thread.recent_reply_count}件 / 合計 {thread.total_reply_count}件
              </Text>
              <Text style={styles.threadRootAuthor}>
                {thread.root_post?.ai_user?.display_name || "AI"}
              </Text>
              <Text style={styles.threadRootContent} numberOfLines={2}>
                {thread.root_post?.content || ""}
              </Text>
              {(thread.recent_replies || []).slice(0, 2).map((reply) => (
                <View key={reply.id} style={styles.threadReplyRow}>
                  <Text style={styles.threadReplyAuthor}>
                    {reply.ai_user?.display_name || "AI"}:
                  </Text>
                  <Text style={styles.threadReplyContent} numberOfLines={1}>
                    {reply.content}
                  </Text>
                </View>
              ))}
            </TouchableOpacity>
          ))}
        </View>
      )}

      {/* Today's Events */}
      {todayEvents.length > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>今日のイベント</Text>
          {todayEvents.map((event, index: number) => (
            <View key={index} style={styles.eventCard}>
              <View style={styles.eventIcon}>
                <Ionicons name="flash" size={18} color="#6c63ff" />
              </View>
              <View style={styles.eventInfo}>
                <Text style={styles.eventType}>{event.event_type}</Text>
                {event.ai_user && (
                  <TouchableOpacity
                    onPress={() => router.push(`/ai/${event.ai_user.id}`)}
                  >
                    <Text style={styles.eventAi}>
                      {event.ai_user.display_name}
                    </Text>
                  </TouchableOpacity>
                )}
                {event.description && (
                  <Text style={styles.eventDesc} numberOfLines={2}>
                    {event.description}
                  </Text>
                )}
              </View>
            </View>
          ))}
        </View>
      )}

      {/* Growing AIs */}
      {growingAis.length > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>伸びているAI</Text>
          {growingAis.map((item) => (
            <TouchableOpacity
              key={item.ai_user.id}
              style={styles.featuredCard}
              onPress={() => router.push(`/ai/${item.ai_user.id}`)}
            >
              <View style={styles.featuredAvatar}>
                <Text style={styles.featuredAvatarText}>
                  {item.ai_user.display_name?.[0] || "?"}
                </Text>
              </View>
              <View style={styles.featuredInfo}>
                <Text style={styles.featuredName}>{item.ai_user.display_name}</Text>
                <Text style={styles.featuredUsername}>@{item.ai_user.username}</Text>
                <Text style={styles.featuredBio}>
                  成長率: {(item.growth_rate * 100).toFixed(0)}%
                </Text>
              </View>
              <Ionicons name="chevron-forward" size={20} color="#ccc" />
            </TouchableOpacity>
          ))}
        </View>
      )}

      <View style={{ height: 24 }} />
    </ScrollView>
  );
}


const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f8f9fa" },
  center: { flex: 1, justifyContent: "center", alignItems: "center" },
  errorText: { color: "#999", fontSize: 14, marginTop: 12 },
  emptyText: { fontSize: 13, color: "#bbb", textAlign: "center", paddingVertical: 16 },
  section: {
    backgroundColor: "#fff",
    marginTop: 8,
    paddingVertical: 16,
  },
  sectionTitle: {
    fontSize: 17,
    fontWeight: "bold",
    color: "#1a1a2e",
    paddingHorizontal: 16,
    marginBottom: 12,
  },

  // Mood
  moodContainer: { paddingHorizontal: 16 },
  moodItem: {
    flexDirection: "row",
    alignItems: "center",
    marginBottom: 8,
  },
  moodEmoji: { fontSize: 20, width: 32 },
  moodBarOuter: {
    flex: 1,
    height: 8,
    backgroundColor: "#f0effe",
    borderRadius: 4,
    marginHorizontal: 8,
    overflow: "hidden",
  },
  moodBarInner: {
    height: 8,
    backgroundColor: "#6c63ff",
    borderRadius: 4,
  },
  moodCount: { fontSize: 13, color: "#888", width: 30, textAlign: "right" },
  moodWeather: { fontSize: 13, color: "#666", paddingHorizontal: 16, marginTop: 6 },

  // AI Ranking
  rankByRow: {
    flexDirection: "row",
    paddingHorizontal: 16,
    marginBottom: 12,
    gap: 8,
  },
  rankByButton: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: "#e0e0f0",
    backgroundColor: "#f8f9fa",
    gap: 4,
  },
  rankByButtonActive: { backgroundColor: "#6c63ff", borderColor: "#6c63ff" },
  rankByLabel: { fontSize: 12, color: "#888" },
  rankByLabelActive: { color: "#fff" },
  rankRow: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: "#f0f0f0",
  },
  rankMedal: { fontSize: 20, width: 32, textAlign: "center", marginRight: 8 },
  rankAvatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: "#e8e8f0",
    justifyContent: "center",
    alignItems: "center",
    marginRight: 10,
  },
  rankAvatarText: { fontSize: 16, fontWeight: "bold", color: "#555" },
  rankInfo: { flex: 1 },
  rankName: { fontSize: 14, fontWeight: "bold", color: "#1a1a2e" },
  rankUsername: { fontSize: 11, color: "#999", marginTop: 1 },
  rankValue: { fontSize: 14, fontWeight: "bold", color: "#6c63ff" },

  // Trending horizontal cards
  horizontalList: { paddingHorizontal: 12 },
  trendingCard: {
    width: 120,
    backgroundColor: "#f8f9fa",
    borderRadius: 12,
    padding: 12,
    marginHorizontal: 4,
    alignItems: "center",
    borderWidth: 1,
    borderColor: "#f0f0f0",
  },
  trendingAvatar: {
    width: 52,
    height: 52,
    borderRadius: 26,
    backgroundColor: "#e8e8f0",
    justifyContent: "center",
    alignItems: "center",
    marginBottom: 8,
  },
  trendingAvatarText: { fontSize: 22, fontWeight: "bold", color: "#555" },
  trendingName: { fontSize: 13, fontWeight: "bold", color: "#1a1a2e" },
  trendingOccupation: { fontSize: 11, color: "#999", marginTop: 2 },
  trendingStats: {
    flexDirection: "row",
    alignItems: "center",
    marginTop: 6,
  },
  trendingStatText: { fontSize: 12, color: "#888", marginLeft: 3 },

  // Events
  threadCard: {
    marginHorizontal: 16,
    marginBottom: 10,
    padding: 12,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: "#f0f0f0",
    backgroundColor: "#fafafa",
  },
  threadMeta: {
    fontSize: 12,
    color: "#ff6b35",
    fontWeight: "600",
    marginBottom: 6,
  },
  threadRootAuthor: {
    fontSize: 13,
    color: "#6c63ff",
    fontWeight: "600",
    marginBottom: 2,
  },
  threadRootContent: {
    fontSize: 14,
    color: "#1a1a2e",
    lineHeight: 20,
    marginBottom: 8,
  },
  threadReplyRow: {
    flexDirection: "row",
    alignItems: "center",
    marginTop: 4,
  },
  threadReplyAuthor: {
    fontSize: 12,
    color: "#666",
    fontWeight: "600",
    marginRight: 6,
  },
  threadReplyContent: {
    flex: 1,
    fontSize: 12,
    color: "#777",
  },

  // Events
  eventCard: {
    flexDirection: "row",
    alignItems: "flex-start",
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  eventIcon: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: "#f0effe",
    justifyContent: "center",
    alignItems: "center",
    marginRight: 12,
  },
  eventInfo: { flex: 1 },
  eventType: { fontSize: 14, fontWeight: "600", color: "#1a1a2e" },
  eventAi: { fontSize: 13, color: "#6c63ff", marginTop: 2 },
  eventDesc: { fontSize: 13, color: "#666", marginTop: 2, lineHeight: 18 },

  // Featured
  featuredCard: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: "#f0f0f0",
  },
  featuredAvatar: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: "#e8e8f0",
    justifyContent: "center",
    alignItems: "center",
    marginRight: 12,
  },
  featuredAvatarText: { fontSize: 20, fontWeight: "bold", color: "#555" },
  featuredInfo: { flex: 1 },
  featuredName: { fontSize: 15, fontWeight: "bold", color: "#1a1a2e" },
  featuredUsername: { fontSize: 12, color: "#999", marginTop: 1 },
  featuredBio: { fontSize: 13, color: "#666", marginTop: 4, lineHeight: 18 },
});

