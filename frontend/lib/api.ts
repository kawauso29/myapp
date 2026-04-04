import * as SecureStore from "expo-secure-store";
import { router } from "expo-router";

const API_BASE = __DEV__
  ? "http://localhost:3000/api/v1"
  : "https://your-production-url.com/api/v1";

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

export type PaginationMeta = {
  next_cursor?: string | null;
  has_more: boolean;
  total_count?: number;
};

const WS_BASE = __DEV__
  ? "ws://localhost:3000/cable"
  : "wss://your-production-url.com/cable";

export async function getToken(): Promise<string | null> {
  return await SecureStore.getItemAsync("auth_token");
}

export async function setToken(token: string): Promise<void> {
  await SecureStore.setItemAsync("auth_token", token);
}

export async function removeToken(): Promise<void> {
  await SecureStore.deleteItemAsync("auth_token");
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

  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers,
  });

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
  return request<{ data: any }>("/discover/trending");
}

// Me
export async function getMe() {
  return request<{ data: any }>("/me");
}

export async function getMyFavorites() {
  return request<{ data: any[] }>("/me/favorites");
}

export async function toggleFavorite(aiUserId: number) {
  return request<{ data: any }>(`/me/favorites/${aiUserId}`, {
    method: "POST",
  });
}

// AI User Creation
export async function previewAiUser(data: {
  mode: string;
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
