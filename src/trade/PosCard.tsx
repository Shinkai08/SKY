import Slider from '@react-native-community/slider'
import * as Clipboard from 'expo-clipboard'
import { useState } from 'react'
import { Pressable, Share, StyleSheet, View } from 'react-native'
import { success, tap, warn } from '@/lib/haptics'
import { useI18n } from '@/lib/i18n'
import type { PosToolResult, SkyAccount, SkyPosition } from '@/lib/sky'
import { useColors } from '@/lib/theme'
import { Btn, Field, Icon, Row, Seg, Txt } from '@/ui/kit'
import { Sheet } from '@/ui/Sheet'

// Open-position card (the website's PosCard): side, margin mode, leverage,
// risk, PnL with return on margin, figures, and close / TP-SL / margin /
// leverage tools in native sheets.

export type PosTools = {
  onClose: (ps: SkyPosition, qty: number) => Promise<unknown>
  onAdd: (ps: SkyPosition) => void
  onNotice: (msg: string) => void
  setTpsl: (symbol: string, tp: number, sl: number) => Promise<PosToolResult>
  adjustMargin: (symbol: string, amount: number) => Promise<PosToolResult>
  setLeverage: (symbol: string, leverage: number) => Promise<PosToolResult>
  onOpen: (ps: SkyPosition) => void
  maxLev?: (ps: SkyPosition) => number
}

export function marginRatio(ps: SkyPosition, acct?: SkyAccount) {
  if (ps.isolated) return ps.maint > 0 ? (ps.margin + ps.upnl) / ps.maint : 0
  const iso = (acct?.positions ?? []).filter(x => x.isolated).reduce((a, x) => a + x.margin + x.upnl, 0)
  const maint = (acct?.positions ?? []).filter(x => !x.isolated).reduce((a, x) => a + x.maint, 0)
  return maint > 0 ? ((acct?.equity ?? 0) - iso) / maint : 0
}

function RiskBars({ ratio }: { ratio: number }) {
  const c = useColors()
  const risk = ratio > 0 ? 1 / ratio : 0
  const n = Math.max(1, Math.min(5, Math.ceil(risk * 5)))
  const col = risk >= 0.7 ? c.red : risk >= 0.4 ? '#f0a03c' : c.green
  return <Row gap={2}>{[0, 1, 2, 3, 4].map(i => <View key={i} style={{ width: 3, height: 6 + i * 2, borderRadius: 1, backgroundColor: i < n ? col : c.line }} />)}</Row>
}

const toNum = (s: string) => { const v = Number(s.replace(/,/g, '.')); return Number.isFinite(v) && v > 0 ? v : 0 }

function Fact({ k, v, tone, right }: { k: string; v: string; tone?: 'up' | 'down' | 'gold'; right?: boolean }) {
  return (
    <View style={{ flex: 1, alignItems: right ? 'flex-end' : 'flex-start', gap: 2 }}>
      <Txt v="tiny" tone="muted">{k}</Txt>
      <Txt v="small" num bold tone={tone}>{v}</Txt>
    </View>
  )
}

