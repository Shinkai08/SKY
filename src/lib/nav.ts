import { router } from 'expo-router'
import { useI18n } from './i18n'
import { tradeTarget } from './prefs'

/** Switch to the Trade tab on a market (spot or perpetual). */
export function openTrade(sym: string, spot: boolean) {
  tradeTarget.set({ sym, spot })
  router.navigate('/trade')
}

/** Price with enough digits for anything from 0.0000123 to 70,000. */
export function usePriceFmt() {
  const { num } = useI18n()
  return (p: number) => {
    if (!p) return '—'
    if (p >= 100) return num(p, 2)
    if (p >= 1) return num(p, 4)
    const d = Math.min(10, Math.max(4, 3 - Math.floor(Math.log10(p))))
    return num(p, d)
  }
}
