import { useEffect, useState, useRef, useCallback } from "react";
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  RefreshControl,
} from "react-native";
import { router } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import { getToken, connectNotificationWebSocket } from "../../lib/api";

export type NotificationItem = {
  id: string; // クライアント生成のユニークID
  type: "new_post" | "life_event" | "milestone";
  ai_user: any;
  post?: any;
  event_type?: string;
  milestone?: string;
  value?: number;
  message?: string;
  received_at: string;
  is_read: boolean;
};

// グローバルな未読数更新コールバック（タブバッジ用）
type BadgeCallback = (count: number) => void;
let badgeCallback: BadgeCallback | null = null;
export function setBadgeCallback(cb: BadgeCallback | null) {
  badgeCallback = cb;
}

export default function NotificationsScreen() {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [loading, setLoading] = useState(true);
  const [notifications, setNotifications] = useState<NotificationItem[]>([]);
  const wsRef = useRef<WebSocket | null>(null);

  useEffect(() => {
    checkAuth();
    return () => {
      wsRef.current?.close();
    };
  }, []);

  const checkAuth = async () => {
    const token = await getToken();
    if (token) {
      setIsLoggedIn(true);
      setupWebSocket();
    }
    setLoading(false);
  };

  const setupWebSocket = async () => {
    const ws = await connectNotificationWebSocket((msg) => {
      const item = buildNotificationItem(msg);
      if (!item) return;
      setNotifications((prev) => {
        const next = [item, ...prev];
        const unread = next.filter((n) => !n.is_read).length;
        badgeCallback?.(unread);
        return next;
      });
    });
    wsRef.current = ws;
  };

  const markAllRead = useCallback(() => {
    setNotifications((prev) => prev.map((n) => ({ ...n, is_read: true })));
    badgeCallback?.(0);
  }, []);

  const handlePress = useCallback((item: NotificationItem) => {
    setNotifications((prev) =>
      prev.map((n) => (n.id === item.id ? { ...n, is_read: true } : n))
    );
    setNotifications((prev) => {
      const unread = prev.filter((n) => !n.is_read).length;
      badgeCallback?.(unread);
      return prev;
    });

    if (item.type === "new_post" && item.post?.id) {
      router.push(`/post/${item.post.id}`);
    } else if (item.ai_user?.id) {
      router.push(`/ai/${item.ai_user.id}`);
    }
  }, []);

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#6c63ff" />
      </View>
    );
  }

  if (!isLoggedIn) {
    return (
      <View style={styles.center}>
        <Ionicons name="notifications-off-outline" size={48} color="#ccc" />
        <Text style={styles.emptyText}>
          ログインすると通知が届きます
        </Text>
        <TouchableOpacity
          style={styles.loginButton}
          onPress={() => router.push("/login")}
        >
          <Text style={styles.loginButtonText}>ログイン</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {notifications.length > 0 && (
        <TouchableOpacity style={styles.readAllButton} onPress={markAllRead}>
          <Text style={styles.readAllText}>すべて既読にする</Text>
        </TouchableOpacity>
      )}
      <FlatList
        data={notifications}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <NotificationRow item={item} onPress={handlePress} />
        )}
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Ionicons name="notifications-outline" size={48} color="#ccc" />
            <Text style={styles.emptyText}>
              通知はまだありません{"\n"}お気に入りのAIを登録しましょう
            </Text>
          </View>
        }
        refreshControl={
          <RefreshControl refreshing={false} onRefresh={() => {}} />
        }
      />
    </View>
  );
}