export function PosCard({ ps, acct, tools }: { ps: SkyPosition; acct?: SkyAccount; tools: PosTools }) {
  const { t, num } = useI18n()
  const c = useColors()
  const [closing, setClosing] = useState(false)
  const [pctSel, setPctSel] = useState(100)
  const [busy, setBusy] = useState(false)
  const [sheet, setSheet] = useState<'margin' | 'tpsl' | 'lev' | null>(null)
  const long = ps.qty > 0
  const qd = Math.max(0, ps.qtyDec)
  const step = Math.pow(10, -ps.qtyDec)
  const roe = ps.margin > 0 ? (ps.upnl / ps.margin) * 100 : 0
  const ratio = marginRatio(ps, acct)
  const notional = Math.abs(ps.qty) * ps.mark
  const closeQty = Math.min(Math.abs(ps.qty), Math.floor((Math.abs(ps.qty) * pctSel / 100) / step + 1e-9) * step)
  const sign = (v: number, d = 2) => `${v >= 0 ? '+' : '−'}${num(Math.abs(v), d === 2 && v !== 0 && Math.abs(v) < 0.01 ? 4 : d)}`
  const px = (v: number) => num(v, ps.priceDec)
  const tooled = ps.realized !== undefined
  const hasTrig = !!(ps.tp || ps.sl)

  const run = async (qty: number) => {
    if (busy || qty <= 0) return
    setBusy(true)
    try { await tools.onClose(ps, qty); setClosing(false) } finally { setBusy(false) }
  }
  const share = () => {
    const text = `SKY · ${ps.base}USDT ${t('pc_perp')} ${long ? t('pc_long') : t('pc_short')} ${ps.lev}x · ${sign(roe)}%`
    Share.share({ message: text }).catch(() => Clipboard.setStringAsync(text).then(() => tools.onNotice(t('copied'))))
  }
  const tag = (label: string, bg: string, fg: string) => (
    <View style={[styles.tag, { backgroundColor: bg }]}><Txt v="tiny" bold style={{ color: fg }}>{label}</Txt></View>
  )

  return (
    <View style={[styles.card, { backgroundColor: c.surface, borderColor: c.line }]}>
      <Pressable onPress={() => { tap(); tools.onOpen(ps) }} style={{ gap: 8 }}>
        <Row style={{ justifyContent: 'space-between' }}>
          <Row gap={4}><Txt bold>{ps.base}USDT {t('pc_perp')}</Txt><Icon name="chevron.right" size={12} color={c.muted} /></Row>
          <Pressable hitSlop={8} onPress={share}><Icon name="square.and.arrow.up" size={16} color={c.muted} /></Pressable>
        </Row>
        <Row gap={6}>
          {tag(long ? t('pc_long') : t('pc_short'), long ? c.upTint : c.downTint, long ? c.up : c.down)}
          {tag(t(ps.isolated ? 'isolated' : 'cross'), c.surface2, c.ink2)}
          {tooled && ps.maxLev !== undefined
            ? <Pressable onPress={() => { tap(); setSheet('lev') }}>{tag(`${ps.lev}x ✎`, c.surface2, c.gold)}</Pressable>
            : tag(`${ps.lev}x`, c.surface2, c.ink2)}
          <RiskBars ratio={ratio} />
        </Row>
        <View style={{ gap: 2 }}>
          <Txt v="tiny" tone="muted">{t('pc_pnl')}</Txt>
          <Txt v="title" num tone={ps.upnl >= 0 ? 'up' : 'down'}>{sign(ps.upnl)} <Txt v="h2" num tone={ps.upnl >= 0 ? 'up' : 'down'}>({sign(roe)}%)</Txt></Txt>
        </View>
        <Row>
          <Fact k={t('pc_size')} v={num(notional)} />
          <Pressable style={{ flex: 1 }} disabled={!(tooled && ps.isolated)} onPress={() => { tap(); setSheet('margin') }}>
            <Fact k={t('pc_margin') + (tooled && ps.isolated ? ' ⊕' : '')} v={num(ps.margin)} />
          </Pressable>
          <Fact k={t('pc_mmr')} v={ratio > 0 ? `${num(ratio * 100, 2)}%` : '—'} right />
        </Row>
        <Row>
          <Fact k={t('pc_entry')} v={px(ps.entry)} />
          <Fact k={t('pc_mark')} v={px(ps.mark)} />
          <Fact k={t('pc_liq')} v={ps.liq ? px(ps.liq) : '—'} tone="gold" right />
        </Row>
        {(tooled || hasTrig) && (
          <Row>
            {tooled && <Fact k={t('pc_realized')} v={sign(ps.realized ?? 0)} tone={(ps.realized ?? 0) >= 0 ? 'up' : 'down'} />}
            {hasTrig && <Fact k={`${t('pc_tp')} / ${t('pc_sl')}`} v={`${ps.tp ? px(ps.tp) : '—'} / ${ps.sl ? px(ps.sl) : '—'}`} right />}
          </Row>
        )}
      </Pressable>

      {closing && (
        <View style={[styles.closer, { backgroundColor: c.surface2 }]}>
          <Seg items={[25, 50, 75, 100].map(v => ({ id: String(v), label: `${v}%` }))} value={String(pctSel)} onChange={v => setPctSel(Number(v))} />
          <Row style={{ justifyContent: 'space-between' }}>
            <Txt v="small" tone="muted">{t('quantity')}</Txt><Txt v="small" num>{num(closeQty, qd)} {ps.base}</Txt>
          </Row>
          <Row>
            <Btn small kind="secondary" title={t('pc_back')} onPress={() => setClosing(false)} style={{ flex: 1 }} />
            <Btn small kind={long ? 'down' : 'up'} title={t('pc_closeMarket')} busy={busy} disabled={closeQty <= 0} onPress={() => run(closeQty)} style={{ flex: 1 }} />
          </Row>
        </View>
      )}

      <Row gap={6}>
        <Btn small kind="secondary" title={t('pc_add')} onPress={() => tools.onAdd(ps)} style={{ flex: 1 }} />
        <Btn small kind="secondary" title={t('pc_tpsl')} onPress={() => (tooled ? setSheet('tpsl') : tools.onNotice(t('pc_tpslSoon')))} style={[{ flex: 1 }, hasTrig && { borderWidth: 1, borderColor: c.gold }]} />
        <Btn small kind="secondary" title={t('pc_close')} onPress={() => { setPctSel(100); setClosing(v => !v) }} style={{ flex: 1 }} />
        <Btn small kind="secondary" title={t('pc_closeAll')} busy={busy} onPress={() => run(Math.abs(ps.qty))} style={{ flex: 1 }} />
      </Row>

      <MarginSheet visible={sheet === 'margin'} ps={ps} acct={acct} tools={tools} onDone={() => setSheet(null)} />
      <TpslSheet visible={sheet === 'tpsl'} ps={ps} tools={tools} onDone={() => setSheet(null)} />
      <LeverageSheet visible={sheet === 'lev'} ps={ps} acct={acct} tools={tools} onDone={() => setSheet(null)} />
    </View>
  )
}

