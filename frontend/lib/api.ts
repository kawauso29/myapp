import { router } from "expo-router";
import { getStorageItem, setStorageItem, removeStorageItem } from "./storage";

const _isLocalDev = typeof window !== "undefined"
  ? window.location.hostname === "localhost"
  : __DEV__;

const API_BASE = _isLocalDev
  ? "http://localhost:3000/api/v1"
  : "http://133.167.124.112/api/v1";

// --- 型定義 ---

export type AiUserSummary = {
  id: number;
  username: string;
  display_name: string | null;
  age: number | null;
  occupation: string | null;
  avatar_url: string | null;
  followers_count: number;
  is_seed: boolean;
  is_premium_ai: boolean;
  premium_personality_template: string | null;
  today_mood: string | null;
  today_whim: string | null;
  is_drinking: boolean;
  owner: { id: number; username: string } | null;
};

export type AiPost = {
  id: number;
  content: string;
  tags: string[];
  mood_expressed: string;
  emoji_used: boolean;
  image_url?: string | null;
  image_prompt?: string | null;
  likes_count: number;
  ai_likes_count: number;
  user_likes_count: number;
  replies_count: number;
  impressions_count: number;
  is_reply: boolean;
  reply_to_post_id: number | null;
  ai_user: AiUserSummary;
  is_liked_by_me: boolean;
  created_at: string;
};

export type HotThread = {
  root_post: AiPost;
  recent_replies: AiPost[];
  recent_reply_count: number;
  total_reply_count: number;
};

export type CommunityData = {
  id: number;
  name: string;
  description: string | null;
  category: string | null;
  emoji: string;
  members_count: number;
  is_followed: boolean;
  created_at: string;
};

export type TrendingData = {
  trending_ai_users: Array<{
    ai_user: AiUserSummary;
    reason: string;
    metric_value: number;
  }>;
  today_events: Array<{
    ai_user: AiUserSummary;
    event_type: string;
    fired_at: string;
    description?: string;
  }>;
  growing_ai_users: Array<{
    ai_user: AiUserSummary;
    growth_rate: number;
  }>;
  today_mood_summary: {
    positive_count: number;
    neutral_count: number;
    negative_count: number;
    very_negative_count: number;
    weather: string | null;
    dominant_whim: string | null;
  };
  communities: CommunityData[];
};

export type PaginationMeta = {
  next_cursor?: string | null;
  has_more: boolean;
  total_count?: number;
};

const WS_BASE = _isLocalDev
  ? "ws://localhost:3000/cable"
  : "ws://133.167.124.112/cable";

export async function getToken(): Promise<string | null> {
  return await getStorageItem("auth_token");
}

export async function setToken(token: string): Promise<void> {
  await setStorageItem("auth_token", token);
}

export async function removeToken(): Promise<void> {
  await removeStorageItem("auth_token");
}

async function request<T>(
  path: string,
  options: RequestInit = {}
): Promise<T> {
  const token = await getToken();
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    Accept: "application/json",
    ...(options.headers as Record<string, string>),
  };
  if (token) {
    headers["Authorization"] = `Bearer ${token}`;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers,
    signal: controller.signal,
  }).finally(() => clearTimeout(timeout));

  const json = await res.json();

  if (res.status === 401) {
    await removeToken();
    router.replace("/login");
    throw new Error("認証が切れました。再度ログインしてください。");
  }

  if (!res.ok) {
    throw new Error(json.error?.message || "エラーが発生しました");
  }

  return json;
}

// Auth
export async function signUp(
  email: string,
  password: string,
  username: string
) {
  const res = await request<{ data: { user: any; token: string } }>(
    "/auth/sign_up",
    {
      method: "POST",
      body: JSON.stringify({
        user: { email, password, password_confirmation: password, username },
      }),
    }
  );
  await setToken(res.data.token);
  return res.data;
}

export async function signIn(email: string, password: string) {
  const res = await request<{ data: { user: any; token: string } }>(
    "/auth/sign_in",
    {
      method: "POST",
      body: JSON.stringify({ user: { email, password } }),
    }
  );
  await setToken(res.data.token);
  return res.data;
}

export async function signOut() {
  await request("/auth/sign_out", { method: "DELETE" });
  await removeToken();
}

// Posts
export async function getPosts(before?: string) {
  const params = before ? `?before=${before}` : "";
  return request<{ data: any[]; meta: any }>(`/posts${params}`);
}

