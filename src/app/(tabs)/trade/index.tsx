import Slider from '@react-native-community/slider'
import { router, Stack } from 'expo-router'
import { useEffect, useMemo, useState, type ReactNode } from 'react'
import { Pressable, StyleSheet, View } from 'react-native'
import { useI18n } from '@/lib/i18n'
import { success, tap, warn } from '@/lib/haptics'
import { openTrade } from '@/lib/nav'
import { stars, toggleStar, tradeTarget } from '@/lib/prefs'
import { isolatedLiq, mmrFor, useAccount, useKlines, useMarket, type SkyPosition, type SkySnap } from '@/lib/sky'
import { persisted } from '@/lib/storage'
import { useColors } from '@/lib/theme'
import { useNow } from '@/web/market/hooks'
import { feeFor, pct, vipOf } from '@/web/vip'
import { Btn, Card, Chg, Empty, Field, Icon, Row, Screen, Seg, Tabs, Txt } from '@/ui/kit'
import { MarketIcon } from '@/ui/MarketIcon'
import { Sheet } from '@/ui/Sheet'
import { tierName } from '@/ui/VipCard'
import { useGroupedBook } from '@/trade/book'
import { MiniBook, PctSlider, RatioBar, StepPicker } from '@/trade/BookView'
import { CandleChart } from '@/trade/CandleChart'
import { LeverageSheet, PosCard, UsdtCard, type PosTools } from '@/trade/PosCard'

const LEV_MARKS = [1, 20, 50, 100, 150, 200]
const marginMode = persisted<'cross' | 'isolated'>('sky.marginMode', 'isolated')
const TFS = ['1m', '5m', '15m', '1h', '4h', '1d'] as const
const TF_KEYS: Record<string, string> = { '1m': 'min1', '5m': 'min5', '15m': 'min15', '1h': 'hour', '4h': 'hour4', '1d': 'day' }

export default function TradeScreen() {
  const { t } = useI18n()
  const target = tradeTarget.useValue()
  const switchTo = (spot: boolean) => { if (spot !== target.spot) openTrade(target.sym, spot) }
  return (
    <>
      <Stack.Screen options={{
        title: '',
        headerLeft: () => (
          <Seg style={{ width: 150 }} items={[{ id: 'perp', label: t('perpetual') }, { id: 'spot', label: t('spot') }]}
            value={target.spot ? 'spot' : 'perp'} onChange={v => switchTo(v === 'spot')} />
        ),
      }} />
      {target.spot ? <SpotTrade key={'s' + target.sym} sym={target.sym} /> : <PerpTrade key={'p' + target.sym} sym={target.sym} />}
    </>
  )
}

/** Pair button (opens the picker), favourite star and chart toggle. */
function PairHead({ snap, sym, spot, sub, chart, setChart }: { snap?: SkySnap; sym: string; spot: boolean; sub: string; chart: boolean; setChart: (v: boolean) => void }) {
  const c = useColors()
  const starred = stars.useValue().includes(sym)
  const base = snap?.base ?? sym.replace(/USDT$|@.*$/, '')
  return (
    <Row style={{ justifyContent: 'space-between' }}>
      <Pressable onPress={() => { tap(); router.push({ pathname: '/pair', params: { spot: spot ? '1' : '0' } }) }}>
        <Row>
          <MarketIcon it={{ base, icon: snap?.icon, cat: snap?.cat, sub: snap?.sub }} size={30} />
          <View>
            <Row gap={4}><Txt v="h2">{base}{spot ? '/' : ''}USDT</Txt><Icon name="chevron.down" size={12} color={c.muted} /></Row>
            <Txt v="tiny" tone="muted">{sub}</Txt>
          </View>
        </Row>
      </Pressable>
      <Row gap={18}>
        <Pressable hitSlop={8} onPress={() => { tap(); toggleStar(sym) }}><Icon name={starred ? 'star.fill' : 'star'} size={20} color={starred ? c.gold : c.muted} /></Pressable>
        <Pressable hitSlop={8} onPress={() => { tap(); setChart(!chart) }}><Icon name="chart.bar.xaxis" size={20} color={chart ? c.gold : c.muted} /></Pressable>
      </Row>
    </Row>
  )
}

