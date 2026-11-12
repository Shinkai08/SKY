import { Image } from 'expo-image'
import { router } from 'expo-router'
import { useEffect, useMemo, useState } from 'react'
import { Pressable, StyleSheet, View } from 'react-native'
import { api, ApiError } from '@/lib/api'
import { useAuth } from '@/lib/auth'
import { success, tap } from '@/lib/haptics'
import { useI18n } from '@/lib/i18n'
import { openTrade } from '@/lib/nav'
import { useAccount } from '@/lib/sky'
import { useColors } from '@/lib/theme'
import { compact, priceDigits } from '@/web/data'
import { useSpotTickers, useTrends } from '@/web/market/hooks'
import type { Sentiment } from '@/web/market/listings'
import { SPOT_SYMBOLS, liveMarkets } from '@/web/market/live'
import { vipOf } from '@/web/vip'
import { Gauge, Spark } from '@/ui/charts'
import { Btn, Card, Chg, Icon, Row, Screen, Seg, Txt } from '@/ui/kit'
import { MarketIcon } from '@/ui/MarketIcon'
import { Sheet } from '@/ui/Sheet'
import { JoyCard } from '@/ui/VipCard'

const HOME_SYMBOLS = [...SPOT_SYMBOLS, 'PAXGUSDT']
const mood = (v: number) => (v < 20 ? 'moodExtremeFear' : v < 40 ? 'moodFear' : v <= 60 ? 'moodNeutral' : v < 80 ? 'moodGreed' : 'moodExtremeGreed')

