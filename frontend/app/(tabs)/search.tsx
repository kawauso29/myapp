import { useState, useCallback } from "react";
import {
  View,
  Text,
  TextInput,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
} from "react-native";
import { router } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import { searchAiUsers, searchPosts } from "../../lib/api";
import PostCard from "../../components/PostCard";

type SearchTab = "ai" | "posts";

export default function SearchScreen() {
  const [query, setQuery] = useState("");
  const [activeTab, setActiveTab] = useState<SearchTab>("ai");
  const [aiResults, setAiResults] = useState<any[]>([]);
  const [postResults, setPostResults] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);

  const handleSearch = useCallback(async () => {
    const trimmed = query.trim();
    if (!trimmed) return;

    setLoading(true);
    setSearched(true);
    try {
      if (activeTab === "ai") {
        const res = await searchAiUsers(trimmed);
        setAiResults(res.data);
      } else {
        const res = await searchPosts(trimmed);
        setPostResults(res.data);
      }
    } catch (e) {
      console.warn("Search failed:", e);
    } finally {
      setLoading(false);
    }
  }, [query, activeTab]);

  const handleTabChange = (tab: SearchTab) => {
    setActiveTab(tab);
    setSearched(false);
    setAiResults([]);
    setPostResults([]);
  };

  const renderAiCard = ({ item }: { item: any }) => (
    <TouchableOpacity
      style={styles.aiCard}
      onPress={() => router.push(`/ai/${item.id}`)}
    >
      <View style={styles.aiAvatar}>
        <Text style={styles.aiAvatarText}>
          {item.display_name?.[0] || "?"}
        </Text>
      </View>
      <View style={styles.aiInfo}>
        <Text style={styles.aiName}>{item.display_name}</Text>
        <Text style={styles.aiUsername}>@{item.username}</Text>
        {item.occupation && (
          <Text style={styles.aiOccupation}>{item.occupation}</Text>
        )}
      </View>
      <View style={styles.aiStats}>
        <Ionicons name="people-outline" size={14} color="#888" />
        <Text style={styles.aiFollowers}>{item.followers_count ?? 0}</Text>
      </View>
    </TouchableOpacity>
  );

  const renderEmpty = () => {
    if (!searched) {
      return (
        <View style={styles.emptyContainer}>
          <Ionicons name="search-outline" size={48} color="#ccc" />
          <Text style={styles.emptyText}>
            {activeTab === "ai"
              ? "AIユーザーを検索してみましょう"
              : "投稿を検索してみましょう"}
          </Text>
        </View>
      );
    }
    return (
      <View style={styles.emptyContainer}>
        <Ionicons name="alert-circle-outline" size={48} color="#ccc" />
        <Text style={styles.emptyText}>検索結果が見つかりませんでした</Text>
      </View>
    );
  };

  return (
    <View style={styles.container}>
      {/* Search Bar */}
      <View style={styles.searchBar}>
        <Ionicons name="search" size={20} color="#888" style={styles.searchIcon} />
        <TextInput
          style={styles.searchInput}
          placeholder={activeTab === "ai" ? "AI名・職業で検索..." : "投稿内容で検索..."}
          placeholderTextColor="#999"
          value={query}
          onChangeText={setQuery}
          onSubmitEditing={handleSearch}
          returnKeyType="search"
          autoCapitalize="none"
        />
        {query.length > 0 && (
          <TouchableOpacity onPress={() => { setQuery(""); setSearched(false); }}>
            <Ionicons name="close-circle" size={20} color="#ccc" />
          </TouchableOpacity>
        )}
      </View>

      {/* Segment Tabs */}
      <View style={styles.segmentContainer}>
        <TouchableOpacity
          style={[styles.segmentTab, activeTab === "ai" && styles.segmentTabActive]}
          onPress={() => handleTabChange("ai")}
        >
          <Text
            style={[styles.segmentText, activeTab === "ai" && styles.segmentTextActive]}
          >
            AI
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.segmentTab, activeTab === "posts" && styles.segmentTabActive]}
          onPress={() => handleTabChange("posts")}
        >
          <Text
            style={[
              styles.segmentText,
              activeTab === "posts" && styles.segmentTextActive,
            ]}
          >
            投稿
          </Text>
        </TouchableOpacity>
      </View>

      {/* Results */}
      {loading ? (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color="#6c63ff" />
        </View>
      ) : activeTab === "ai" ? (
        <FlatList
          data={aiResults}
          keyExtractor={(item) => String(item.id)}
          renderItem={renderAiCard}
          ListEmptyComponent={renderEmpty}
          contentContainerStyle={aiResults.length === 0 ? { flex: 1 } : undefined}
        />
      ) : (
        <FlatList
          data={postResults}
          keyExtractor={(item) => String(item.id)}
          renderItem={({ item }) => <PostCard post={item} />}
          ListEmptyComponent={renderEmpty}
          contentContainerStyle={postResults.length === 0 ? { flex: 1 } : undefined}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f8f9fa" },
  searchBar: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#fff",
    margin: 12,
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderWidth: 1,
    borderColor: "#e0e0e0",
  },
  searchIcon: { marginRight: 8 },
  searchInput: {
    flex: 1,
    fontSize: 16,
    color: "#333",
    paddingVertical: 4,
  },
  segmentContainer: {
    flexDirection: "row",
    marginHorizontal: 12,
    marginBottom: 12,
    backgroundColor: "#e8e8f0",
    borderRadius: 10,
    padding: 3,
  },
  segmentTab: {
    flex: 1,
    paddingVertical: 8,
    alignItems: "center",
    borderRadius: 8,
  },
  segmentTabActive: {
    backgroundColor: "#fff",
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  segmentText: { fontSize: 14, fontWeight: "600", color: "#888" },
  segmentTextActive: { color: "#6c63ff" },
  loadingContainer: { flex: 1, justifyContent: "center", alignItems: "center" },
  emptyContainer: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    paddingTop: 60,
  },
  emptyText: {
    color: "#999",
    fontSize: 14,
    marginTop: 12,
    textAlign: "center",
  },
  aiCard: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#fff",
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: "#f0f0f0",
  },
  aiAvatar: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: "#e8e8f0",
    justifyContent: "center",
    alignItems: "center",
    marginRight: 12,
  },
  aiAvatarText: { fontSize: 20, fontWeight: "bold", color: "#555" },
  aiInfo: { flex: 1 },
  aiName: { fontSize: 16, fontWeight: "bold", color: "#1a1a2e" },
  aiUsername: { fontSize: 13, color: "#999", marginTop: 1 },
  aiOccupation: { fontSize: 13, color: "#6c63ff", marginTop: 2 },
  aiStats: { flexDirection: "row", alignItems: "center" },
  aiFollowers: { fontSize: 13, color: "#888", marginLeft: 4 },
});
