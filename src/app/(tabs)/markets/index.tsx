import { Stack } from 'expo-router'
import { useEffect, useMemo, useState } from 'react'
import { FlatList, Pressable, ScrollView, StyleSheet, View } from 'react-native'
import { press, tap } from '@/lib/haptics'
import { useI18n } from '@/lib/i18n'
import { openTrade, usePriceFmt } from '@/lib/nav'
import { stars, toggleStar } from '@/lib/prefs'
import { useColors } from '@/lib/theme'
import { compact } from '@/web/data'
import { useAllCatalog, useCatalog, type CatItem, type Category } from '@/web/market/catalog'
import { useNow } from '@/web/market/hooks'
import { remaining, useListings, type Listing } from '@/web/market/listings'
import { Card, Chg, Empty, Icon, Loading, Row, Txt } from '@/ui/kit'
import { MarketIcon } from '@/ui/MarketIcon'

const PAGE = 60
const SUBS: Record<Category, string[]> = {
  crypto: [],
  tradfi: ['local', 'us', 'hk', 'kr', 'cn', 'preipo', 'fx'],
  commodities: ['metal', 'energy', 'rareearth'],
  onchain: ['bsc', 'solana', 'base', 'ethereum'],
}

const go = (m: CatItem) => {
  if (m.spot) openTrade(m.sym, true)
  else if (m.tradable) openTrade(m.sym, false)
}

export default function Markets() {
  const { t, num } = useI18n()
  const c = useColors()
  const fmt = usePriceFmt()
  const starred = stars.useValue()
  const [cat, setCat] = useState<Category | 'stars'>('crypto')
  const [sub, setSub] = useState('all')
  const [q, setQ] = useState('')
  const [limit, setLimit] = useState(PAGE)
  const onlyStars = cat === 'stars'
  const current = useCatalog(onlyStars ? 'crypto' : cat, !onlyStars)
  const all = useAllCatalog(onlyStars)
  const { items, state } = onlyStars ? all : current
  useEffect(() => { setSub('all'); setLimit(PAGE) }, [cat])

  const name = (it: CatItem) => {
    const k = `cm_${it.base}`, tr = t(k)
    return tr !== k ? tr : it.name ?? ''
  }
  const rows = useMemo(() => {
    const qq = q.trim().toLowerCase()
    return items.filter(it =>
      (onlyStars ? starred.includes(it.sym) : sub === 'all' || it.sub === sub) &&
      (!qq || it.base.toLowerCase().includes(qq) || (it.name ?? '').toLowerCase().includes(qq) || (it.contract ?? '').toLowerCase() === qq))
  }, [items, sub, q, onlyStars, starred])
  const top = (f: (x: CatItem) => number) => [...items].filter(x => x.vol > 0).sort((a, b) => f(b) - f(a)).slice(0, 3)
  const boards = [{ title: t('hot'), list: top(x => x.vol) }, { title: t('gainers'), list: top(x => x.chg) }, { title: t('losers'), list: top(x => -x.chg) }]
  const cats: { id: Category | 'stars'; label: string }[] = [
    { id: 'stars', label: t('watchlist') }, { id: 'crypto', label: t('crypto') }, { id: 'tradfi', label: t('tradfi') },
    { id: 'commodities', label: t('commodities') }, { id: 'onchain', label: t('onchain') },
  ]
  const subs = onlyStars ? [] : SUBS[cat].filter(s => items.some(x => x.sub === s))

  const header = (
    <View style={{ gap: 12, paddingBottom: 6 }}>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chips}>
        {cats.map(x => (
          <Pressable key={x.id} onPress={() => { tap(); setCat(x.id) }} style={[styles.chip, { backgroundColor: cat === x.id ? c.gold : c.surface2 }]}>
            {x.id === 'stars' && <Icon name="star.fill" size={12} color={cat === x.id ? c.onGold : c.gold} />}
            <Txt v="small" bold tone={cat === x.id ? 'onGold' : 'ink2'}>{x.label}</Txt>
          </Pressable>
        ))}
      </ScrollView>
      {!onlyStars && !q && (
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 10, paddingHorizontal: 16 }}>
          {boards.map(b => (
            <Card key={b.title} style={styles.board}>
              <Txt v="small" bold tone="ink2">{b.title}</Txt>
              {b.list.map(m => (
                <Pressable key={m.sym} onPress={() => { tap(); go(m) }}>
                  <Row>
                    <MarketIcon it={m} size={20} />
                    <Txt v="small" bold style={{ flex: 1 }} lines={1}>{m.base}</Txt>
                    <Chg v={m.chg} />
                  </Row>
                </Pressable>
              ))}
              {!b.list.length && <Txt v="tiny" tone="muted">—</Txt>}
            </Card>
          ))}
        </ScrollView>
      )}
      {cat === 'crypto' && !q && <Listings />}
      {subs.length > 0 && (
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 16, paddingHorizontal: 16 }}>
          {['all', ...subs].map(s => (
            <Pressable key={s} onPress={() => { tap(); setSub(s) }}>
              <Txt v="small" bold={sub === s} tone={sub === s ? 'ink' : 'muted'}>
                {s === 'all' ? t('sub_all') : t(`sub_${s}`) !== `sub_${s}` ? t(`sub_${s}`) : items.find(x => x.sub === s)?.chain ?? s}
              </Txt>
            </Pressable>
          ))}
        </ScrollView>
      )}
      <Row style={styles.headRow}>
        <Txt v="tiny" tone="muted" style={{ flex: 1 }}>{t('name')} / {t('volume')}</Txt>
        <Txt v="tiny" tone="muted">{t('price')}</Txt>
        <Txt v="tiny" tone="muted" style={{ width: 84, textAlign: 'right' }}>{t('change')}</Txt>
      </Row>
    </View>
  )

  return (
    <>
      <Stack.Screen options={{ headerSearchBarOptions: { placeholder: t('search'), hideWhenScrolling: true, onChangeText: e => { setQ(e.nativeEvent.text); setLimit(PAGE) } } }} />
      <FlatList
        style={{ flex: 1, backgroundColor: c.bg }}
        contentInsetAdjustmentBehavior="automatic"
        data={rows.slice(0, limit)}
        keyExtractor={m => m.sym}
        ListHeaderComponent={header}
        onEndReached={() => { if (rows.length > limit) setLimit(l => l + PAGE) }}
        onEndReachedThreshold={0.5}
        ListEmptyComponent={state === 'loading' ? <Loading /> : <Empty text={state === 'offline' ? t('err_service_unavailable') : t('noData')} />}
        contentContainerStyle={{ paddingTop: 10, paddingBottom: 40 }}
        renderItem={({ item: m }) => {
          const starredRow = starred.includes(m.sym)
          return (
            <Pressable onPress={() => { tap(); go(m) }} onLongPress={() => { press(); toggleStar(m.sym) }}
              style={({ pressed }) => [styles.row, pressed && { backgroundColor: c.hover }]}>
              <MarketIcon it={m} size={34} />
              <View style={{ flex: 1, gap: 2, minWidth: 0 }}>
                <Row gap={4}>
                  <Txt bold lines={1}>{m.base}</Txt>
                  {starredRow && <Icon name="star.fill" size={11} color={c.gold} />}
                  {!m.spot && !m.tradable && <Txt v="tiny" tone="muted"> · {m.chain || m.source === 'ecb' ? t('quoteOnly') : t('comingSoon')}</Txt>}
                </Row>
                <Txt v="tiny" tone="muted" lines={1}>{name(m) || (m.sub === 'spot' ? '/ USDT' : '')}{m.chain ? ` · ${m.chain}` : ''} · {compact(m.vol, num)}</Txt>
              </View>
              <Txt num bold>{fmt(m.price)}</Txt>
              <View style={{ width: 84, alignItems: 'flex-end' }}><Chg v={m.chg} pill /></View>
            </Pressable>
          )
        }}
      />
    </>
  )
}

