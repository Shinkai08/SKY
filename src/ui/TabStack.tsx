import { router, Stack } from 'expo-router'
import { Pressable } from 'react-native'
import { useAuth } from '@/lib/auth'
import { tap } from '@/lib/haptics'
import { useColors } from '@/lib/theme'
import { Icon } from './kit'

/** Header button that opens "Me" (or login when signed out). */
export function MeButton() {
  const { me } = useAuth()
  const c = useColors()
  return (
    <Pressable hitSlop={10} onPress={() => { tap(); router.push(me ? '/me' : '/login') }} accessibilityLabel="me">
      <Icon name={me ? 'person.crop.circle.fill' : 'person.crop.circle'} size={26} color={c.gold} />
    </Pressable>
  )
}

/** A tab's stack: large-title root screen with the Me button, plus pushed screens. */
export function TabStack({ title, large = true, children }: { title: string; large?: boolean; children?: React.ReactNode }) {
  const c = useColors()
  return (
    <Stack screenOptions={{
      headerTintColor: c.gold, headerTitleStyle: { color: c.ink }, headerLargeTitleStyle: { color: c.ink },
      contentStyle: { backgroundColor: c.bg }, headerBackButtonDisplayMode: 'minimal',
      headerTransparent: false, headerStyle: { backgroundColor: c.bg }, headerShadowVisible: false,
    }}>
      <Stack.Screen name="index" options={{ title, headerLargeTitleEnabled: large, headerRight: () => <MeButton /> }} />
      {children}
    </Stack>
  )
}
