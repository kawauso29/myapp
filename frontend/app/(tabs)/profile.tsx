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
import { getToken, getMe, getMyFavorites, signOut, toggleFavorite } from "../../lib/api";

export default function ProfileScreen() {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [user, setUser] = useState<any>(null);
  const [favorites, setFavorites] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    checkAuthAndLoad();
  }, []);

  const checkAuthAndLoad = async () => {
    const token = await getToken();
    if (token) {
      setIsLoggedIn(true);
      await loadData();
    } else {
      setIsLoggedIn(false);
      setLoading(false);
    }
  };

  const loadData = async () => {
    try {
      const [meRes, favsRes] = await Promise.all([
        getMe(),
        getMyFavorites(),
      ]);
      setUser(meRes.data);
      setFavorites(favsRes.data);
    } catch (e) {
      console.warn("Failed to load profile:", e);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    loadData();
  }, []);

  const handleSignOut = async () => {
    try {
      await signOut();
    } catch {
      // ignore errors on sign out
    }
    setIsLoggedIn(false);
    setUser(null);
    setFavorites([]);
  };

  const handleRemoveFavorite = async (aiUserId: number) => {
    try {
      await toggleFavorite(aiUserId);
      setFavorites((prev) => prev.filter((f) => f.id !== aiUserId));
    } catch (e) {
      console.warn("Failed to remove favorite:", e);
    }
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#6c63ff" />
      </View>
    );
  }

  if (!isLoggedIn) {
    return (
      <View style={styles.loginPrompt}>
        <Ionicons name="person-circle-outline" size={80} color="#ccc" />
        <Text style={styles.loginTitle}>マイページ</Text>
        <Text style={styles.loginMessage}>
          ログインすると、お気に入りAIの管理や{"\n"}詳細なステータスが確認できます
        </Text>
        <TouchableOpacity
          style={styles.loginButton}
          onPress={() => router.push("/login")}
        >
          <Text style={styles.loginButtonText}>ログイン / 新規登録</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const rankLabel = (rank: string | undefined) => {
    const map: Record<string, string> = {
      bronze: "ブロンズ",
      silver: "シルバー",
      gold: "ゴールド",
      platinum: "プラチナ",
    };
    return rank ? map[rank] || rank : "--";
  };

  return (
    <ScrollView
      style={styles.container}
      refreshControl={
        <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
      }
    >
      {/* User Info Header */}
      <View style={styles.header}>
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>
            {user?.username?.[0]?.toUpperCase() || "?"}
          </Text>
        </View>
        <Text style={styles.username}>{user?.username}</Text>
        <Text style={styles.email}>{user?.email}</Text>
      </View>

      {/* Plan & Score */}
      <View style={styles.statsRow}>
        <View style={styles.statCard}>
          <Text style={styles.statLabel}>プラン</Text>
          <Text style={styles.statValue}>{user?.plan || "free"}</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={styles.statLabel}>オーナースコア</Text>
          <Text style={styles.statValue}>{user?.owner_score ?? 0}</Text>
        </View>
        <View style={styles.statCard}>
          <Text style={styles.statLabel}>ランク</Text>
          <Text style={styles.statValue}>{rankLabel(user?.score_rank)}</Text>
        </View>
      </View>

      {/* Create AI Button */}
      <TouchableOpacity
        style={styles.createAiButton}
        onPress={() => router.push("/create-ai")}
      >
        <Ionicons name="sparkles-outline" size={20} color="#fff" />
        <Text style={styles.createAiButtonText}>AIを作成する</Text>
      </TouchableOpacity>

      {/* Favorites Section */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>
          お気に入りAI ({favorites.length})
        </Text>
        {favorites.length === 0 ? (
          <View style={styles.emptyFavorites}>
            <Ionicons name="star-outline" size={36} color="#ccc" />
            <Text style={styles.emptyFavoritesText}>
              お気に入りのAIはまだありません
            </Text>
          </View>
        ) : (
          favorites.map((ai) => (
            <TouchableOpacity
              key={ai.id}
              style={styles.favoriteCard}
              onPress={() => router.push(`/ai/${ai.id}`)}
            >
              <View style={styles.favoriteAvatar}>
                <Text style={styles.favoriteAvatarText}>
                  {ai.display_name?.[0] || "?"}
                </Text>
              </View>
              <View style={styles.favoriteInfo}>
                <Text style={styles.favoriteName}>{ai.display_name}</Text>
                <Text style={styles.favoriteUsername}>@{ai.username}</Text>
              </View>
              <TouchableOpacity
                style={styles.removeFavoriteButton}
                onPress={() => handleRemoveFavorite(ai.id)}
              >
                <Ionicons name="star" size={22} color="#f0c040" />
              </TouchableOpacity>
            </TouchableOpacity>
          ))
        )}
      </View>

      {/* Sign Out */}
      <TouchableOpacity style={styles.signOutButton} onPress={handleSignOut}>
        <Ionicons name="log-out-outline" size={18} color="#e74c3c" />
        <Text style={styles.signOutText}>ログアウト</Text>
      </TouchableOpacity>

      <View style={{ height: 40 }} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f8f9fa" },
  center: { flex: 1, justifyContent: "center", alignItems: "center" },

  // Login prompt
  loginPrompt: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    paddingHorizontal: 32,
    backgroundColor: "#f8f9fa",
  },
  loginTitle: {
    fontSize: 22,
    fontWeight: "bold",
    color: "#1a1a2e",
    marginTop: 16,
  },
  loginMessage: {
    fontSize: 14,
    color: "#888",
    textAlign: "center",
    marginTop: 8,
    lineHeight: 22,
  },
  loginButton: {
    backgroundColor: "#1a1a2e",
    borderRadius: 12,
    paddingVertical: 14,
    paddingHorizontal: 40,
    marginTop: 24,
  },
  loginButtonText: { color: "#fff", fontSize: 16, fontWeight: "bold" },

  // Header
  header: {
    alignItems: "center",
    paddingVertical: 24,
    backgroundColor: "#fff",
  },
  avatar: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: "#1a1a2e",
    justifyContent: "center",
    alignItems: "center",
    marginBottom: 12,
  },
  avatarText: { fontSize: 28, fontWeight: "bold", color: "#fff" },
  username: { fontSize: 20, fontWeight: "bold", color: "#1a1a2e" },
  email: { fontSize: 13, color: "#999", marginTop: 2 },

  // Stats
  statsRow: {
    flexDirection: "row",
    backgroundColor: "#fff",
    paddingVertical: 16,
    paddingHorizontal: 8,
    borderTopWidth: 1,
    borderTopColor: "#f0f0f0",
  },
  statCard: {
    flex: 1,
    alignItems: "center",
    paddingVertical: 8,
  },
  statLabel: { fontSize: 12, color: "#999" },
  statValue: { fontSize: 18, fontWeight: "bold", color: "#1a1a2e", marginTop: 4 },

  // Create AI
  createAiButton: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#6c63ff",
    marginHorizontal: 16,
    marginTop: 16,
    borderRadius: 12,
    paddingVertical: 14,
  },
  createAiButtonText: {
    color: "#fff",
    fontSize: 16,
    fontWeight: "bold",
    marginLeft: 8,
  },

  // Section
  section: {
    backgroundColor: "#fff",
    marginTop: 8,
    paddingVertical: 16,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: "bold",
    color: "#1a1a2e",
    paddingHorizontal: 16,
    marginBottom: 12,
  },

  // Empty favorites
  emptyFavorites: {
    alignItems: "center",
    paddingVertical: 24,
  },
  emptyFavoritesText: { color: "#ccc", fontSize: 14, marginTop: 8 },

  // Favorite cards
  favoriteCard: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: "#f0f0f0",
  },
  favoriteAvatar: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: "#e8e8f0",
    justifyContent: "center",
    alignItems: "center",
    marginRight: 12,
  },
  favoriteAvatarText: { fontSize: 18, fontWeight: "bold", color: "#555" },
  favoriteInfo: { flex: 1 },
  favoriteName: { fontSize: 15, fontWeight: "bold", color: "#1a1a2e" },
  favoriteUsername: { fontSize: 12, color: "#999", marginTop: 1 },
  removeFavoriteButton: { padding: 8 },

  // Sign out
  signOutButton: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#fff",
    marginTop: 8,
    paddingVertical: 16,
  },
  signOutText: {
    fontSize: 15,
    color: "#e74c3c",
    marginLeft: 8,
    fontWeight: "600",
  },
});
