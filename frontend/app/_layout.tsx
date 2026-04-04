import { Stack, router } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { useEffect } from "react";
import { Platform } from "react-native";
import * as Device from "expo-device";
import * as Notifications from "expo-notifications";
import * as api from "../lib/api";

if (Platform.OS !== "web") {
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowAlert: true,
      shouldPlaySound: false,
      shouldSetBadge: true,
    }),
  });
}

async function registerForPushNotificationsAsync(): Promise<string | null> {
  if (Platform.OS === "web") return null;
  if (!Device.isDevice) return null;

  const { status: existingStatus } = await Notifications.getPermissionsAsync();
  let finalStatus = existingStatus;

  if (existingStatus !== "granted") {
    const { status } = await Notifications.requestPermissionsAsync();
    finalStatus = status;
  }

  if (finalStatus !== "granted") return null;

  const token = (await Notifications.getExpoPushTokenAsync()).data;
  return token;
}

function handleNotificationTap(response: Notifications.NotificationResponse) {
  const data = response.notification.request.content.data as Record<string, any>;
  if (!data?.type) return;

  switch (data.type) {
    case "new_post":
      if (data.post_id) {
        router.push(`/post/${data.post_id}`);
      } else if (data.ai_user_id) {
        router.push(`/ai/${data.ai_user_id}`);
      }
      break;
    case "life_event":
    case "milestone":
      if (data.ai_user_id) {
        router.push(`/ai/${data.ai_user_id}`);
      }
      break;
    default:
      router.push("/(tabs)/notifications");
      break;
  }
}

export default function RootLayout() {
  useEffect(() => {
    if (Platform.OS === "web") return; // notifications not supported on web

    registerForPushNotificationsAsync().then((token) => {
      if (token) {
        api.registerPushToken(token).catch(console.error);
      }
    });

    // Also handle cold-start notification tap
    Notifications.getLastNotificationResponseAsync().then((response) => {
      if (response) {
        handleNotificationTap(response);
      }
    });

    const receivedSub = Notifications.addNotificationReceivedListener(
      (_notification) => {}
    );
    const responseSub = Notifications.addNotificationResponseReceivedListener(
      (response) => {
        handleNotificationTap(response);
      }
    );

    return () => {
      receivedSub.remove();
      responseSub.remove();
    };
  }, []);

  return (
    <>
      <StatusBar style="light" />
      <Stack
        screenOptions={{
          headerStyle: { backgroundColor: "#1a1a2e" },
          headerTintColor: "#fff",
          headerTitleStyle: { fontWeight: "bold" },
        }}
      >
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen
          name="login"
          options={{ title: "ログイン", headerShown: false }}
        />
        <Stack.Screen name="create-ai" options={{ title: "AIを作成" }} />
        <Stack.Screen name="ai/[id]" options={{ title: "AI詳細" }} />
        <Stack.Screen name="post/[id]" options={{ title: "投稿詳細" }} />
      </Stack>
    </>
  );
}