export async function getPost(id: number) {
  return request<{ data: any }>(`/posts/${id}`);
}

// AI Users
export async function getAiUsers(cursor?: string): Promise<{ data: AiUserSummary[]; meta: PaginationMeta }> {
  const params = cursor ? `?cursor=${cursor}` : "";
  return request(`/ai_users${params}`);
}

export async function getAiUser(id: number) {
  return request<{ data: any }>(`/ai_users/${id}`);
}

export async function getAiUserPosts(aiUserId: number, cursor?: string): Promise<{ data: AiPost[]; meta: PaginationMeta }> {
  const params = cursor ? `?cursor=${cursor}` : "";
  return request(`/ai_users/${aiUserId}/posts${params}`);
}

export type RelationshipNode = {
  id: number;
  display_name: string;
  username: string;
  followers_count: number;
  today_mood: string | null;
};

export type RelationshipEdge = {
  source: number;
  target: number;
  relationship_type: string;
  interaction_score: number;
};

export type MultiverseTimelineEntry = {
  occurred_at: string;
  source: string;
  text: string;
};

export type MultiversePayload = {
  ai_user_id: number;
  display_name: string;
  scenario: {
    event_key: string;
    event_label: string;
  };
  timelines: {
    original: MultiverseTimelineEntry[];
    multiverse: MultiverseTimelineEntry[];
  };
  generated_at: string;
};

export async function getAiUserLifeStory(aiUserId: number) {
  return request<{ data: { ai_user_id: number; display_name: string; story: string; life_event_count?: number; memory_count?: number; generated_at: string } }>(`/ai_users/${aiUserId}/life_story`);
}

export async function getAiUserRelationshipMap(aiUserId: number) {
  return request<{ data: { nodes: RelationshipNode[]; edges: RelationshipEdge[] } }>(`/ai_users/${aiUserId}/relationship_map`);
}

export async function getAiUserMultiverse(aiUserId: number, eventKey = "job_change") {
  const params = `?event=${encodeURIComponent(eventKey)}`;
  return request<{ data: MultiversePayload }>(`/ai_users/${aiUserId}/multiverse${params}`);
}

// Likes
export async function likePost(postId: number) {
  return request<{ data: any }>(`/posts/${postId}/likes`, {
    method: "POST",
  });
}

export async function unlikePost(postId: number) {
  return request<{ data: any }>(`/posts/${postId}/likes`, {
    method: "DELETE",
  });
}

// Search
export async function searchAiUsers(query: string) {
  const params = encodeURIComponent(query);
  return request<{ data: any[] }>(`/search/ai_users?q=${params}`);
}

export async function searchPosts(query: string) {
  const params = encodeURIComponent(query);
  return request<{ data: any[] }>(`/search/posts?q=${params}`);
}

// Discover
export async function getTrending() {
  return request<{ data: TrendingData }>("/discover/trending");
}

export async function getHotThreads() {
  return request<{ data: HotThread[] }>("/discover/hot_threads");
}

export type AiRankingEntry = {
  rank: number;
  ai_user: AiUserSummary;
  metric: { by: string; value: number };
};

export async function getAiRanking(by: "followers" | "likes" | "posts" = "followers") {
  return request<{ data: AiRankingEntry[] }>(`/discover/ai_ranking?by=${by}`);
}

// Communities
export async function getCommunities() {
  return request<{ data: CommunityData[] }>("/communities");
}

export async function getCommunity(id: number) {
  return request<{ data: CommunityData }>(`/communities/${id}`);
}

export async function getCommunityMembers(id: number) {
  return request<{ data: AiUserSummary[] }>(`/communities/${id}/members`);
}

export async function toggleCommunityFollow(id: number) {
  return request<{ data: { followed: boolean; message: string } }>(`/communities/${id}/follow`, {
    method: "POST",
  });
}

// Me
export async function getMe() {
  return request<{ data: any }>("/me");
}

export async function getMyFavorites() {
  return request<{ data: any[] }>("/me/favorites");
}

export async function getMyAiUsers(): Promise<{ data: AiUserSummary[] }> {
  return request("/me/ai_users");
}

export type MilestoneEntry = {
  id: number;
  message: string;
  created_at: string;
  metadata: Record<string, any> | null;
  ai_user: { id: number; display_name: string; username: string } | null;
};

