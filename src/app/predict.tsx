import { randomUUID } from 'expo-crypto'
import { router, Stack } from 'expo-router'
import { useCallback, useEffect, useState } from 'react'
import { Pressable, StyleSheet, TextInput, View } from 'react-native'
import { api, ApiError } from '@/lib/api'
import { useAuth } from '@/lib/auth'
import { success, tap, warn } from '@/lib/haptics'
import { useI18n } from '@/lib/i18n'
import { loadJSON, saveJSON } from '@/lib/storage'
import { usePoll } from '@/lib/sky'
import { radius, useColors } from '@/lib/theme'
import { useNow } from '@/web/market/hooks'
import { PREDICTION_SCALE, USDT_SCALE, predictionLabel, type PredictionMarket, type PredictionOrder } from '@/web/market/predictions'
import { Btn, Card, Empty, Field, Icon, Loading, Row, Screen, Tabs, Txt } from '@/ui/kit'
import { Sheet } from '@/ui/Sheet'

// Prediction markets (the website's Predict page): price up/down rounds from
// Binance and admin-listed events, with quotes, bets and history.

type Tab = 'all' | 'price' | 'event' | 'history'
const FAV_KEY = 'sky.predictFav'

export default function Predict() {
  const { t, num, lang } = useI18n()
  const c = useColors()
  const { me } = useAuth()
  const now = useNow(1000)
  const [tab, setTab] = useState<Tab>('all')
  const [markets, setMarkets] = useState<PredictionMarket[]>()
  const [orders, setOrders] = useState<PredictionOrder[]>()
  const [marketErr, setMarketErr] = useState(false)
  const [histErr, setHistErr] = useState(false)
  const [q, setQ] = useState('')
  const [favOnly, setFavOnly] = useState(false)
  const [favs, setFavs] = useState<string[]>([])
  const [sel, setSel] = useState<{ market: PredictionMarket; outcome: number }>()
  useEffect(() => { loadJSON<string[]>(FAV_KEY, []).then(setFavs) }, [])
  const reloadMarkets = useCallback(async () => {
    try { setMarkets(await api<PredictionMarket[]>('/predictions')); setMarketErr(false) } catch { setMarketErr(true) }
  }, [])
  usePoll(() => { reloadMarkets() }, 3000, [])
  usePoll(() => {
    if (tab !== 'history' || !me) return
    api<PredictionOrder[]>('/predictions/me').then(o => { setOrders(o); setHistErr(false) }).catch(() => setHistErr(true))
  }, 5000, [tab, me?.id])
  const toggleFav = (id: string) => {
    tap()
    const next = favs.includes(id) ? favs.filter(x => x !== id) : [...favs, id]
    setFavs(next); saveJSON(FAV_KEY, next)
  }
  const shown = markets?.filter(m => (tab === 'all' || m.kind === tab) && (!favOnly || favs.includes(m.id)) &&
    [m.title, m.symbol, ...m.outcomes.map(o => o.label)].some(v => v?.toLowerCase().includes(q.trim().toLowerCase())))
  const labels: Record<Tab, string> = { all: 'pr_all', price: 'pr_updown', event: 'pr_events', history: 'pr_history' }
  const date = (v: number) => new Date(v).toLocaleString(lang)

  return (
    <>
      <Stack.Screen options={{ headerShown: true, title: t('pr_title') }} />
      <Screen>
        <Tabs style={{ paddingHorizontal: 0 }} items={(['all', 'price', 'event', 'history'] as const).map(id => ({ id, label: t(labels[id]) }))} value={tab} onChange={setTab} />
        {tab === 'history' ? (
          !me ? <Btn title={t('login')} onPress={() => router.push('/login')} />
            : histErr ? <Empty text={t('pr_failed')} />
            : !orders ? <Loading />
            : orders.length === 0 ? <Empty text={t('pr_no_orders')} />
            : orders.map(o => (
              <Card key={o.id}>
                <Row style={{ justifyContent: 'space-between' }}>
                  <Txt bold style={{ flex: 1 }}>{o.title} · {predictionLabel(t, o.label, o.source === 'Binance Spot')}</Txt>
                  <Txt v="small" tone={o.status === 'won' ? 'up' : o.status === 'lost' ? 'down' : 'gold'}>{t(`pr_status_${o.status}`)}</Txt>
                </Row>
                <Txt v="tiny" tone="muted">{date(o.at)} · {o.source} · ×{num(PREDICTION_SCALE / o.probability, 4)}</Txt>
                <Txt v="small" num>{t('pr_stake')} {num(o.amount / USDT_SCALE, 2)} USDT · {t(o.status === 'pending' ? 'pr_payout' : 'pr_paid')} {num((o.status === 'refunded' ? o.amount : o.status === 'lost' ? 0 : o.payout) / USDT_SCALE, 2)} USDT</Txt>
                {o.result ? <Txt v="tiny" tone="muted">{o.result.evidence}</Txt> : null}
              </Card>
            ))
        ) : (
          <>
            <View style={[styles.search, { backgroundColor: c.surface2 }]}>
              <Icon name="magnifyingglass" size={15} color={c.muted} />
              <TextInput value={q} onChangeText={setQ} placeholder={t('pr_search')} placeholderTextColor={c.muted} style={{ flex: 1, color: c.ink, fontSize: 16 }} selectionColor={c.gold} />
              <Pressable hitSlop={8} onPress={() => { tap(); setFavOnly(v => !v) }}><Icon name={favOnly ? 'star.fill' : 'star'} size={18} color={favOnly ? c.gold : c.muted} /></Pressable>
            </View>
            {marketErr && <Txt tone="down">{t('pr_failed')}</Txt>}
            {!markets && !marketErr && <Loading />}
            {shown?.length === 0 && <Empty text={t('pr_empty')} icon="chart.pie" />}
            {shown?.map(m => {
              const open = !marketErr && m.status === 'open' && now < m.closes
              return (
                <Card key={m.id}>
                  <Row style={{ alignItems: 'flex-start' }}>
                    <Txt bold style={{ flex: 1 }}>{m.title}</Txt>
                    <Pressable hitSlop={8} onPress={() => toggleFav(m.id)}><Icon name={favs.includes(m.id) ? 'star.fill' : 'star'} size={17} color={favs.includes(m.id) ? c.gold : c.muted} /></Pressable>
                  </Row>
                  <Txt v="tiny" tone="muted">{m.kind === 'price' ? `Binance Spot · ${m.symbol} · ${m.interval}` : 'Polymarket'} · {date(m.closes)}</Txt>
                  {m.quote?.openPrice ? <Txt v="tiny" tone="ink2" num>{t('pr_open')} {m.quote.openPrice} · {t('price')} {m.quote.price}</Txt> : null}
                  <Row gap={10}>
                    {m.outcomes.map((o, i) => {
                      const p = m.quote?.probabilities[i]
                      return (
                        <View key={o.label} style={{ flex: 1, gap: 6 }}>
                          <Txt v="small" num center>{open && p ? `${num(p / 10000, 1)}% · ×${num(PREDICTION_SCALE / p, 2)}` : '—'}</Txt>
                          <Btn small kind={i === 0 ? 'up' : 'down'} title={predictionLabel(t, o.label, m.kind === 'price')} disabled={!open || !p}
                            onPress={() => (me ? setSel({ market: m, outcome: i }) : router.push('/login'))} />
                        </View>
                      )
                    })}
                  </Row>
                  <Row style={{ justifyContent: 'space-between' }}>
                    <Txt v="tiny" tone="muted">{t(`pr_status_${m.status}`)}{open ? ` · ${t('pr_left')} ${Math.max(0, Math.ceil((m.closes - now) / 1000))}s` : ''}</Txt>
                  </Row>
                  {m.rules ? <Txt v="tiny" tone="muted" lines={3}>{t('pr_rules')}: {m.rules}</Txt> : null}
                  {m.result ? <Txt v="small" tone="gold">{m.result.winner < 0 ? t('pr_status_refunded') : predictionLabel(t, m.outcomes[m.result.winner].label, m.kind === 'price')} · {m.result.evidence}</Txt> : null}
                </Card>
              )
            })}
          </>
        )}
      </Screen>
      {sel && <BetSheet market={sel.market} current={markets?.find(m => m.id === sel.market.id)} outcome={sel.outcome}
        onClose={() => setSel(undefined)} reload={reloadMarkets} onPlaced={() => { setSel(undefined); setTab('history') }} />}
    </>
  )
}

