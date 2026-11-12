import { NativeTabs } from 'expo-router/native-tabs'
import { useI18n } from '@/lib/i18n'
import { useColors } from '@/lib/theme'

// Native iOS tab bar (Liquid Glass on iOS 26). Each tab is a stack folder.
export default function Tabs() {
  const { t } = useI18n()
  const c = useColors()
  return (
    <NativeTabs tintColor={c.gold} minimizeBehavior="onScrollDown">
      <NativeTabs.Trigger name="home">
        <NativeTabs.Trigger.Label>{t('app_tabHome')}</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf={{ default: 'house', selected: 'house.fill' }} md="home" />
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="markets">
        <NativeTabs.Trigger.Label>{t('app_tabMarkets')}</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf="chart.line.uptrend.xyaxis" md="show_chart" />
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="trade">
        <NativeTabs.Trigger.Label>{t('app_tabTrade')}</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf={{ default: 'arrow.left.arrow.right.circle', selected: 'arrow.left.arrow.right.circle.fill' }} md="swap_horiz" />
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="games">
        <NativeTabs.Trigger.Label>{t('app_tabGames')}</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf={{ default: 'gamecontroller', selected: 'gamecontroller.fill' }} md="sports_esports" />
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="assets">
        <NativeTabs.Trigger.Label>{t('app_tabAssets')}</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf={{ default: 'wallet.pass', selected: 'wallet.pass.fill' }} md="account_balance_wallet" />
      </NativeTabs.Trigger>
    </NativeTabs>
  )
}
