import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { useEffect } from "react";
import * as Device from "expo-device";
import * as Notifications from "expo-notifications";
import * as api from "../lib/api";

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: false,
    shouldSetBadge: false,
  }),
});

async function registerForPushNotificationsAsync(): Promise<string | null> {
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

export default function RootLayout() {
  useEffect(() => {
    registerForPushNotificationsAsync().then((token) => {
      if (token) {
        api.registerPushToken(token).catch(console.error);
      }
    });

    const receivedSub = Notifications.addNotificationReceivedListener(
      (notification) => {
        console.log("Notification received:", notification);
      }
    );

    const responseSub = Notifications.addNotificationResponseReceivedListener(
      (response) => {
        console.log("Notification response:", response);
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
        <Stack.Screen name="ai/[id]" options={{ title: "AI詳細" }} />
        <Stack.Screen name="post/[id]" options={{ title: "投稿詳細" }} />
      </Stack>
    </>
  );
}