function Facts({ rows }: { rows: [string, string, ('up' | 'down' | 'gold')?][] }) {
  return (
    <View style={{ gap: 8 }}>
      {rows.map(([k, v, tone]) => (
        <Row key={k} style={{ justifyContent: 'space-between' }}><Txt v="small" tone="muted">{k}</Txt><Txt v="small" num tone={tone}>{v}</Txt></Row>
      ))}
    </View>
  )
}

function MarginSheet({ visible, ps, acct, tools, onDone }: { visible: boolean; ps: SkyPosition; acct?: SkyAccount; tools: PosTools; onDone: () => void }) {
  const { t, num } = useI18n()
  const [mode, setMode] = useState<'add' | 'remove'>('add')
  const [amt, setAmt] = useState('')
  const [err, setErr] = useState('')
  const [busy, setBusy] = useState(false)
  const max = Math.max(0, Math.floor((mode === 'add' ? acct?.available ?? 0 : ps.removable ?? 0) * 100) / 100)
  const v = toNum(amt)
  const submit = async () => {
    if (busy || v <= 0) return
    setBusy(true); setErr('')
    const r = await tools.adjustMargin(ps.sym, mode === 'add' ? v : -v)
    setBusy(false)
    if (r.ok) { success(); tools.onNotice(t('pc_marginSaved')); setAmt(''); onDone() } else { warn(); setErr(t(`err_${r.reason ?? 'service_unavailable'}`)) }
  }
  return (
    <Sheet visible={visible} title={`${t('pc_marginTitle')} · ${ps.base}USDT`} onClose={onDone}>
      <Seg items={[{ id: 'add', label: t('pc_marginAdd') }, { id: 'remove', label: t('pc_marginRemove') }]} value={mode} onChange={m => { setMode(m); setAmt(''); setErr('') }} />
      <Field label={t('pc_amount')} value={amt} onChangeText={setAmt} placeholder="0.00" keyboardType="decimal-pad" suffix="USDT" />
      <Btn small kind="ghost" title={`${t('pc_max')} ${num(max)}`} onPress={() => setAmt(max.toFixed(2))} />
      <Facts rows={[[t('pc_curMargin'), `${num(ps.margin)} USDT`], [t(mode === 'add' ? 'pc_canAdd' : 'pc_canRemove'), `${num(max)} USDT`], [t('pc_liq'), ps.liq ? num(ps.liq, ps.priceDec) : '—', 'gold']]} />
      {err ? <Txt v="small" tone="down">{err}</Txt> : null}
      <Btn title={t('pc_confirm')} busy={busy} disabled={v <= 0 || v > max + 1e-9} onPress={submit} />
    </Sheet>
  )
}