function ChartBox({ snap, last, digits }: { snap?: SkySnap; last: number; digits: number }) {
  const { t } = useI18n()
  const [tf, setTf] = useState('15m')
  const candles = useKlines(snap, tf)
  const data = useMemo(() => {
    if (!candles.length || !last || snap?.src === 'local') return candles
    const k = candles[candles.length - 1]
    return [...candles.slice(0, -1), { ...k, c: last, h: Math.max(k.h, last), l: Math.min(k.l, last) }]
  }, [candles, last, snap?.src])
  return (
    <Card style={{ paddingHorizontal: 8 }}>
      <Seg items={TFS.map(id => ({ id, label: t(TF_KEYS[id]) }))} value={tf} onChange={setTf} />
      {data.length ? <CandleChart data={data} height={280} digits={digits} /> : <Empty text={snap && !snap.ref ? t('collecting') : t('connecting')} icon="chart.bar" />}
    </Card>
  )
}

function Stat({ k, v }: { k: string; v: ReactNode }) {
  return (
    <Row style={{ justifyContent: 'space-between' }}>
      <Txt v="tiny" tone="muted">{k}</Txt>
      {typeof v === 'string' ? <Txt v="tiny" num tone="ink2">{v}</Txt> : v}
    </Row>
  )
}

function useToast(): [string, (m: string) => void] {
  const [notice, setNotice] = useState('')
  useEffect(() => { if (!notice) return; const id = setTimeout(() => setNotice(''), 1800); return () => clearTimeout(id) }, [notice])
  return [notice, setNotice]
}

function Toast({ text }: { text: string }) {
  const c = useColors()
  if (!text) return null
  return <View pointerEvents="none" style={[styles.toast, { backgroundColor: c.surface2, borderColor: c.line }]}><Txt v="small" center>{text}</Txt></View>
}

function Gate() {
  const { t } = useI18n()
  return (
    <View style={{ gap: 8 }}>
      <Txt v="tiny" tone="muted" center>{t('loginToTrade')}</Txt>
      <Btn title={t('login')} onPress={() => router.push('/login')} />
    </View>
  )
}

// ---------- perpetual ----------

