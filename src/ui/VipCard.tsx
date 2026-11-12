import { Image } from 'expo-image'
import { StyleSheet, Text, View } from 'react-native'
import { useI18n } from '@/lib/i18n'

// VIP 悦享卡: the website's layered card (metal art + emblem + live text).
export type CardTier = 'bronze' | 'silver' | 'gold' | 'platinum' | 'blackgold'
export const CARD_TIERS: { tier: CardTier; en: string; levels: [number, number]; tint: string }[] = [
  { tier: 'bronze', en: 'BRONZE', levels: [0, 1], tint: 'rgb(241,190,157)' },
  { tier: 'silver', en: 'SILVER', levels: [2, 3], tint: 'rgb(226,233,243)' },
  { tier: 'gold', en: 'GOLD', levels: [4, 5], tint: 'rgb(255,224,150)' },
  { tier: 'platinum', en: 'PLATINUM', levels: [6, 7], tint: 'rgb(219,238,253)' },
  { tier: 'blackgold', en: 'BLACK GOLD', levels: [8, 9], tint: 'rgb(245,213,143)' },
]
export const cardFor = (level: number) => CARD_TIERS.find(c => level >= c.levels[0] && level <= c.levels[1]) ?? CARD_TIERS[0]
export const tierName = (level: number, t: (k: string) => string) => (level === 0 ? t('regular') : `VIP ${level}`)

const ART: Record<CardTier, number> = {
  bronze: require('@/assets/vip/bronze.webp'), silver: require('@/assets/vip/silver.webp'), gold: require('@/assets/vip/gold.webp'),
  platinum: require('@/assets/vip/platinum.webp'), blackgold: require('@/assets/vip/blackgold.webp'),
}

export function JoyCard({ level, width = 300 }: { level: number; width?: number }) {
  const { t } = useI18n()
  const c = cardFor(level)
  const k = width / 300 // text scale
  return (
    <View style={[styles.card, { width, height: width * 0.625, borderRadius: 14 * k }]}>
      <Image source={ART[c.tier]} style={StyleSheet.absoluteFill} contentFit="cover" />
      <View style={[StyleSheet.absoluteFill, styles.shade]} />
      <View style={[styles.frame, { borderColor: c.tint, borderRadius: 10 * k, margin: 8 * k }]} />
      <Image source={require('@/assets/vip/emblem.png')} style={{ position: 'absolute', right: 18 * k, top: 18 * k, width: 40 * k, height: 40 * k }} contentFit="contain" />
      <View style={{ position: 'absolute', left: 20 * k, top: 18 * k }}>
        <Text style={[styles.word, { fontSize: 22 * k, color: c.tint }]}>SKY</Text>
        <Text style={{ fontSize: 13 * k, color: '#fff', fontWeight: '700', marginTop: 2 }}>{t('vipJoyCard')}</Text>
      </View>
      <View style={{ position: 'absolute', left: 20 * k, bottom: 16 * k, right: 20 * k, flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'space-between' }}>
        <View>
          <Text style={{ fontSize: 16 * k, color: c.tint, fontWeight: '800' }}>{t(`vipTier_${c.tier}`)}</Text>
          <Text style={{ fontSize: 9 * k, color: 'rgba(255,255,255,.75)', letterSpacing: 2 }}>{c.en} · SKYLINE EXCHANGE</Text>
        </View>
        <Text style={{ fontSize: 15 * k, color: '#fff', fontWeight: '800' }}>{tierName(level, t)}</Text>
      </View>
    </View>
  )
}

const styles = StyleSheet.create({
  card: { overflow: 'hidden', backgroundColor: '#222' },
  shade: { backgroundColor: 'rgba(0,0,0,0.18)' },
  frame: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, borderWidth: 1, opacity: 0.55 },
  word: { fontWeight: '900', letterSpacing: 4 },
})
