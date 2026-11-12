import { DarkTheme, DefaultTheme, Stack, ThemeProvider } from 'expo-router'
import * as SplashScreen from 'expo-splash-screen'
import { StatusBar } from 'expo-status-bar'
import { useEffect } from 'react'
import { AuthProvider, useAuth } from '@/lib/auth'
import { I18nProvider, useI18n } from '@/lib/i18n'
import { AccountProvider } from '@/lib/sky'
import { useColors } from '@/lib/theme'
import { Lock } from '@/ui/Lock'

SplashScreen.preventAutoHideAsync().catch(() => undefined)

export default function Root() {
  return (
    <I18nProvider>
      <AuthProvider>
        <AccountProvider>
          <App />
        </AccountProvider>
      </AuthProvider>
    </I18nProvider>
  )
}

function App() {
  const c = useColors()
  const { t } = useI18n()
  const { ready } = useAuth()
  useEffect(() => { if (ready) SplashScreen.hideAsync().catch(() => undefined) }, [ready])
  const base = c.dark ? DarkTheme : DefaultTheme
  const theme = { ...base, colors: { ...base.colors, background: c.bg, card: c.surface, primary: c.gold, text: c.ink, border: c.line } }
  const sheet = { presentation: 'formSheet' as const, sheetGrabberVisible: true, headerShown: false }
  return (
    <ThemeProvider value={theme}>
      <StatusBar style={c.dark ? 'light' : 'dark'} />
      <Lock>
        <Stack screenOptions={{ headerTintColor: c.gold, headerTitleStyle: { color: c.ink }, contentStyle: { backgroundColor: c.bg }, headerBackButtonDisplayMode: 'minimal' }}>
          <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
          <Stack.Screen name="login" options={{ presentation: 'modal', headerShown: false }} />
          <Stack.Screen name="me" options={{ title: t('app_me') }} />
          <Stack.Screen name="settings" options={{ title: t('settings') }} />
          <Stack.Screen name="vip" options={{ title: 'VIP' }} />
          <Stack.Screen name="privacy" options={{ title: t('privacyNotice') }} />
          <Stack.Screen name="predict" options={{ headerShown: false }} />
          <Stack.Screen name="community/index" options={{ title: t('community') }} />
          <Stack.Screen name="community/[id]" options={{ title: t('community') }} />
          <Stack.Screen name="user/[id]" options={{ title: '' }} />
          <Stack.Screen name="deposit" options={{ title: t('deposit') }} />
          <Stack.Screen name="pair" options={{ ...sheet, sheetAllowedDetents: [0.92] }} />
        </Stack>
      </Lock>
    </ThemeProvider>
  )
}