function PerpTrade({ sym }: { sym: string }) {
  const { t, num } = useI18n()
  const c = useColors()
  const { snap, state } = useMarket(sym)
  const { account: acct, place, cancel, setTpsl, adjustMargin, setLeverage, loggedIn } = useAccount()
  const now = useNow()
  const [chart, setChart] = useState(false)
  const [kind, setKind] = useState<'limit' | 'market'>('limit')
  const [lev, setLev] = useState(20)
  const savedMode = marginMode.useValue()
  const [limitPx, setLimitPx] = useState('')
  const [size, setSize] = useState('')
  const [tab, setTab] = useState<'pos' | 'orders'>('pos')
  const [msg, setMsg] = useState('')
  const [levOpen, setLevOpen] = useState(false)
  const [notice, setNotice] = useToast()

  const pd = snap?.priceDec ?? 2
  const qd = snap?.qtyDec ?? 3
  const qDigits = Math.max(0, qd)
  const step = Math.pow(10, -qd)
  const last = snap ? snap.last || snap.mark : 0
  const mark = snap?.mark ?? 0
  const chg = snap && snap.open ? ((last - snap.open) / snap.open) * 100 : 0
  const tier = vipOf(acct).perp
  const maxLev = snap?.maxLev ?? 200
  const myPos = acct?.positions.find(p => p.sym === sym)
  const perpOrders = (acct?.orders ?? []).filter(o => !o.spot)

  useEffect(() => {
    if (!snap) return
    setLev(l => Math.max(1, Math.min(l, snap.maxLev)))
    setSize(s => (s ? s : (Math.max(step, Math.floor(100 / (snap.mark || 1) / step) * step)).toFixed(qDigits)))
  }, [snap, step, qDigits])

  const book = useGroupedBook(snap, sym, 8)
  const bestAsk = snap?.asks?.[0]?.[0] ?? last, bestBid = snap?.bids?.[0]?.[0] ?? last
  const px = kind === 'market' ? last : Number(limitPx.replace(/,/g, '.')) || last
  const qty = Number(size.replace(/,/g, '.')) || 0
  const notional = px * qty
  const useLev = myPos?.lev ?? lev
  const useMode = myPos ? (myPos.isolated ? 'isolated' : 'cross') : savedMode
  const margin = notional / useLev
  const takerLong = kind === 'market' || px >= bestAsk
  const takerShort = kind === 'market' || px <= bestBid
  const rateFor = (s: 'long' | 'short') => ((s === 'long' ? takerLong : takerShort) ? tier.taker.perp : tier.maker.perp)
  const estFee = feeFor(notional, Math.max(rateFor('long'), rateFor('short')))
  const avail = acct?.available ?? 0
  const estLiq = (long: boolean) => {
    if (!px || !qty) return 0
    if (useMode === 'isolated') return isolatedLiq(px, useLev, long)
    const cross = (acct?.positions ?? []).filter(x => !x.isolated && x.sym !== sym)
    const eq = avail + cross.reduce((a, x) => a + x.margin, 0) - Math.max(0, estFee)
    const maint = cross.reduce((a, x) => a + x.maint, 0) + mmrFor(useLev) * notional
    const q = long ? qty : -qty
    const v = px + (maint - eq) / (q - mmrFor(useLev) * qty)
    return v > 0 && Number.isFinite(v) ? v : 0
  }
  const canOpen = loggedIn && state === 'live' && qty > 0 && margin + Math.max(0, estFee) <= avail
  const maxQty = px > 0 ? (avail * useLev * 0.98) / px : 0
  const pctNow = maxQty > 0 ? Math.min(100, (qty / maxQty) * 100) : 0
  const setPct = (p: number) => setSize(p <= 0 ? '' : (Math.floor((maxQty * p / 100) / step) * step).toFixed(qDigits))
  const p = (v: number, d = pd) => num(v, d)

  const open = async (s: 'long' | 'short') => {
    if (!canOpen) return
    setMsg('')
    const r = await place({ symbol: sym, side: s === 'long' ? 'buy' : 'sell', type: kind, price: px, qty, leverage: useLev, marginMode: useMode })
    if (!r.ok) { warn(); setMsg(`${t('rejected')}: ${r.reason ? t(`err_${r.reason}`) : r.status ?? ''}`) }
    else {
      success()
      setTab(r.rested ? 'orders' : 'pos')
      setNotice(r.filled > 0 && r.price ? `${t('filledAt')} ${p(r.price)}` : r.status === 'cancelled' ? t('orderCancelled') : t('pc_confirm'))
    }
  }
  const closeQty = async (ps: SkyPosition, q: number) => {
    const r = await place({ symbol: ps.sym, side: ps.qty > 0 ? 'sell' : 'buy', type: 'market', qty: q, reduceOnly: true })
    if (r.ok) success(); else warn()
    setNotice(r.ok ? t('pc_closed') : `${t('rejected')}: ${r.reason ? t(`err_${r.reason}`) : r.status ?? ''}`)
  }
  const posTools: PosTools = {
    onClose: closeQty, onNotice: setNotice, setTpsl, adjustMargin, setLeverage,
    maxLev: ps => (ps.sym === sym ? maxLev : 200),
    onAdd: ps => openTrade(ps.sym, false), onOpen: ps => openTrade(ps.sym, false),
  }
  const countdown = (() => {
    const s = Math.floor(Math.max(0, (snap?.nextFunding ?? 0) - now) / 1000)
    return [Math.floor(s / 3600), Math.floor((s % 3600) / 60), s % 60].map(x => String(x).padStart(2, '0')).join(':')
  })()
  const sub = snap ? `${t('perpetual')} · ${snap.cat === 'onchain' ? snap.sub ?? t('onchain') : t(snap.cat === 'crypto' ? 'crypto' : snap.cat)}` : t('perpetual')

  if (state === 'missing') return <Screen><Empty text={`${sym} · ${t('noData')}`} /><Btn title="BTCUSDT" onPress={() => openTrade('BTCUSDT', false)} /></Screen>

  return (
    <View style={{ flex: 1 }}>
      <Screen>
        <PairHead snap={snap} sym={sym} spot={false} sub={sub} chart={chart} setChart={setChart} />
        <Row style={{ alignItems: 'flex-start' }}>
          <View style={{ flex: 1, minWidth: 0 }}>
            <Txt v="hero" num tone={chg >= 0 ? 'up' : 'down'} style={{ fontSize: 28 }}>{last ? p(last) : '—'}</Txt>
            <Chg v={chg} />
          </View>
          <View style={{ width: 170, gap: 3 }}>
            <Stat k={t('mark')} v={mark ? p(mark) : '—'} />
            <Stat k={t('funding')} v={<Txt v="tiny" num><Txt v="tiny" tone="gold">{pct(snap?.funding ?? 0)}</Txt> · {countdown}</Txt>} />
            <Stat k={t('dayVolume')} v={num(snap?.volUsdt ?? 0, 0)} />
          </View>
        </Row>
        {chart && <ChartBox snap={snap} last={last} digits={pd} />}

        <Row style={{ alignItems: 'flex-start' }} gap={12}>
          <View style={{ flex: 1.25, gap: 10, minWidth: 0 }}>
            <Seg items={[{ id: 'cross', label: t('cross') }, { id: 'isolated', label: t('isolated') }]} value={useMode}
              onChange={m => { if (!myPos) marginMode.set(m) }} />
            <Pressable onPress={() => { tap(); setLevOpen(true) }} style={[styles.levBtn, { backgroundColor: c.surface2 }]}>
              <Txt v="small" tone="muted">{t('leverage')}</Txt>
              <Row gap={4}><Txt bold num tone="gold">{useLev}x</Txt><Icon name="chevron.down" size={11} color={c.muted} /></Row>
            </Pressable>
            <Seg items={[{ id: 'limit', label: t('limit') }, { id: 'market', label: t('market') }]} value={kind} onChange={setKind} />
            <Row style={{ justifyContent: 'space-between' }}>
              <Txt v="tiny" tone="muted">{t('available')}</Txt><Txt v="tiny" num>{num(avail)} USDT</Txt>
            </Row>
            <Field value={kind === 'market' ? t('market') : limitPx} editable={kind === 'limit'} onChangeText={setLimitPx}
              placeholder={last ? last.toFixed(pd) : t('orderPrice')} keyboardType="decimal-pad" suffix="USDT" />
            <Field value={size} onChangeText={setSize} placeholder={t('size')} keyboardType="decimal-pad" suffix={snap?.base} />
            <PctSlider value={pctNow} onChange={setPct} disabled={!loggedIn || !maxQty} />
            {loggedIn ? (
              <View style={{ gap: 8 }}>
                <Btn kind="up" title={t('long')} disabled={!canOpen} onPress={() => open('long')} />
                <Btn kind="down" title={t('short')} disabled={!canOpen} onPress={() => open('short')} />
              </View>
            ) : <Gate />}
            {msg ? <Txt v="tiny" tone="down" center>{msg}</Txt> : null}
            <View style={{ gap: 3 }}>
              <Stat k={t('estimate')} v={`${num(margin)} USDT`} />
              <Stat k={t('fee')} v={`${num(estFee, 4)} USDT`} />
              <Stat k={`${t('feeRate')} · ${tierName(tier.level, t)}`} v={`${pct(tier.maker.perp)} / ${pct(tier.taker.perp)}`} />
              <Stat k={`${t('liqPrice')} · ${t('long')}`} v={myPos ? (myPos.liq ? p(myPos.liq) : '—') : estLiq(true) ? p(estLiq(true)) : '—'} />
              <Stat k={`${t('liqPrice')} · ${t('short')}`} v={myPos ? (myPos.liq ? p(myPos.liq) : '—') : estLiq(false) ? p(estLiq(false)) : '—'} />
            </View>
          </View>
          <View style={{ flex: 1, minWidth: 0 }}>
            <MiniBook asks={book.asks} bids={book.bids} max={book.max} last={last} up={chg >= 0} head={[t('price'), t('quantity')]}
              fp={v => num(v, book.digits)} fq={v => num(v, qDigits)} lastFmt={v => p(v)} sub={mark ? p(mark) : undefined}
              onPick={v => { setKind('limit'); setLimitPx(v.toFixed(pd)) }} />
            <RatioBar buyPct={book.buyPct} />
            <View style={{ marginTop: 8 }}><StepPicker step={book.step} steps={book.steps} onChange={book.setStep} /></View>
          </View>
        </Row>

        <Tabs style={{ paddingHorizontal: 0 }} items={[
          { id: 'pos', label: t('positions').replace(/\(\d+\)/, `(${acct?.positions.length ?? 0})`) },
          { id: 'orders', label: t('orders').replace(/\(\d+\)/, `(${perpOrders.length})`) },
        ]} value={tab} onChange={setTab} />
        {tab === 'pos'
          ? (acct?.positions.length ? acct.positions.map(ps => <PosCard key={ps.sym} ps={ps} acct={acct} tools={posTools} />) : <Empty text="—" />)
          : (perpOrders.length ? perpOrders.map(o => (
            <Card key={o.id}>
              <Row style={{ justifyContent: 'space-between' }}>
                <Row><Txt bold>{o.sym.replace(/@.*/, '')}</Txt><Txt v="small" tone={o.side === 'buy' ? 'up' : 'down'}>{o.side === 'buy' ? t('long') : t('short')}</Txt></Row>
                <Btn small kind="secondary" title={t('cancel')} onPress={() => { tap(); cancel(o.id) }} />
              </Row>
              <Stat k={t('orderPrice')} v={num(o.price, o.priceDec)} />
              <Stat k={t('quantity')} v={num(o.qty, Math.max(0, o.qtyDec))} />
              <Stat k={t('leverage')} v={o.reduceOnly ? t('reduceOnly') : `${t(o.isolated ? 'isolated' : 'cross')} ${o.lev}x`} />
            </Card>
          )) : <Empty text="—" />)}
        {loggedIn && <UsdtCard acct={acct} />}
      </Screen>
      <Toast text={notice} />

      {myPos
        ? <LeverageSheet visible={levOpen} ps={myPos} acct={acct} tools={posTools} onDone={() => setLevOpen(false)} />
        : (
          <Sheet visible={levOpen} title={t('leverage')} onClose={() => setLevOpen(false)}>
            <Txt v="hero" num center tone="gold">{lev}x</Txt>
            <Slider minimumValue={1} maximumValue={maxLev} step={1} value={lev} onValueChange={v => setLev(Math.round(v))}
              minimumTrackTintColor={c.gold} maximumTrackTintColor={c.line} thumbTintColor={c.gold} />
            <Row gap={6} style={{ flexWrap: 'wrap' }}>
              {LEV_MARKS.filter(l => l <= maxLev).map(l => <Btn key={l} small kind={lev === l ? 'primary' : 'secondary'} title={`${l}x`} onPress={() => setLev(l)} />)}
            </Row>
            {lev > 100 && <Txt v="small" tone="down">{t('highLevWarn')}</Txt>}
            <Stat k={t('maintMargin')} v={`${num(mmrFor(lev) * 100, 2)}%`} />
            <Btn title={t('app_done')} onPress={() => setLevOpen(false)} />
          </Sheet>
        )}
    </View>
  )
}

