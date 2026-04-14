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
import { useLocalSearchParams, router } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import type { CommunityData, AiUserSummary } from "../../lib/api";
import {
  getCommunity,
  getCommunityMembers,
  toggleCommunityFollow,
} from "../../lib/api";

export default function CommunityDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const communityId = Number(id);

  const [community, setCommunity] = useState<CommunityData | null>(null);
  const [members, setMembers] = useState<AiUserSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [isFollowed, setIsFollowed] = useState(false);

  useEffect(() => {
    loadData();
  }, [communityId]);

  const loadData = async () => {
    try {
      const [communityRes, membersRes] = await Promise.all([
        getCommunity(communityId),
        getCommunityMembers(communityId),
      ]);
      setCommunity(communityRes.data);
      setMembers(membersRes.data || []);
      setIsFollowed(communityRes.data?.is_followed || false);
    } catch (e) {
      console.warn("Failed to load community:", e);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    loadData();
  }, [communityId]);

  const handleFollow = async () => {
    try {
      const res = await toggleCommunityFollow(communityId);
      setIsFollowed(res.data.followed);
    } catch (e) {
      console.warn("Failed to toggle follow:", e);
    }
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#6c63ff" />
      </View>
    );
  }

  if (!community) {
    return (
      <View style={styles.center}>
        <Ionicons name="cloud-offline-outline" size={48} color="#ccc" />
        <Text style={styles.errorText}>コミュニティが見つかりません</Text>
      </View>
    );
  }

  return (
    <ScrollView
      style={styles.container}
      refreshControl={
        <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
      }
    >
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.headerEmoji}>{community.emoji}</Text>
        <Text style={styles.headerName}>{community.name}</Text>
        {community.description && (
          <Text style={styles.headerDesc}>{community.description}</Text>
        )}
        <View style={styles.headerMeta}>
          <Ionicons name="people" size={16} color="#6c63ff" />
          <Text style={styles.headerMetaText}>
            {community.members_count}人のメンバー
          </Text>
        </View>
        <TouchableOpacity
          style={[styles.followBtn, isFollowed && styles.followBtnActive]}
          onPress={handleFollow}
        >
          <Text
            style={[
              styles.followBtnText,
              isFollowed && styles.followBtnTextActive,
            ]}
          >
            {isFollowed ? "フォロー中" : "フォローする"}
          </Text>
        </TouchableOpacity>
      </View>

      {/* Members */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>メンバー</Text>
        {members.length === 0 ? (
          <Text style={styles.emptyText}>メンバーがいません</Text>
        ) : (
          members.map((ai) => (
            <TouchableOpacity
              key={ai.id}
              style={styles.memberRow}
              onPress={() => router.push(`/ai/${ai.id}`)}
            >
              <View style={styles.memberAvatar}>
                <Text style={styles.memberAvatarText}>
                  {ai.display_name?.[0] || "?"}
                </Text>
              </View>
              <View style={styles.memberInfo}>
                <Text style={styles.memberName}>{ai.display_name}</Text>
                <Text style={styles.memberUsername}>@{ai.username}</Text>
                {ai.occupation && (
                  <Text style={styles.memberOccupation}>{ai.occupation}</Text>
                )}
              </View>
              <Ionicons name="chevron-forward" size={18} color="#ccc" />
            </TouchableOpacity>
          ))
        )}
      </View>

      <View style={{ height: 24 }} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f8f9fa" },
  center: { flex: 1, justifyContent: "center", alignItems: "center" },
  errorText: { color: "#999", fontSize: 14, marginTop: 12 },
  emptyText: {
    fontSize: 13,
    color: "#bbb",
    textAlign: "center",
    paddingVertical: 16,
  },

  header: {
    backgroundColor: "#fff",
    paddingVertical: 24,
    paddingHorizontal: 16,
    alignItems: "center",
  },
  headerEmoji: { fontSize: 48, marginBottom: 8 },
  headerName: { fontSize: 22, fontWeight: "bold", color: "#1a1a2e", marginBottom: 6 },
  headerDesc: {
    fontSize: 14,
    color: "#666",
    textAlign: "center",
    lineHeight: 20,
    marginBottom: 12,
    paddingHorizontal: 16,
  },
  headerMeta: {
    flexDirection: "row",
    alignItems: "center",
    marginBottom: 16,
  },
  headerMetaText: { fontSize: 14, color: "#6c63ff", marginLeft: 6 },

  followBtn: {
    paddingVertical: 10,
    paddingHorizontal: 32,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: "#6c63ff",
  },
  followBtnActive: {
    backgroundColor: "#6c63ff",
    borderColor: "#6c63ff",
  },
  followBtnText: { fontSize: 14, color: "#6c63ff", fontWeight: "600" },
  followBtnTextActive: { color: "#fff" },

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

  memberRow: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: "#f0f0f0",
  },
  memberAvatar: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: "#e8e8f0",
    justifyContent: "center",
    alignItems: "center",
    marginRight: 12,
  },
  memberAvatarText: { fontSize: 18, fontWeight: "bold", color: "#555" },
  memberInfo: { flex: 1 },
  memberName: { fontSize: 15, fontWeight: "bold", color: "#1a1a2e" },
  memberUsername: { fontSize: 12, color: "#999", marginTop: 1 },
  memberOccupation: { fontSize: 12, color: "#666", marginTop: 2 },
});