function TpslSheet({ visible, ps, tools, onDone }: { visible: boolean; ps: SkyPosition; tools: PosTools; onDone: () => void }) {
  const { t, num } = useI18n()
  const [tp, setTp] = useState(ps.tp ? String(ps.tp) : '')
  const [sl, setSl] = useState(ps.sl ? String(ps.sl) : '')
  const [err, setErr] = useState('')
  const [busy, setBusy] = useState(false)
  const est = (price: number) => (price - ps.entry) * ps.qty
  const sign = (v: number) => `${v >= 0 ? '+' : '−'}${num(Math.abs(v))}`
  const save = async (a: number, b: number) => {
    if (busy) return
    setBusy(true); setErr('')
    const r = await tools.setTpsl(ps.sym, a, b)
    setBusy(false)
    if (r.ok) { success(); tools.onNotice(t('pc_tpslSaved')); onDone() } else { warn(); setErr(t(`err_${r.reason ?? 'service_unavailable'}`)) }
  }
  const field = (label: string, val: string, set: (s: string) => void) => (
    <View style={{ gap: 4 }}>
      <Field label={label} value={val} onChangeText={set} placeholder={num(ps.mark, ps.priceDec)} keyboardType="decimal-pad" suffix="USDT" />
      {toNum(val) > 0 && <Txt v="tiny" num tone={est(toNum(val)) >= 0 ? 'up' : 'down'}>{t('pc_estPnl')} {sign(est(toNum(val)))}</Txt>}
    </View>
  )
  return (
    <Sheet visible={visible} title={`${t('pc_tpsl')} · ${ps.base}USDT`} onClose={onDone}>
      <Facts rows={[[t('pc_entry'), num(ps.entry, ps.priceDec)], [t('pc_mark'), num(ps.mark, ps.priceDec)]]} />
      {field(t('pc_tpPrice'), tp, setTp)}
      {field(t('pc_slPrice'), sl, setSl)}
      <Txt v="tiny" tone="muted">{t('pc_tpslHint')}</Txt>
      {err ? <Txt v="small" tone="down">{err}</Txt> : null}
      <Row>
        {(ps.tp || ps.sl) ? <Btn kind="secondary" title={t('pc_clear')} busy={busy} onPress={() => save(0, 0)} style={{ flex: 1 }} /> : null}
        <Btn title={t('pc_confirm')} busy={busy} onPress={() => save(toNum(tp), toNum(sl))} style={{ flex: 1 }} />
      </Row>
    </Sheet>
  )
}

const LEV_STOPS = [1, 20, 50, 100, 150, 200]