// ---------- spot ----------

function SpotTrade({ sym }: { sym: string }) {
  const { t, num } = useI18n()
  const { snap, state } = useMarket(sym, true)
  const { account: acct, place, cancel, loggedIn } = useAccount()
  const [chart, setChart] = useState(false)
  const [side, setSide] = useState<'buy' | 'sell'>('buy')
  const [kind, setKind] = useState<'limit' | 'market'>('limit')
  const [tab, setTab] = useState<'orders' | 'holdings'>('orders')
  const [px, setPx] = useState('')
  const [amt, setAmt] = useState('')
  const [msg, setMsg] = useState('')
  const [notice, setNotice] = useToast()

  const pd = snap?.priceDec ?? 2
  const qd = snap?.qtyDec ?? 3
  const qDigits = Math.max(0, qd)
  const step = Math.pow(10, -qd)
  const last = snap ? snap.last || snap.mark : 0
  const chg = snap && snap.open ? ((last - snap.open) / snap.open) * 100 : 0
  const tier = vipOf(acct).spot
  const fee = kind === 'market' ? tier.taker.spot : tier.maker.spot
  const bal = acct?.balances.find(b => b.sym === sym)
  const free = side === 'buy' ? acct?.available ?? 0 : bal?.free ?? 0
  const book = useGroupedBook(snap, sym, 8)
  const spotOrders = (acct?.orders ?? []).filter(o => o.spot)
  const p = (v: number) => num(v, pd)

  const price = kind === 'market' ? last : Number(px.replace(/,/g, '.')) || last
  const qty = Number(amt.replace(/,/g, '.')) || 0
  const total = price * qty
  const fit = (v: number) => (Math.floor(v / step) * step).toFixed(qDigits)
  const maxQty = !price ? 0 : side === 'buy' ? free / price / (1 + Math.max(fee, 0)) : free
  const pctNow = maxQty > 0 ? Math.min(100, (qty / maxQty) * 100) : 0
  const enough = side === 'buy' ? total * (1 + Math.max(fee, 0)) <= free : qty <= free + 1e-12
  const ok = loggedIn && state === 'live' && qty > 0 && enough
  const sub = snap ? `${t('spot')} · ${t(snap.cat === 'crypto' ? 'crypto' : snap.cat)}` : t('spot')

  const submit = async () => {
    setMsg('')
    const r = await place({ market: 'spot', symbol: sym, side, type: kind, price, qty })
    if (!r.ok) { warn(); setMsg(`${t('rejected')}: ${r.reason ? t(`err_${r.reason}`) : r.status ?? ''}`) }
    else {
      success(); setAmt('')
      if (r.rested) setTab('orders')
      setNotice(r.filled > 0 && r.price ? `${t('filledAt')} ${p(r.price)}` : t('pc_confirm'))
    }
  }

  if (state === 'missing') return <Screen><Empty text={`${sym} · ${t('noData')}`} /><Btn title="BTC/USDT" onPress={() => openTrade('BTCUSDT', true)} /></Screen>

  return (
    <View style={{ flex: 1 }}>
      <Screen>
        <PairHead snap={snap} sym={sym} spot sub={sub} chart={chart} setChart={setChart} />
        <Row style={{ alignItems: 'flex-start' }}>
          <View style={{ flex: 1, minWidth: 0 }}>
            <Txt v="hero" num tone={chg >= 0 ? 'up' : 'down'} style={{ fontSize: 28 }}>{last ? p(last) : '—'}</Txt>
            <Chg v={chg} />
          </View>
          <View style={{ width: 170, gap: 3 }}>
            <Stat k={t('dayHigh')} v={snap?.high ? p(snap.high) : '—'} />
            <Stat k={t('dayLow')} v={snap?.low ? p(snap.low) : '—'} />
            <Stat k={t('dayVolume')} v={num(snap?.volUsdt ?? 0, 0)} />
          </View>
        </Row>
        {chart && <ChartBox snap={snap} last={last} digits={pd} />}

        <Row style={{ alignItems: 'flex-start' }} gap={12}>
          <View style={{ flex: 1.25, gap: 10, minWidth: 0 }}>
            <Row gap={6}>
              <Btn small kind={side === 'buy' ? 'up' : 'secondary'} title={t('buyBtn')} onPress={() => { setSide('buy'); setAmt('') }} style={{ flex: 1 }} />
              <Btn small kind={side === 'sell' ? 'down' : 'secondary'} title={t('sellBtn')} onPress={() => { setSide('sell'); setAmt('') }} style={{ flex: 1 }} />
            </Row>
            <Seg items={[{ id: 'limit', label: t('limit') }, { id: 'market', label: t('market') }]} value={kind} onChange={setKind} />
            <Row style={{ justifyContent: 'space-between' }}>
              <Txt v="tiny" tone="muted">{t('available')}</Txt>
              <Txt v="tiny" num>{num(free, side === 'buy' ? 2 : qDigits)} {side === 'buy' ? 'USDT' : snap?.base}</Txt>
            </Row>
            <Field value={kind === 'market' ? t('market') : px} editable={kind === 'limit'} onChangeText={setPx}
              placeholder={last ? last.toFixed(pd) : t('price')} keyboardType="decimal-pad" suffix="USDT" />
            <Field value={amt} onChangeText={setAmt} placeholder={t('quantity')} keyboardType="decimal-pad" suffix={snap?.base} />
            <PctSlider value={pctNow} onChange={pc => { if (price) setAmt(pc <= 0 ? '' : fit(maxQty * pc / 100)) }} disabled={!loggedIn || !maxQty} />
            <Field value={total ? total.toFixed(2) : ''} placeholder={t('orderTotal')} keyboardType="decimal-pad" suffix="USDT"
              onChangeText={v => price && setAmt(fit((Number(v.replace(/,/g, '.')) || 0) / price))} />
            <Stat k={t('fee')} v={`≈ ${num(feeFor(total, fee), 4)} USDT`} />
            {loggedIn
              ? <Btn kind={side === 'buy' ? 'up' : 'down'} title={`${side === 'buy' ? t('buyBtn') : t('sellBtn')} ${snap?.base ?? ''}`} disabled={!ok} onPress={submit} />
              : <Gate />}
            {msg ? <Txt v="tiny" tone="down" center>{msg}</Txt> : null}
            <Stat k={`${t('feeRate')} · ${tierName(tier.level, t)}`} v={`${pct(tier.maker.spot)} / ${pct(tier.taker.spot)}`} />
          </View>
          <View style={{ flex: 1, minWidth: 0 }}>
            <MiniBook asks={book.asks} bids={book.bids} max={book.max} last={last} up={chg >= 0} head={[t('price'), t('quantity')]}
              fp={v => num(v, book.digits)} fq={v => num(v, qDigits)} lastFmt={p}
              onPick={v => { setKind('limit'); setPx(v.toFixed(pd)) }} />
            <RatioBar buyPct={book.buyPct} />
            <View style={{ marginTop: 8 }}><StepPicker step={book.step} steps={book.steps} onChange={book.setStep} /></View>
          </View>
        </Row>

        <Tabs style={{ paddingHorizontal: 0 }} items={[
          { id: 'orders', label: t('orders').replace(/\(\d+\)/, `(${spotOrders.length})`) },
          { id: 'holdings', label: `${t('holdingsSpot')} (${acct?.balances.length ?? 0})` },
        ]} value={tab} onChange={setTab} />
        {tab === 'orders'
          ? (spotOrders.length ? spotOrders.map(o => (
            <Card key={o.id}>
              <Row style={{ justifyContent: 'space-between' }}>
                <Row><Txt bold>{o.sym.replace(/USDT$/, '')}/USDT</Txt><Txt v="small" tone={o.side === 'buy' ? 'up' : 'down'}>{o.side === 'buy' ? t('buyBtn') : t('sellBtn')}</Txt></Row>
                <Btn small kind="secondary" title={t('cancel')} onPress={() => { tap(); cancel(o.id) }} />
              </Row>
              <Stat k={t('price')} v={num(o.price, o.priceDec)} />
              <Stat k={t('quantity')} v={num(o.qty, Math.max(0, o.qtyDec))} />
              <Stat k={t('orderTotal')} v={num(o.price * o.qty, 2)} />
            </Card>
          )) : <Empty text="—" />)
          : (acct?.balances.length ? acct.balances.map(b => (
            <Card key={b.sym} onPress={() => openTrade(b.sym, true)}>
              <Row style={{ justifyContent: 'space-between' }}>
                <Row><MarketIcon it={{ base: b.base, cat: b.cat }} size={24} /><Txt bold>{b.base}</Txt></Row>
                <Txt num bold>{num(b.value)} USDT</Txt>
              </Row>
              <Stat k={t('available')} v={num(b.free, Math.max(0, b.qtyDec))} />
              <Stat k={t('avgCost')} v={num(b.avgCost, b.priceDec)} />
              <Stat k={t('pnl')} v={<Txt v="tiny" num tone={b.pnl >= 0 ? 'up' : 'down'}>{b.pnl >= 0 ? '+' : '−'}{num(Math.abs(b.pnl))}</Txt>} />
            </Card>
          )) : <Empty text="—" />)}
      </Screen>
      <Toast text={notice} />
    </View>
  )
}

const styles = StyleSheet.create({
  levBtn: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', height: 40, borderRadius: 10, paddingHorizontal: 12 },
  toast: { position: 'absolute', left: 40, right: 40, bottom: 110, padding: 12, borderRadius: 12, borderWidth: StyleSheet.hairlineWidth },
})