export default function Home() {
  const { t, num } = useI18n()
  const c = useColors()
  const { me } = useAuth()
  const { account } = useAccount()
  const [tab, setTab] = useState<'popular' | 'gainers'>('popular')
  const { tickers } = useSpotTickers(HOME_SYMBOLS)
  const trends = useTrends(SPOT_SYMBOLS)
  const markets = useMemo(() => liveMarkets(tickers, trends), [tickers, trends])
  const list = [...markets].sort((a, b) => (tab === 'popular' ? b.vol - a.vol : b.chg - a.chg)).slice(0, 6)
  const totalVol = markets.reduce((s, m) => s + m.vol, 0)
  const total = account?.total ?? account?.equity ?? 0
  const pnl = account?.upnl ?? 0
  const vip = vipOf(account)

  const [stats, setStats] = useState<{ n: number; trades: number }>()
  const [sent, setSent] = useState<Sentiment>()
  const [tick, setTick] = useState(0)
  useEffect(() => {
    api<{ trades: number }[]>('/sky/markets').then(ms => setStats({ n: ms.length, trades: ms.reduce((s, m) => s + m.trades, 0) })).catch(() => undefined)
    api<Sentiment>('/market-sentiment').then(setSent).catch(() => undefined)
  }, [tick])
  const [refreshing, setRefreshing] = useState(false)
  const refresh = () => { setRefreshing(true); setTick(x => x + 1); setTimeout(() => setRefreshing(false), 600) }
  const fg = sent?.fearGreed

  return (
    <Screen refreshing={refreshing} onRefresh={refresh}>
      {me ? (
        <Card onPress={() => router.push('/vip')} style={{ alignItems: 'center' }}>
          <JoyCard level={vip.level} width={300} />
          <Row style={{ justifyContent: 'space-between', alignSelf: 'stretch' }}>
            <View>
              <Txt v="small" tone="muted">{t('equity')}</Txt>
              <Txt v="title" num>{num(total)} <Txt v="small" tone="muted">USDT</Txt></Txt>
            </View>
            <View style={{ alignItems: 'flex-end' }}>
              <Txt v="small" tone="muted">{t('pnl')}</Txt>
              <Txt v="h2" num tone={pnl >= 0 ? 'up' : 'down'}>{pnl >= 0 ? '+' : '−'}{num(Math.abs(pnl))}</Txt>
            </View>
          </Row>
          <Row style={{ alignSelf: 'stretch' }}>
            <Btn title={t('deposit')} icon="arrow.down.circle" onPress={() => router.push('/deposit')} style={{ flex: 1 }} />
            <Btn title={t('tradeNow')} kind="secondary" icon="arrow.left.arrow.right" onPress={() => openTrade('BTCUSDT', true)} style={{ flex: 1 }} />
          </Row>
        </Card>
      ) : (
        <Card style={{ alignItems: 'center', paddingVertical: 24 }}>
          <Image source={require('@/assets/brand/sky-logo.webp')} style={{ width: 130, height: 116 }} contentFit="contain" />
          <Txt v="h2" center>Skyline Exchange</Txt>
          <Row style={{ alignSelf: 'stretch' }}>
            <Btn title={t('register')} onPress={() => router.push('/login')} style={{ flex: 1 }} />
            <Btn title={t('login')} kind="secondary" onPress={() => router.push('/login')} style={{ flex: 1 }} />
          </Row>
        </Card>
      )}

      <Row gap={10}>
        {[
          { icon: 'waveform.path.ecg' as const, v: compact(totalVol, num), l: t('activity') },
          { icon: 'square.grid.2x2' as const, v: stats ? num(stats.n, 0) : '—', l: `SKY · ${t('markets')}` },
          { icon: 'doc.text' as const, v: stats ? num(stats.trades, 0) : '—', l: `SKY · ${t('tradeCount')}` },
        ].map(s => (
          <Card key={s.l} style={styles.stat}>
            <Icon name={s.icon} size={16} color={c.gold} />
            <Txt v="h2" num lines={1}>{s.v}</Txt>
            <Txt v="tiny" tone="muted" lines={1}>{s.l}</Txt>
          </Card>
        ))}
      </Row>

      <LuckyGift />

      <Card style={{ paddingHorizontal: 0, paddingBottom: 6 }}>
        <Row style={{ paddingHorizontal: 16, justifyContent: 'space-between' }}>
          <Seg items={[{ id: 'popular', label: t('popular') }, { id: 'gainers', label: t('gainers') }]} value={tab} onChange={setTab} style={{ width: 190 }} />
          <Pressable onPress={() => router.navigate('/markets')}><Txt v="small" tone="gold">{t('all')} ›</Txt></Pressable>
        </Row>
        {list.map(m => (
          <Pressable key={m.sym} onPress={() => { tap(); openTrade(`${m.sym}USDT`, true) }} style={({ pressed }) => [styles.coin, pressed && { backgroundColor: c.hover }]}>
            <MarketIcon it={{ base: m.sym, cat: 'crypto' }} size={34} />
            <View style={{ flex: 1 }}>
              <Txt bold>{m.sym}</Txt>
              <Txt v="tiny" tone="muted">{m.name}</Txt>
            </View>
            <Spark data={m.trend} w={60} h={26} up={m.chg >= 0} />
            <View style={{ alignItems: 'flex-end', width: 96, gap: 3 }}>
              <Txt num bold>{num(m.price, priceDigits(m.price))}</Txt>
              <Chg v={m.chg} />
            </View>
          </Pressable>
        ))}
      </Card>

      {fg && (
        <Card style={{ alignItems: 'center' }}>
          <Txt v="h2" style={{ alignSelf: 'flex-start' }}>{t('fearGreedTitle')}</Txt>
          <Gauge score={fg.current} label={t(mood(fg.current))} size={260} />
          <Row style={{ alignSelf: 'stretch', justifyContent: 'space-around' }}>
            {[{ k: 'sentimentYesterday', v: fg.yesterday }, { k: 'sentimentLastWeek', v: fg.lastWeek }].map(x => (
              <View key={x.k} style={{ alignItems: 'center' }}>
                <Txt v="tiny" tone="muted">{t(x.k)}</Txt>
                <Txt bold num>{x.v} · <Txt v="small" tone="ink2">{t(mood(x.v))}</Txt></Txt>
              </View>
            ))}
          </Row>
        </Card>
      )}

      <Card>
        <Txt v="h2">{t('news')}</Txt>
        {[{ k: 'news1', go: () => openTrade('BTCUSDT', false) }, { k: 'news2', go: () => router.push('/vip') }, { k: 'news3', go: () => router.push('/settings') }].map(n => (
          <Pressable key={n.k} onPress={() => { tap(); n.go() }}>
            <Row><Icon name="newspaper" size={15} color={c.gold} /><Txt v="small" tone="ink2" style={{ flex: 1 }}>{t(n.k)}</Txt></Row>
          </Pressable>
        ))}
      </Card>
    </Screen>
  )
}

