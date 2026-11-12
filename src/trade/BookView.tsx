import Slider from '@react-native-community/slider'
import { useState } from 'react'
import { Pressable, StyleSheet, Text, View } from 'react-native'
import { tap } from '@/lib/haptics'
import { useI18n } from '@/lib/i18n'
import { useColors } from '@/lib/theme'
import { Icon, Row, Txt } from '@/ui/kit'
import { Sheet } from '@/ui/Sheet'
import { stepDigits, type BookLevel } from './book'

/** Compact order book: asks above, last price, bids below; tap a row to use its price. */
export function MiniBook({ asks, bids, max, last, up, fp, fq, lastFmt, onPick, sub, head }: {
  asks: BookLevel[]; bids: BookLevel[]; max: number; last: number; up: boolean
  fp: (n: number) => string; fq: (n: number) => string; lastFmt: (n: number) => string; onPick: (p: number) => void
  sub?: string; head: [string, string]
}) {
  const c = useColors()
  const row = (r: BookLevel, side: 'ask' | 'bid') => (
    <Pressable key={side + r.p} onPress={() => { tap(); onPick(r.p) }} style={styles.row}>
      <View style={[styles.bar, { width: `${(r.cum / max) * 100}%`, backgroundColor: side === 'ask' ? c.downTint : c.upTint }]} />
      <Text style={[styles.cell, { color: side === 'ask' ? c.down : c.up }]}>{fp(r.p)}</Text>
      <Text style={[styles.cell, styles.r, { color: c.ink2 }]}>{fq(r.q)}</Text>
    </Pressable>
  )
  return (
    <View style={{ gap: 1 }}>
      <Row style={{ justifyContent: 'space-between', marginBottom: 4 }}>
        <Txt v="tiny" tone="muted">{head[0]}</Txt><Txt v="tiny" tone="muted">{head[1]}</Txt>
      </Row>
      {asks.map(r => row(r, 'ask'))}
      <View style={styles.last}>
        <Txt v="h2" num tone={up ? 'up' : 'down'}>{last ? lastFmt(last) : '—'}</Txt>
        {sub ? <Txt v="tiny" tone="muted" num>{sub}</Txt> : null}
      </View>
      {bids.map(r => row(r, 'bid'))}
    </View>
  )
}

export function RatioBar({ buyPct }: { buyPct: number }) {
  const c = useColors()
  return (
    <View style={styles.ratio}>
      <View style={[styles.ratioSide, { flex: Math.max(buyPct, 8), backgroundColor: c.upTint }]}>
        <Text style={[styles.ratioTxt, { color: c.up }]}>B {buyPct}%</Text>
      </View>
      <View style={[styles.ratioSide, { flex: Math.max(100 - buyPct, 8), backgroundColor: c.downTint, alignItems: 'flex-end' }]}>
        <Text style={[styles.ratioTxt, { color: c.down }]}>{100 - buyPct}% S</Text>
      </View>
    </View>
  )
}

/** Price-grouping button and its picker sheet. */
export function StepPicker({ step, steps, onChange }: { step: number; steps: number[]; onChange: (v: number) => void }) {
  const { t, num } = useI18n()
  const c = useColors()
  const [open, setOpen] = useState(false)
  const label = (v: number) => num(v, stepDigits(v))
  return (
    <>
      <Pressable onPress={() => { tap(); setOpen(true) }} style={[styles.stepBtn, { backgroundColor: c.surface2 }]}>
        <Txt v="small" num>{label(step)}</Txt><Icon name="chevron.down" size={11} color={c.muted} />
      </Pressable>
      <Sheet visible={open} title={t('bk_group')} onClose={() => setOpen(false)}>
        {steps.map(v => (
          <Pressable key={v} onPress={() => { tap(); onChange(v); setOpen(false) }} style={[styles.stepRow, { borderBottomColor: c.line }]}>
            <Txt num bold={v === step} tone={v === step ? 'gold' : 'ink'} style={{ flex: 1 }}>{label(v)}</Txt>
            {v === step && <Icon name="checkmark" size={16} color={c.gold} />}
          </Pressable>
        ))}
      </Sheet>
    </>
  )
}

/** 0–100% slider with 0 / 25 / 50 / 75 / 100 stops (snaps when within 3%). */
export function PctSlider({ value, onChange, disabled }: { value: number; onChange: (v: number) => void; disabled?: boolean }) {
  const c = useColors()
  const v = Math.max(0, Math.min(100, Math.round(value)))
  const set = (n: number) => { const s = [0, 25, 50, 75, 100].find(m => Math.abs(m - n) <= 3); onChange(s ?? n) }
  return (
    <View style={{ opacity: disabled ? 0.4 : 1 }}>
      <Row gap={6}>
        <Slider style={{ flex: 1, height: 30 }} minimumValue={0} maximumValue={100} step={1} value={v} disabled={disabled}
          minimumTrackTintColor={c.gold} maximumTrackTintColor={c.line} thumbTintColor={c.gold} onValueChange={set} />
        <Txt v="small" num style={{ width: 40, textAlign: 'right' }}>{v}%</Txt>
      </Row>
      <Row style={{ justifyContent: 'space-between', paddingRight: 46 }}>
        {[0, 25, 50, 75, 100].map(m => (
          <Pressable key={m} hitSlop={6} disabled={disabled} onPress={() => { tap(); onChange(m) }}>
            <Txt v="tiny" tone={v >= m ? 'gold' : 'muted'}>{m}%</Txt>
          </Pressable>
        ))}
      </Row>
    </View>
  )
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', justifyContent: 'space-between', height: 21, alignItems: 'center' },
  bar: { position: 'absolute', right: 0, top: 1, bottom: 1 },
  cell: { fontSize: 12, fontVariant: ['tabular-nums'] },
  r: { textAlign: 'right' },
  last: { paddingVertical: 6, gap: 1 },
  ratio: { flexDirection: 'row', height: 20, borderRadius: 4, overflow: 'hidden', marginTop: 6, gap: 2 },
  ratioSide: { justifyContent: 'center', paddingHorizontal: 5 },
  ratioTxt: { fontSize: 10, fontWeight: '700', fontVariant: ['tabular-nums'] },
  stepBtn: { flexDirection: 'row', alignItems: 'center', gap: 4, height: 26, paddingHorizontal: 8, borderRadius: 6, alignSelf: 'flex-start' },
  stepRow: { flexDirection: 'row', alignItems: 'center', height: 50, borderBottomWidth: StyleSheet.hairlineWidth },
})
