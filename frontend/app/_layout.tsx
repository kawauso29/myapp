import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";

export default function RootLayout() {
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
