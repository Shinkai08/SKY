// Client for skyd (SKY's own matching service): account, markets, charts.
// Mirrors the website's market/sky.ts; the market stream is replaced by
// 1 s snapshot polling (no EventSource in React Native) that pauses while
// the screen is hidden or the app is in the background.
import { useIsFocused } from 'expo-router'
import { createContext, createElement, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from 'react'
import { AppState } from 'react-native'
import type { Candle } from '@/web/data'
import { api, ApiError } from './api'
import { useAuth } from './auth'

export type MarketSpec = {
  sym: string; base: string; name?: string; cat: string; sub?: string; src: 'spot' | 'perp' | 'alpha' | 'local'; ref?: string; icon?: string
  priceDec: number; qtyDec: number; maxLev: number; bandPpm: number; vol24h: number; spot?: boolean
  totalShares?: number
}
export type SkyTrade = { id: number; price: number; qty: number; buy: boolean; t: number }
export type SkySnap = MarketSpec & {
  t: number; bid: number; ask: number; live: boolean; quoteVenue: 'perp' | 'spot' | ''
  last: number; mark: number; index: number; open: number; high: number; low: number
  volBase: number; volUsdt: number; funding: number; nextFunding: number
  bids: [number, number][]; asks: [number, number][]; trades: SkyTrade[]; tradeCount: number
}
export type SkyPosition = {
  sym: string; base: string; qty: number; entry: number; mark: number; upnl: number; lev: number; margin: number
  isolated: boolean; liq: number; maint: number; priceDec: number; qtyDec: number
  realized?: number; tp?: number; sl?: number; removable?: number; maxLev?: number
}
export type SkyBalance = {
  sym: string; base: string; cat: string; free: number; locked: number; mark: number; value: number
  avgCost: number; pnl: number; priceDec: number; qtyDec: number
}
export type SkyOrderRow = {
  id: number; sym: string; side: 'buy' | 'sell'; price: number; qty: number; priceDec: number; qtyDec: number; spot: boolean
  lev: number; isolated: boolean; reduceOnly: boolean
}
export type SkyAccount = {
  wallet: number; equity: number; available: number; margin: number; upnl: number; leverage: number
  fees: number; volume: number; liquidations: number
  positions: SkyPosition[]
  orders: SkyOrderRow[]
  spotValue: number; spotLocked: number; total: number; balances: SkyBalance[]
  usdtUsd?: number
  vip?: {
    spot: number; perp: number; assets: number; vol30Spot: number; vol30Perp: number
    spotMaker: number; spotTaker: number; perpMaker: number; perpTaker: number
  }
}
export type PosToolResult = { ok: boolean; reason?: string }
export type SkyOrder = {
  market?: 'spot'; symbol: string; side: 'buy' | 'sell'; type: 'limit' | 'market'; price?: number; qty: number; leverage?: number; reduceOnly?: boolean
  marginMode?: 'cross' | 'isolated'; tif?: 'gtc' | 'ioc' | 'fok' | 'post_only'
}
export type SkyOrderResult = { ok: boolean; id?: number; status?: string; filled: number; price?: number; rested: boolean; reason?: string }

/** True while the app is in the foreground. */
export function useAppActive() {
  const [active, setActive] = useState(AppState.currentState === 'active')
  useEffect(() => {
    const sub = AppState.addEventListener('change', s => setActive(s === 'active'))
    return () => sub.remove()
  }, [])
  return active
}

/** Runs `fn` now and every `ms` while the screen is focused and the app is active. */
export function usePoll(fn: () => void, ms: number, deps: unknown[]) {
  const focused = useIsFocused()
  const active = useAppActive()
  const ref = useRef(fn)
  ref.current = fn
  useEffect(() => {
    if (!focused || !active) return
    ref.current()
    const id = setInterval(() => ref.current(), ms)
    return () => clearInterval(id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [focused, active, ms, ...deps])
}

type AccountCtx = {
  account?: SkyAccount
  refresh: () => Promise<void>
  place: (o: SkyOrder) => Promise<SkyOrderResult>
  cancel: (id: number) => Promise<void>
  setTpsl: (symbol: string, tp: number, sl: number) => Promise<PosToolResult>
  adjustMargin: (symbol: string, amount: number) => Promise<PosToolResult>
  setLeverage: (symbol: string, leverage: number) => Promise<PosToolResult>
  loggedIn: boolean
}
const Ctx = createContext<AccountCtx | null>(null)

/** One account poll for the whole app (every 1.5 s while active and logged in). */
export function AccountProvider({ children }: { children: ReactNode }) {
  const { me } = useAuth()
  const active = useAppActive()
  const [account, setAccount] = useState<SkyAccount>()
  const refresh = useCallback(async () => {
    if (!me) { setAccount(undefined); return }
    try {
      setAccount(await api<SkyAccount>('/account'))
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) setAccount(undefined)
    }
  }, [me])
  useEffect(() => {
    if (!me) { setAccount(undefined); return }
    if (!active) return
    refresh()
    const id = setInterval(refresh, 1500)
    return () => clearInterval(id)
  }, [me, active, refresh])
  const place = useCallback(async (o: SkyOrder): Promise<SkyOrderResult> => {
    try {
      const res = await api<SkyOrderResult>('/order', { body: o })
      refresh()
      return res
    } catch (e) {
      return { ok: false, filled: 0, rested: false, reason: e instanceof ApiError ? e.code : 'service_unavailable' }
    }
  }, [refresh])
  const cancel = useCallback(async (id: number) => {
    await api('/cancel', { body: { id } }).catch(() => undefined)
    refresh()
  }, [refresh])
  const tool = useCallback(async (path: string, body: object): Promise<PosToolResult> => {
    try {
      const res = await api<PosToolResult>(path, { body })
      refresh()
      return res
    } catch (e) {
      return { ok: false, reason: e instanceof ApiError ? (e.status === 404 ? 'service_unavailable' : e.code) : 'service_unavailable' }
    }
  }, [refresh])
  const value: AccountCtx = {
    account, refresh, place, cancel, loggedIn: !!me,
    setTpsl: (symbol, tp, sl) => tool('/position/tpsl', { symbol, tp, sl }),
    adjustMargin: (symbol, amount) => tool('/position/margin', { symbol, amount }),
    setLeverage: (symbol, leverage) => tool('/position/leverage', { symbol, leverage }),
  }
  return createElement(Ctx.Provider, { value }, children)
}

export function useAccount() {
  const c = useContext(Ctx)
  if (!c) throw new Error('useAccount outside AccountProvider')
  return c
}

/** Maintenance margin rate SKY applies at a leverage (mirrors exchange.mmrFor). */
export const mmrFor = (lev: number) => Math.min(0.005, 1 / (2 * Math.max(1, lev)))

/** Liquidation price of a new isolated position opened at `entry`. */
export function isolatedLiq(entry: number, lev: number, long: boolean) {
  const mmr = mmrFor(lev)
  return long ? (entry * (1 - 1 / lev)) / (1 - mmr) : (entry * (1 + 1 / lev)) / (1 + mmr)
}

/** Live order book / trades / ticker of one SKY market (1 s snapshots while visible). */
export function useMarket(sym: string, spot = false) {
  const [snap, setSnap] = useState<SkySnap>()
  const [state, setState] = useState<'loading' | 'live' | 'offline' | 'missing'>('loading')
  const busy = useRef(false)
  const key = `${sym}|${spot}`
  useEffect(() => { setSnap(undefined); setState('loading') }, [key])
  usePoll(() => {
    if (busy.current) return
    busy.current = true
    api<SkySnap>(`/snapshot?sym=${encodeURIComponent(sym)}${spot ? '&type=spot' : ''}`)
      .then(s => { setSnap(s); setState('live') })
      .catch(e => setState(e instanceof ApiError && e.status === 404 ? 'missing' : s => (s === 'missing' ? s : 'offline')))
      .finally(() => { busy.current = false })
  }, 1000, [key])
  return { snap, state }
}

const TF: Record<string, { binance: string; minutes: number }> = {
  '1m': { binance: '1m', minutes: 1 }, '5m': { binance: '5m', minutes: 5 },
  '15m': { binance: '15m', minutes: 15 }, '1h': { binance: '1h', minutes: 60 },
  '4h': { binance: '4h', minutes: 240 }, '1d': { binance: '1d', minutes: 1440 },
}

/** Chart history: Binance klines (via skyd) for listed reference symbols, SKY's own otherwise. */
export function useKlines(spec: Pick<MarketSpec, 'sym' | 'src' | 'ref' | 'spot'> | undefined, tf: string) {
  const [candles, setCandles] = useState<Candle[]>([])
  const key = spec ? `${spec.sym}|${spec.src}|${spec.ref ?? ''}|${spec.spot ? 's' : 'p'}|${tf}` : ''
  useEffect(() => { setCandles([]) }, [key])
  usePoll(() => {
    if (!spec) return
    const t = TF[tf] ?? TF['1h']
    const load = async () => {
      if (spec.ref && (spec.src === 'spot' || spec.src === 'perp' || spec.src === 'alpha')) {
        const rows = await api<[number, string, string, string, string, string][]>(
          `/klines/ref?sym=${encodeURIComponent(spec.ref)}&i=${t.binance}${spec.src === 'perp' ? '&perp=1' : ''}`)
        return rows.map(k => ({ t: k[0], o: +k[1], h: +k[2], l: +k[3], c: +k[4], v: +k[5] }))
      }
      const rows = await api<Candle[]>(`/klines?sym=${encodeURIComponent(spec.sym)}&m=${t.minutes}${spec.spot ? '&type=spot' : ''}`)
      return rows.map(r => ({ t: r.t, o: r.o, h: r.h, l: r.l, c: r.c, v: r.v }))
    }
    load().then(setCandles).catch(() => undefined)
  }, spec?.src === 'local' ? 5000 : 30_000, [key])
  return candles
}