function Countdown({ item, now }: { item: Listing; now: number }) {
  const { t } = useI18n()
  const r = remaining(item.launchAt, now)
  if (item.status !== 'scheduled') return <Txt v="small" tone="gold">{t(item.status === 'live' ? 'listingLive' : 'listingCancelled')}</Txt>
  if (r.due) return <Txt v="small" tone="gold">{t(item.issue ? 'listingWaitingPrice' : 'listingOpening')}</Txt>
  return <Txt v="h2" num tone="gold">{r.days > 0 ? `${r.days}${t('dayUnit')} ` : ''}{r.clock}</Txt>
}

/** Upcoming listings with live countdowns. */
function Listings() {
  const { t } = useI18n()
  const { items, offset } = useListings()
  const now = useNow() + offset
  if (!items.length) return null
  return (
    <View style={{ gap: 8 }}>
      <Row style={{ paddingHorizontal: 16 }}><Icon name="clock" size={15} /><Txt bold>{t('upcomingListings')}</Txt></Row>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 10, paddingHorizontal: 16 }}>
        {items.map(it => {
          const base = it.symbol.replace(/USDT$/, '')
          return (
            <Card key={it.id} style={{ width: 200 }} onPress={it.status === 'live' ? () => openTrade(it.symbol, it.board !== 'perp') : undefined}>
              <Row><MarketIcon it={{ base, cat: it.category }} size={28} /><View><Txt bold>{base} / USDT</Txt>{it.name ? <Txt v="tiny" tone="muted">{it.name}</Txt> : null}</View></Row>
              <Countdown item={it} now={now} />
              <Txt v="tiny" tone="muted">{new Date(it.launchAt).toLocaleString()}</Txt>
            </Card>
          )
        })}
      </ScrollView>
    </View>
  )
}

const styles = StyleSheet.create({
  chips: { gap: 8, paddingHorizontal: 16 },
  chip: { flexDirection: 'row', alignItems: 'center', gap: 5, height: 32, paddingHorizontal: 14, borderRadius: 16 },
  board: { width: 170, padding: 12, gap: 8 },
  headRow: { paddingHorizontal: 16, paddingTop: 4 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 16, paddingVertical: 10 },
})
