// Order-book grouping (same rules as the website's BookTools): steps are the
// tick, then 10× (and 5×) steps up to ~2% of the price; asks round up, bids
// round down; a far bucket the depth only partly covers is dropped.
import { useEffect, useMemo, useState } from 'react'
import { loadJSON, saveJSON } from '@/lib/storage'
import type { SkySnap } from '@/lib/sky'
import { perpDepth, spotDepth, type Level } from '@/web/market/binance'

export type BookLevel = { p: number; q: number; cum: number }

const clean = (v: number) => Number(v.toPrecision(12))

export const stepDigits = (step: number) => Math.max(0, Math.ceil(-Math.log10(step) - 1e-9))

export function groupSteps(price: number, pd: number): number[] {
  const tick = clean(Math.pow(10, -pd))
  const cap = Math.max(tick, price * 0.02)
  const out: number[] = []
  for (let d = tick; d <= cap * (1 + 1e-9) && out.length < 16; d = clean(d * 10)) {
    out.push(d)
    if (d > tick && d * 5 <= cap) out.push(clean(d * 5))
  }
  out.sort((a, b) => a - b)
  while (out.length > 7) {
    const i = out.findIndex(v => String(v).replace(/0|\./g, '').startsWith('5'))
    out.splice(i >= 0 ? i : 1, 1)
  }
  return out
}

export function groupLevels(levels: Level[], step: number, side: 'ask' | 'bid', rows: number): BookLevel[] {
  const m = new Map<number, number>()
  let far = side === 'ask' ? -Infinity : Infinity
  for (const [p, q] of levels) {
    const k = clean((side === 'ask' ? Math.ceil(p / step - 1e-9) : Math.floor(p / step + 1e-9)) * step)
    m.set(k, (m.get(k) ?? 0) + q)
    far = side === 'ask' ? Math.max(far, p) : Math.min(far, p)
  }
  const keys = [...m.entries()].sort((a, b) => (side === 'ask' ? a[0] - b[0] : b[0] - a[0]))
  const last = keys[keys.length - 1]
  if (keys.length > 1 && last && (side === 'ask' ? far < last[0] - step * 1e-6 : far > last[0] + step * 1e-6)) keys.pop()
  let c = 0
  return keys.slice(0, rows).map(([p, q]) => ({ p, q, cum: (c += q) }))
}

export function spanOf(b: { bids: Level[]; asks: Level[] }) {
  const a = b.asks.map(x => x[0]), d = b.bids.map(x => x[0])
  if (!a.length || !d.length) return 0
  return Math.min(Math.max(...a) - Math.min(...a), Math.max(...d) - Math.min(...d))
}

/** Binance's deeper book (1,000 levels) for coarse steps: every 2 s when shown, else every 30 s. */
function useWideDepth(snap: SkySnap | undefined, fast: boolean) {
  const [d, setD] = useState<{ key: string; bids: Level[]; asks: Level[] }>()
  const ref = snap?.ref, perp = snap?.quoteVenue === 'perp' || (!snap?.quoteVenue && snap?.src === 'perp')
  const ok = !!ref && (snap?.src === 'spot' || snap?.src === 'perp')
  const key = `${ref}|${perp}`
  useEffect(() => {
    if (!ok || !ref) return
    let alive = true
    const load = () => { (perp ? perpDepth(ref, 1000) : spotDepth(ref, 1000)).then(b => { if (alive) setD({ key, ...b }) }).catch(() => undefined) }
    load()
    const id = setInterval(load, fast ? 2000 : 30_000)
    return () => { alive = false; clearInterval(id) }
  }, [ok, ref, perp, key, fast])
  return ok && d?.key === key ? d : undefined
}

let savedSteps: Record<string, number> = {}
loadJSON<Record<string, number>>('sky.bookSteps', {}).then(v => { savedSteps = v })

/** The book as shown: grouped by the chosen step, `rows` levels a side, asks farthest-first. */
export function useGroupedBook(snap: SkySnap | undefined, sym: string, rows: number) {
  const pd = snap?.priceDec ?? 2
  const ref = snap ? snap.last || snap.mark : 0
  const bucket = Math.round(Math.log10(Math.max(ref, 1e-12)) * 4)
  const all = useMemo(() => groupSteps(ref, pd), [bucket, pd]) // eslint-disable-line react-hooks/exhaustive-deps
  const [chosen, setChosen] = useState(savedSteps[sym] ?? 0)
  useEffect(() => { setChosen(savedSteps[sym] ?? 0) }, [sym])
  const wide = useWideDepth(snap, chosen >= (all[0] ?? 0) * 10)
  const span = spanOf(wide ?? { bids: snap?.bids ?? [], asks: snap?.asks ?? [] })
  const steps = all.filter((v, i) => i === 0 || span / v >= 3)
  const step = steps.includes(chosen) ? chosen : steps[0] ?? Math.pow(10, -pd)
  const setStep = (v: number) => { setChosen(v); savedSteps = { ...savedSteps, [sym]: v }; saveJSON('sky.bookSteps', savedSteps) }
  const book = useMemo(() => {
    const src = wide ?? { bids: snap?.bids ?? [], asks: snap?.asks ?? [] }
    const a = groupLevels(src.asks, step, 'ask', rows), b = groupLevels(src.bids, step, 'bid', rows)
    const sa = a[a.length - 1]?.cum ?? 0, sb = b[b.length - 1]?.cum ?? 0
    return { asks: [...a].reverse(), bids: b, max: Math.max(sa, sb, 1e-12), buyPct: sa + sb > 0 ? Math.round((sb / (sa + sb)) * 100) : 50 }
  }, [wide, snap?.bids, snap?.asks, step, rows]) // eslint-disable-line react-hooks/exhaustive-deps
  return { ...book, step, steps, setStep, digits: Math.min(pd, stepDigits(step)) }
}
