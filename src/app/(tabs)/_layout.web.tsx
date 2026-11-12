import { Tabs } from 'expo-router'
import { useI18n } from '@/lib/i18n'
import { useColors } from '@/lib/theme'

// Web preview only (local checks): a bottom bar like the native one.
export default function WebTabs() {
  const { t } = useI18n()
  const c = useColors()
  return (
    <Tabs screenOptions={{ headerShown: false, tabBarActiveTintColor: c.gold, tabBarStyle: { backgroundColor: c.surface, borderTopColor: c.line } }}>
      <Tabs.Screen name="home" options={{ title: t('app_tabHome') }} />
      <Tabs.Screen name="markets" options={{ title: t('app_tabMarkets') }} />
      <Tabs.Screen name="trade" options={{ title: t('app_tabTrade') }} />
      <Tabs.Screen name="games" options={{ title: t('app_tabGames') }} />
      <Tabs.Screen name="assets" options={{ title: t('app_tabAssets') }} />
    </Tabs>
  )
}