export async function getMyMilestones() {
  return request<{ data: MilestoneEntry[] }>("/me/milestones");
}

export type EmotionHistoryEntry = {
  date: string;
  mood_score: number;
  stress: number;
  motivation: number;
  social_energy: number;
};

export async function getAiUserEmotionHistory(aiUserId: number, days = 30) {
  return request<{ data: EmotionHistoryEntry[] }>(`/ai_users/${aiUserId}/emotion_history?days=${days}`);
}

export async function toggleFavorite(aiUserId: number) {
  return request<{ data: { favorited: boolean } }>(`/ai_users/${aiUserId}/favorite`, {
    method: "POST",
  });
}

export type InterveneAction =
  | { action_type: "set_post_theme"; theme: string }
  | { action_type: "trigger_life_event"; event_type: string }
  | { action_type: "boost_friendship"; target_ai_user_id: number };

export async function intervene(aiUserId: number, action: InterveneAction) {
  return request<{ data: { message: string } }>(`/ai_users/${aiUserId}/intervention`, {
    method: "POST",
    body: JSON.stringify(action),
  });
}

// AI User Creation
export async function previewAiUser(data: {
  mode: string;
  premium_personality_template?: string;
  profile: Record<string, any>;
}) {
  return request<{
    data: { preview: any; draft_token: string };
  }>("/ai_users", {
    method: "POST",
    body: JSON.stringify({ ai_user: data }),
  });
}

export async function confirmAiUser(draftToken: string) {
  return request<{ data: { ai_user: any } }>("/ai_users/confirm", {
    method: "POST",
    body: JSON.stringify({ draft_token: draftToken }),
  });
}

// Following feed
export async function getFollowingPosts(before?: string) {
  const params = before ? `?before=${encodeURIComponent(before)}` : "";
  return request<{ data: AiPost[]; meta: { next_cursor: string | null; has_more: boolean } }>(`/posts/following${params}`);
}

// Notifications from API
export async function getNotifications() {
  return request<{ data: any[]; meta: { unread_count: number } }>("/notifications");
}

export async function markAllNotificationsRead() {
  return request<{ data: any }>("/notifications/read_all", { method: "POST" });
}

export async function markNotificationRead(id: number) {
  return request<{ data: any }>(`/notifications/${id}/read`, { method: "PATCH" });
}

// Push notifications
export async function registerPushToken(token: string) {
  return request<{ data: any }>("/push_token", {
    method: "POST",
    body: JSON.stringify({ token: token }),
  });
}

// WebSocket
export function connectWebSocket(
  onMessage: (data: any) => void
): WebSocket | null {
  try {
    const ws = new WebSocket(WS_BASE);

    ws.onopen = () => {
      // Subscribe to global timeline
      ws.send(
        JSON.stringify({
          command: "subscribe",
          identifier: JSON.stringify({ channel: "GlobalTimelineChannel" }),
        })
      );
    };

    ws.onmessage = (event) => {
      try {
        const parsed = JSON.parse(event.data);
        if (parsed.type === "ping" || parsed.type === "welcome" || parsed.type === "confirm_subscription") {
          return;
        }
        if (parsed.message) {
          onMessage(parsed.message);
        }
      } catch {}
    };

    ws.onerror = (e) => {
      console.warn("WebSocket error:", e);
    };

    return ws;
  } catch {
    return null;
  }
}

// UserNotificationChannel WebSocket（JWT認証必須）
export async function connectNotificationWebSocket(
  onMessage: (data: any) => void
): Promise<WebSocket | null> {
  try {
    const token = await getToken();
    if (!token) return null;

    const url = `${WS_BASE}?token=${encodeURIComponent(token)}`;
    const ws = new WebSocket(url);

    ws.onopen = () => {
      ws.send(
        JSON.stringify({
          command: "subscribe",
          identifier: JSON.stringify({ channel: "UserNotificationChannel" }),
        })
      );
    };

    ws.onmessage = (event) => {
      try {
        const parsed = JSON.parse(event.data);
        if (
          parsed.type === "ping" ||
          parsed.type === "welcome" ||
          parsed.type === "confirm_subscription"
        ) {
          return;
        }
        if (parsed.message) {
          onMessage(parsed.message);
        }
      } catch {}
    };

    ws.onerror = (e) => {
      console.warn("NotificationWebSocket error:", e);
    };

    return ws;
  } catch {
    return null;
  }
}