type Gift = { enabled: boolean; claimed: boolean; amount: number }

/** Welcome red pouch (社区福袋): one claim per account. */
function LuckyGift() {
  const { t, num } = useI18n()
  const { me } = useAuth()
  const { refresh } = useAccount()
  const [gift, setGift] = useState<Gift>()
  const [open, setOpen] = useState(false)
  const [busy, setBusy] = useState(false)
  const [issue, setIssue] = useState('')
  useEffect(() => {
    setGift(undefined)
    if (me) api<Gift>('/welcome-gift').then(setGift).catch(() => undefined)
  }, [me?.id])
  if (!me || !gift?.enabled) return null
  const claim = async () => {
    setBusy(true); setIssue('')
    try {
      const r = await api<{ amount: number; claimed: boolean; newClaim: boolean }>('/welcome-gift/claim', { body: {} })
      setGift({ enabled: true, claimed: r.claimed, amount: r.amount })
      if (r.newClaim) success()
      refresh()
    } catch (e) {
      setIssue(e instanceof ApiError && e.code === 'account_frozen' ? 'err_account_frozen' : 'giftClaimFailed')
    } finally { setBusy(false) }
  }
  return (
    <>
      <Card onPress={() => setOpen(true)} style={[styles.gift, { backgroundColor: '#5a1220', borderColor: '#a3283e' }]}>
        <Txt v="title" style={{ color: '#f6d77d' }}>福</Txt>
        <View style={{ flex: 1 }}>
          <Txt bold style={{ color: '#fff' }}>{t('luckyGift')}</Txt>
          <Txt v="tiny" style={{ color: '#f3c9c9' }}>{t(gift.claimed ? 'giftReceived' : 'giftRules')}</Txt>
        </View>
        <Icon name="chevron.right" size={14} color="#f6d77d" />
      </Card>
      <Sheet visible={open} title={t('luckyGift')} onClose={() => setOpen(false)}>
        <View style={{ alignItems: 'center', gap: 12, paddingVertical: 20 }}>
          <View style={[styles.pouch, { backgroundColor: '#b3263a' }]}><Txt v="hero" style={{ color: '#f6d77d' }}>福</Txt></View>
          <Txt v="hero" num tone="gold">{num(gift.amount, 0)} <Txt v="h2" tone="muted">USDT</Txt></Txt>
          <Txt v="small" tone="ink2" center>{t(gift.claimed ? 'giftReceived' : 'giftRules')}</Txt>
        </View>
        {gift.claimed
          ? <Btn title={t('assets')} icon="checkmark" onPress={() => { setOpen(false); router.navigate('/assets') }} />
          : <Btn title={t(busy ? 'giftOpening' : 'giftClaim')} onPress={claim} busy={busy} />}
        {issue ? <Txt v="small" tone="down" center>{t(issue)}</Txt> : null}
      </Sheet>
    </>
  )
}

const styles = StyleSheet.create({
  stat: { flex: 1, padding: 12, gap: 4 },
  coin: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 16, paddingVertical: 10 },
  gift: { flexDirection: 'row', alignItems: 'center', gap: 14 },
  pouch: { width: 96, height: 96, borderRadius: 30, alignItems: 'center', justifyContent: 'center' },
})
