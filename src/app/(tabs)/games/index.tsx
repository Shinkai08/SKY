import { router } from 'expo-router'
import type { SFSymbol } from 'expo-symbols'
import { useState } from 'react'
import { Pressable, StyleSheet, View } from 'react-native'
import Svg, { Defs, LinearGradient, Rect, Stop } from 'react-native-svg'
import { api } from '@/lib/api'
import { tap } from '@/lib/haptics'
import { useI18n } from '@/lib/i18n'
import { usePoll } from '@/lib/sky'
import { Icon, Screen, Txt } from '@/ui/kit'

// Game lobby: 3×3 square tiles. Crash and Blackjack are live; the rest are coming.
const GAMES: { id: string; icon: SFSymbol; route?: '/games/crash' | '/games/blackjack'; colors: [string, string, string] }[] = [
  { id: 'crash', icon: 'paperplane.fill', route: '/games/crash', colors: ['#f0c060', '#c9771c', '#7a3410'] },
  { id: 'blackjack', icon: 'suit.spade.fill', route: '/games/blackjack', colors: ['#2fbf7a', '#137046', '#0a3b25'] },
  { id: 'limbo', icon: 'scope', colors: ['#3cc98a', '#14805a', '#0b4a35'] },
  { id: 'dice', icon: 'dice.fill', colors: ['#6f8dff', '#3b4fd1', '#1f2a7a'] },
  { id: 'mines', icon: 'burst.fill', colors: ['#ff7a7a', '#c23a4c', '#6d1a2c'] },
  { id: 'plinko', icon: 'triangle.fill', colors: ['#e07cff', '#9b3fd0', '#4d1b74'] },
  { id: 'hilo', icon: 'arrow.up.arrow.down', colors: ['#5fd7e8', '#1d93b0', '#0c4c63'] },
  { id: 'wheel', icon: 'circle.circle.fill', colors: ['#ffd166', '#e0902a', '#8a4d0e'] },
  { id: 'tower', icon: 'building.columns.fill', colors: ['#b38cff', '#6a4bc4', '#33236b'] },
]

export default function Games() {
  const { t } = useI18n()
  const [players, setPlayers] = useState<Record<string, number>>({})
  usePoll(() => {
    for (const id of ['crash', 'blackjack']) {
      api<{ players: number }>(`/games/${id}`).then(v => setPlayers(p => ({ ...p, [id]: v.players }))).catch(() => undefined)
    }
  }, 3000, [])
  return (
    <Screen>
      <View style={styles.grid}>
        {GAMES.map(g => (
          <Pressable key={g.id} disabled={!g.route} onPress={() => { tap(); if (g.route) router.push(g.route) }}
            style={({ pressed }) => [styles.tile, pressed && { transform: [{ scale: 0.97 }] }]}>
            <Svg style={StyleSheet.absoluteFill} viewBox="0 0 100 100" preserveAspectRatio="none">
              <Defs>
                <LinearGradient id={`g${g.id}`} x1="0" y1="0" x2="1" y2="1">
                  <Stop offset="0" stopColor={g.colors[0]} /><Stop offset="0.55" stopColor={g.colors[1]} /><Stop offset="1" stopColor={g.colors[2]} />
                </LinearGradient>
              </Defs>
              <Rect width="100" height="100" fill={`url(#g${g.id})`} />
            </Svg>
            {g.route && players[g.id] !== undefined && (
              <View style={[styles.badge, { right: 6 }]}><Icon name="person.fill" size={9} color="#fff" /><Txt v="tiny" bold style={{ color: '#fff' }}>{players[g.id]}</Txt></View>
            )}
            {!g.route && <View style={[styles.badge, { left: 6 }]}><Txt v="tiny" bold style={{ color: '#fff' }}>{t('gm_soon')}</Txt></View>}
            <View style={{ opacity: g.route ? 1 : 0.6, alignItems: 'center', gap: 4 }}>
              <Icon name={g.icon} size={34} color="#fff" />
              <Txt bold style={styles.name} center lines={1}>{t(`gm_${g.id}`)}</Txt>
            </View>
            <Txt v="tiny" style={{ color: 'rgba(255,255,255,.8)' }}>{g.route ? t('gm_original') : 'SKY'}</Txt>
          </Pressable>
        ))}
      </View>
      <Txt v="tiny" tone="muted" center>{t('gm_note')}</Txt>
    </Screen>
  )
}

const styles = StyleSheet.create({
  grid: { width: '100%', flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', rowGap: 10 },
  tile: { width: '31.5%', aspectRatio: 1, borderRadius: 18, overflow: 'hidden', alignItems: 'center', justifyContent: 'center', gap: 4, paddingTop: 14 },
  name: { color: '#fff', fontSize: 15, textShadowColor: 'rgba(0,0,0,.35)', textShadowRadius: 3 },
  badge: { position: 'absolute', top: 6, flexDirection: 'row', alignItems: 'center', gap: 3, paddingHorizontal: 6, paddingVertical: 1, borderRadius: 8, backgroundColor: 'rgba(0,0,0,.35)' },
})