function NotificationRow({
  item,
  onPress,
}: {
  item: NotificationItem;
  onPress: (item: NotificationItem) => void;
}) {
  const { icon, label } = notificationMeta(item);
  const displayName = item.ai_user?.display_name || item.ai_user?.username || "AI";
  const timeAgo = formatTimeAgo(item.received_at);

  return (
    <TouchableOpacity
      style={[styles.row, !item.is_read && styles.rowUnread]}
      onPress={() => onPress(item)}
    >
      <View style={styles.iconWrap}>
        <Ionicons name={icon as any} size={22} color="#6c63ff" />
      </View>
      <View style={styles.rowContent}>
        <Text style={styles.rowTitle}>
          <Text style={styles.rowName}>{displayName}</Text>
          {"  "}
          <Text style={styles.rowLabel}>{label}</Text>
        </Text>
        {item.type === "new_post" && item.post?.content && (
          <Text style={styles.rowPreview} numberOfLines={2}>
            {item.post.content}
          </Text>
        )}
        {item.message && item.type !== "new_post" && (
          <Text style={styles.rowPreview} numberOfLines={1}>
            {item.message}
          </Text>
        )}
        <Text style={styles.rowTime}>{timeAgo}</Text>
      </View>
      {!item.is_read && <View style={styles.unreadDot} />}
    </TouchableOpacity>
  );
}

function notificationMeta(item: NotificationItem): {
  icon: string;
  label: string;
} {
  switch (item.type) {
    case "new_post":
      return { icon: "create-outline", label: "が投稿しました" };
    case "life_event":
      return { icon: "sparkles-outline", label: "にライフイベントが発生" };
    case "milestone":
      return { icon: "trophy-outline", label: "がマイルストーン達成" };
    default:
      return { icon: "notifications-outline", label: "" };
  }
}

let notifCounter = 0;
function buildNotificationItem(msg: any): NotificationItem | null {
  if (!msg.type) return null;
  if (!["new_post", "life_event", "milestone"].includes(msg.type)) return null;

  notifCounter += 1;
  return {
    id: `${Date.now()}-${notifCounter}`,
    type: msg.type,
    ai_user: msg.ai_user ?? null,
    post: msg.post ?? null,
    event_type: msg.event_type ?? null,
    milestone: msg.milestone ?? null,
    value: msg.value ?? null,
    message: msg.message ?? null,
    received_at: new Date().toISOString(),
    is_read: false,
  };
}

function formatTimeAgo(dateStr: string): string {
  const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
  if (diff < 60) return `${diff}秒前`;
  if (diff < 3600) return `${Math.floor(diff / 60)}分前`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}時間前`;
  return `${Math.floor(diff / 86400)}日前`;
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#f8f9fa" },
  center: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    gap: 16,
    paddingHorizontal: 32,
  },
  emptyContainer: {
    paddingTop: 80,
    alignItems: "center",
    gap: 12,
    paddingHorizontal: 32,
  },
  emptyText: {
    color: "#999",
    fontSize: 14,
    textAlign: "center",
    lineHeight: 22,
  },
  loginButton: {
    backgroundColor: "#6c63ff",
    paddingHorizontal: 32,
    paddingVertical: 12,
    borderRadius: 24,
  },
  loginButtonText: { color: "#fff", fontWeight: "bold", fontSize: 15 },
  readAllButton: {
    paddingHorizontal: 16,
    paddingVertical: 10,
    alignItems: "flex-end",
    borderBottomWidth: 1,
    borderBottomColor: "#f0f0f0",
    backgroundColor: "#fff",
  },
  readAllText: { color: "#6c63ff", fontSize: 13 },
  row: {
    flexDirection: "row",
    alignItems: "flex-start",
    backgroundColor: "#fff",
    padding: 14,
    borderBottomWidth: 1,
    borderBottomColor: "#f0f0f0",
  },
  rowUnread: { backgroundColor: "#f5f4ff" },
  iconWrap: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: "#ede9fe",
    justifyContent: "center",
    alignItems: "center",
    marginRight: 12,
    flexShrink: 0,
  },
  rowContent: { flex: 1 },
  rowTitle: { fontSize: 14, color: "#333", lineHeight: 20 },
  rowName: { fontWeight: "bold" },
  rowLabel: { fontWeight: "normal" },
  rowPreview: {
    fontSize: 13,
    color: "#666",
    marginTop: 4,
    lineHeight: 18,
  },
  rowTime: { fontSize: 11, color: "#aaa", marginTop: 4 },
  unreadDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: "#6c63ff",
    marginTop: 6,
    flexShrink: 0,
  },
});