function BetSheet({ market, current, outcome, onClose, onPlaced, reload }: {
  market: PredictionMarket; current?: PredictionMarket; outcome: number; onClose: () => void; onPlaced: () => void; reload: () => Promise<void>
}) {
  const { t, num } = useI18n()
  const now = useNow(1000)
  const [quote, setQuote] = useState(market.quote)
  const [amount, setAmount] = useState('')
  const [available, setAvailable] = useState<number>()
  const [requestId, setRequestId] = useState(() => randomUUID())
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  useEffect(() => { api<{ available: number }>('/account').then(a => setAvailable(a.available)).catch(() => undefined) }, [])
  const probability = quote?.probabilities[outcome] ?? 0
  const odds = probability ? PREDICTION_SCALE / probability : 0
  const decimal = amount.trim().replace(',', '.')
  const value = Number(decimal)
  const valid = /^\d+(?:\.\d{1,8})?$/.test(decimal) && value > 0
  const changed = !quote || now - quote.at >= 15000 || quote.round !== current?.quote?.round ||
    probability !== current?.quote?.probabilities[outcome] || now >= current.closes
  const submit = async () => {
    if (!quote || !valid || busy) return
    setBusy(true); setError('')
    try {
      await api('/predictions/orders', { body: { id: requestId, market: market.id, round: quote.round, outcome, quoteAt: quote.at, probability, amount: decimal } })
      success(); onPlaced()
    } catch (e) {
      warn()
      const code = e instanceof ApiError ? e.code : ''
      setError(code === 'prediction_insufficient_funds' ? 'pr_insufficient' : code === 'prediction_quote_changed' ? 'pr_requote' : 'pr_failed')
      if (code === 'prediction_quote_changed') await reload()
    } finally { setBusy(false) }
  }
  return (
    <Sheet visible title={`${market.title} · ${predictionLabel(t, market.outcomes[outcome].label, market.kind === 'price')}`} onClose={onClose}>
      <Txt v="small" tone="muted">{market.kind === 'price' ? 'Binance Spot' : 'Polymarket'}</Txt>
      <Row style={{ justifyContent: 'space-between' }}><Txt tone="muted">{t('pr_odds')}</Txt><Txt num bold tone="gold">×{num(odds, 4)}</Txt></Row>
      <Row style={{ justifyContent: 'space-between' }}><Txt tone="muted">{t('available')}</Txt><Txt num>{available === undefined ? '—' : num(available, 2)} USDT</Txt></Row>
      <Field label={t('pr_stake')} value={amount} editable={!busy} keyboardType="decimal-pad" suffix="USDT" onChangeText={v => { setAmount(v); setRequestId(randomUUID()) }} />
      <Row style={{ justifyContent: 'space-between' }}><Txt tone="muted">{t('pr_payout')}</Txt><Txt num bold>{valid ? num(value * odds, 2) : '—'} USDT</Txt></Row>
      <Txt v="tiny" tone="muted">{t('pr_no_fee')}</Txt>
      {error ? <Txt v="small" tone="down">{t(error)}</Txt> : null}
      {changed && (
        <Btn kind="secondary" title={t('pr_requote')} disabled={busy || !current?.quote || current.quote.round !== market.quote?.round || now >= (current?.closes ?? 0)}
          onPress={() => { setQuote(current?.quote); setRequestId(randomUUID()); setError('') }} />
      )}
      <Btn title={t('pc_confirm')} busy={busy} disabled={changed || !valid || !odds} onPress={submit} />
    </Sheet>
  )
}

const styles = StyleSheet.create({
  search: { flexDirection: 'row', alignItems: 'center', gap: 8, height: 42, borderRadius: radius.m, paddingHorizontal: 12 },
})