/** Change an open position's leverage (margin added from available or released). */
export function LeverageSheet({ visible, ps, acct, tools, onDone }: { visible: boolean; ps: SkyPosition; acct?: SkyAccount; tools: PosTools; onDone: () => void }) {
  const { t, num } = useI18n()
  const c = useColors()
  const cap = Math.max(1, ps.maxLev ?? tools.maxLev?.(ps) ?? 200)
  const [lev, setLev] = useState(ps.lev)
  const [err, setErr] = useState('')
  const [busy, setBusy] = useState(false)
  const notional = Math.abs(ps.qty) * ps.mark
  const cost = Math.abs(ps.qty) * ps.entry
  let next = ps.isolated ? cost / lev : notional / lev
  if (ps.isolated && next < ps.margin) {
    const spare = Math.max(0, Math.min(ps.margin, ps.margin + ps.upnl - notional / lev))
    next = ps.margin - Math.min(ps.margin - next, spare)
  }
  const delta = next - ps.margin
  const avail = acct?.available ?? 0
  const short = delta > 0 && delta > avail + 1e-9
  const submit = async () => {
    if (busy || lev === ps.lev) return
    setBusy(true); setErr('')
    const r = await tools.setLeverage(ps.sym, lev)
    setBusy(false)
    if (r.ok) { success(); tools.onNotice(t('pc_levSaved')); onDone() } else { warn(); setErr(t(`err_${r.reason ?? 'service_unavailable'}`)) }
  }
  return (
    <Sheet visible={visible} title={`${t('pc_levTitle')} · ${ps.base}USDT`} onClose={onDone}>
      <Txt v="hero" num center tone="gold">{lev}x</Txt>
      <Slider minimumValue={1} maximumValue={cap} step={1} value={lev} onValueChange={v => setLev(Math.round(v))}
        minimumTrackTintColor={c.gold} maximumTrackTintColor={c.line} thumbTintColor={c.gold} />
      <Row gap={6} style={{ flexWrap: 'wrap' }}>
        {LEV_STOPS.filter(l => l <= cap).map(l => <Btn key={l} small kind={lev === l ? 'primary' : 'secondary'} title={`${l}x`} onPress={() => setLev(l)} />)}
      </Row>
      {lev > 100 && <Txt v="small" tone="down">{t('highLevWarn')}</Txt>}
      <Facts rows={[
        [t('pc_curMargin'), `${num(ps.margin)} USDT`], [t('pc_newMargin'), `${num(next)} USDT`],
        [t(delta >= 0 ? 'pc_levAdd' : 'pc_levFree'), `${num(Math.abs(delta))} USDT`, delta > 0 ? 'down' : delta < 0 ? 'up' : undefined],
        [t('available'), `${num(avail)} USDT`],
      ]} />
      <Txt v="tiny" tone="muted">{t(ps.isolated ? 'pc_levHintIso' : 'pc_levHintCross')}</Txt>
      {short ? <Txt v="small" tone="down">{t('err_insufficient_margin')}</Txt> : null}
      {err ? <Txt v="small" tone="down">{err}</Txt> : null}
      <Btn title={t('pc_confirm')} busy={busy} disabled={lev === ps.lev || short} onPress={submit} />
    </Sheet>
  )
}

/** USDT futures balance card. */
export function UsdtCard({ acct }: { acct?: SkyAccount }) {
  const { t, num } = useI18n()
  const c = useColors()
  const upnl = acct?.upnl ?? 0
  const rate = acct?.usdtUsd ?? 0
  const cell = (k: string, v: number, tone?: 'up' | 'down', right?: boolean) => (
    <View style={{ flex: 1, alignItems: right ? 'flex-end' : 'flex-start', gap: 1 }}>
      <Txt v="tiny" tone="muted">{k}</Txt>
      <Txt v="small" num bold tone={tone}>{num(v)}</Txt>
      {rate > 0 && <Txt v="tiny" num tone="muted">≈ ${num(Math.abs(v) * rate)}</Txt>}
    </View>
  )
  return (
    <View style={[styles.card, { backgroundColor: c.surface, borderColor: c.line }]}>
      <Row><View style={[styles.usdt, { backgroundColor: '#26a17b' }]}><Txt bold style={{ color: '#fff' }}>₮</Txt></View><Txt bold>USDT</Txt></Row>
      <Row>{cell(t('acc_equity'), acct?.equity ?? 0)}{cell(t('acc_used'), acct?.margin ?? 0)}{cell(t('acc_avail'), acct?.available ?? 0, undefined, true)}</Row>
      <Row>{cell(t('acc_upnl'), upnl, upnl >= 0 ? 'up' : 'down')}{cell(t('acc_balance'), acct?.wallet ?? 0)}<View style={{ flex: 1 }} /></Row>
    </View>
  )
}

const styles = StyleSheet.create({
  card: { borderRadius: 16, padding: 14, gap: 12, borderWidth: StyleSheet.hairlineWidth },
  tag: { paddingHorizontal: 7, paddingVertical: 3, borderRadius: 5 },
  closer: { borderRadius: 12, padding: 10, gap: 10 },
  usdt: { width: 28, height: 28, borderRadius: 14, alignItems: 'center', justifyContent: 'center' },
})
