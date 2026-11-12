import { router, Stack } from 'expo-router'
import { useEffect, useState, type ReactNode } from 'react'
import { Pressable, ScrollView, StyleSheet, Switch, View } from 'react-native'
import Svg, { Circle, Line, Path, Text as SvgText } from 'react-native-svg'
import { api, errCode } from '@/lib/api'
import { useAuth } from '@/lib/auth'
import { crashPoint, seedMatches } from '@/lib/fair'
import { useFrame, useGameState } from '@/lib/games'
import { press, success, tap, warn } from '@/lib/haptics'
import { useErr, useI18n } from '@/lib/i18n'
import { useAccount } from '@/lib/sky'
import { useColors } from '@/lib/theme'
import { useWidth } from '@/ui/charts'
import { Btn, Card, Empty, Field, Row, Screen, Seg, Txt } from '@/ui/kit'

// Crash (爆点): the multiplier climbs along e^(growth·ms) until the server's
// pre-committed bust point. The server decides everything; this screen draws
// the curve from the round's start time and sends bet / cash-out.

type Phase = 'betting' | 'running' | 'crashed'
type RoundRow = { id: number; point: number; hash: string; seed: string; at: number; players: number }
type CrashState = {
  phase: Phase; round: number; hash: string; now: number; betEnd?: number; start?: number; point?: number; seed?: string; next?: number
  growth: number; players: number; wagered: number
  bets: { nick: string; amount: number; cash?: number; payout?: number }[]
  history: RoundRow[]
  me?: { amount: number; auto?: number; cash?: number; payout?: number }
  limits: { minBet: number; maxBet: number; maxProfit: number }
}
type MineRow = { round: number; amount: number; cash: number; payout: number; point: number; at: number; refund?: boolean }

const fmtX = (m: number) => `${m.toFixed(2)}x`
const STEPS = [0.25, 0.5, 1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 100000]
const T_STEPS = [2000, 5000, 10000, 15000, 30000, 60000, 120000, 300000, 600000]
const nice = (span: number, n: number, steps: number[]) => steps.find(s => span / s <= n) ?? steps[steps.length - 1]

/** Live multiplier of the round as the server sees it now. */
function multNow(s: CrashState, now: number) {
  if (s.phase === 'running' && s.start) return Math.exp(s.growth * Math.max(0, now - s.start))
  if (s.phase === 'crashed' && s.point) return s.point
  return 1
}

function Chart({ s, now }: { s: CrashState; now: () => number }) {
  const { t } = useI18n()
  const c = useColors()
  const [W, onLayout] = useWidth()
  useFrame(s.phase !== 'crashed')
  const H = 260
  const server = now()
  let el = 0, m = 1
  if (s.phase === 'running' && s.start) { el = server - s.start; m = Math.exp(s.growth * el) }
  if (s.phase === 'crashed' && s.point) { m = s.point; el = Math.log(s.point) / s.growth }
  const busted = s.phase === 'crashed'
  const xMax = Math.max(10000, el * 1.15), yMax = Math.max(2, 1 + (m - 1) * 1.25)
  const L = 44, R = 12, T = 14, B = 24
  const px = (ms: number) => L + (ms / xMax) * (W - L - R)
  const py = (v: number) => H - B - ((v - 1) / (yMax - 1)) * (H - T - B)
  const ys = nice(yMax - 1, 4, STEPS), xs = nice(xMax, 5, T_STEPS)
  const col = busted ? c.red : c.gold
  let d = ''
  if (el > 0 && W) {
    const n = 60
    d = `M${px(0)},${py(1)}`
    for (let i = 1; i <= n; i++) { const ms = (el * i) / n; d += ` L${px(ms).toFixed(1)},${py(Math.min(m, Math.exp(s.growth * ms))).toFixed(1)}` }
  }
  const left = s.phase === 'betting' && s.betEnd ? Math.max(0, s.betEnd - server) : 0
  const yTicks: number[] = []
  for (let v = 1; v <= yMax + 1e-9; v += ys) yTicks.push(v)
  const xTicks: number[] = []
  for (let ms = 0; ms <= xMax; ms += xs) xTicks.push(ms)
  return (
    <View style={[styles.chart, { backgroundColor: c.surface, borderColor: c.line }]} onLayout={onLayout}>
      {W > 0 && (
        <Svg width={W} height={H}>
          {yTicks.map(v => (
            <Line key={'y' + v} x1={L} x2={W - R} y1={py(v)} y2={py(v)} stroke={c.line} strokeWidth={1} />
          ))}
          {yTicks.map(v => (
            <SvgText key={'yl' + v} x={L - 6} y={py(v) + 4} fontSize={10} fill={c.muted} textAnchor="end">{v >= 100 ? `${Math.round(v)}x` : `${+v.toFixed(2)}x`}</SvgText>
          ))}
          {xTicks.map(ms => (
            <SvgText key={'x' + ms} x={px(ms)} y={H - 6} fontSize={10} fill={c.muted} textAnchor="middle">{`${Math.round(ms / 1000)}s`}</SvgText>
          ))}
          {d ? <Path d={`${d} L${px(el)},${py(1)} Z`} fill={col} opacity={0.16} /> : null}
          {d ? <Path d={d} stroke={col} strokeWidth={3} fill="none" strokeLinejoin="round" /> : null}
          {d ? <Circle cx={px(el)} cy={py(m)} r={busted ? 5 : 6} fill={col} /> : null}
        </Svg>
      )}
      <View style={styles.head} pointerEvents="none">
        <Txt v="small" tone="muted" bold>{s.phase === 'betting' ? t('cr_starting') : busted ? t('cr_busted') : ' '}</Txt>
        <Txt num bold style={{ fontSize: 52, color: s.phase === 'betting' ? c.ink : busted ? c.red : c.gold }}>
          {s.phase === 'betting' ? `${(left / 1000).toFixed(1)}s` : fmtX(m)}
        </Txt>
        {s.phase === 'betting' && (
          <View style={[styles.bar, { backgroundColor: c.surface2 }]}><View style={{ width: `${Math.min(1, left / 7000) * 100}%`, height: '100%', backgroundColor: c.gold }} /></View>
        )}
      </View>
    </View>
  )
}

/** Live cash-out amount on the button while riding. */
function CashLabel({ s, now, amount, label }: { s: CrashState; now: () => number; amount: number; label: string }) {
  const { num } = useI18n()
  useFrame(true)
  return <Txt bold style={{ color: '#04210f', fontSize: 17 }}>{label} {num(amount * multNow(s, now()))} USDT</Txt>
}

const tone = (p: number) => (p >= 10 ? 'hi' : p >= 2 ? 'mid' : 'lo')

export default function Crash() {
  const { t, num } = useI18n()
  const err = useErr()
  const c = useColors()
  const { me } = useAuth()
  const { account, refresh: refreshAcct } = useAccount()
  const { s, down, now, refresh } = useGameState<CrashState>('/games/crash', v => (v?.phase === 'running' ? 250 : 600))
  const [amount, setAmount] = useState('10')
  const [autoOn, setAutoOn] = useState(false)
  const [auto, setAuto] = useState('2.00')
  const [queued, setQueued] = useState(false)
  const [busy, setBusy] = useState(false)
  const [msg, setMsg] = useState('')
  const [tab, setTab] = useState<'players' | 'mine' | 'fair'>('players')
  const [mine, setMine] = useState<MineRow[]>([])
  const [checked, setChecked] = useState<Record<number, boolean>>({})

  const avail = account?.available ?? 0
  const lim = s?.limits ?? { minBet: 0.1, maxBet: 10000, maxProfit: 100000 }
  const amt = Number(amount.replace(/,/g, '.'))
  const autoX = Number(auto.replace(/,/g, '.'))
  const my = s?.me
  const riding = s?.phase === 'running' && my && !my.cash

  const act = async (path: string, body: object = {}) => {
    setBusy(true); setMsg('')
    try {
      await api(`/games/crash/${path}`, { body })
      if (path === 'cashout') success(); else press()
      await refresh(); refreshAcct()
    } catch (e) { warn(); setMsg(err(errCode(e))); await refresh() } finally { setBusy(false) }
  }
  const validBet = () => {
    if (!(amt >= lim.minBet && amt <= lim.maxBet)) { setMsg(t('cr_range').replace('{a}', num(lim.minBet)).replace('{b}', num(lim.maxBet))); return false }
    if (amt > avail) { setMsg(t('err_crash_insufficient')); return false }
    if (autoOn && !(autoX >= 1.01)) { setMsg(t('err_crash_invalid_auto')); return false }
    return true
  }
  const placeBet = () => act('bet', { amount: String(Math.floor(amt * 1e4) / 1e4), auto: autoOn ? autoX.toFixed(2) : '' })

  useEffect(() => {
    if (queued && s?.phase === 'betting' && !s.me) { setQueued(false); placeBet() }
  }, [s?.phase, s?.round]) // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (s?.phase === 'crashed' && s.me && !s.me.cash) warn()
  }, [s?.phase]) // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (tab !== 'mine' || !me) return
    api<MineRow[]>('/games/crash/me').then(setMine).catch(() => undefined)
  }, [tab, me, s?.history[0]?.id])

  const pressMain = () => {
    if (!me) { router.push('/login'); return }
    if (!s) return
    if (s.phase === 'betting' && my) { act('cancel'); return }
    if (s.phase === 'betting') { if (validBet()) placeBet(); return }
    if (riding) { act('cashout'); return }
    if (queued) { setQueued(false); tap(); return }
    if (validBet()) { setQueued(true); tap() }
  }
  let label: ReactNode = t('cr_next'), kind: 'primary' | 'secondary' | 'up' = 'primary'
  if (!me) label = t('cr_login')
  else if (!s) label = '…'
  else if (s.phase === 'betting' && my) { label = t('cr_cancel'); kind = 'secondary' }
  else if (s.phase === 'betting') label = t('cr_bet')
  else if (riding && my) { label = <CashLabel s={s} now={now} amount={my.amount} label={t('cr_cashout')} />; kind = 'up' }
  else if (queued) { label = t('cr_queued'); kind = 'secondary' }
  const locked = !!my && s?.phase !== 'crashed'
  const chipColor = (p: number) => ({ hi: [c.gold, 'rgba(212,175,95,.18)'], mid: [c.up, c.upTint], lo: [c.muted, c.surface2] }[tone(p)])

  return (
    <>
      <Stack.Screen options={{ title: t('gm_crash') }} />
      <Screen>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 6 }}>
          {(s?.history ?? []).slice(0, 20).map(r => {
            const [fg, bg] = chipColor(r.point)
            return <View key={r.id} style={[styles.chip, { backgroundColor: bg }]}><Txt v="tiny" bold num style={{ color: fg }}>{fmtX(r.point)}</Txt></View>
          })}
        </ScrollView>
        {s ? <Chart s={s} now={now} /> : <Card><Empty text={down ? t('cr_down') : t('connecting')} /></Card>}

        <Card>
          <Row style={{ justifyContent: 'space-between' }}><Txt v="small" tone="muted">{t('cr_balance')}</Txt><Txt v="small" num bold>{me ? `${num(avail)} USDT` : '—'}</Txt></Row>
          <Field label={t('cr_amount')} value={amount} editable={!locked} onChangeText={setAmount} keyboardType="decimal-pad" suffix="USDT" />
          <Row gap={8}>
            {[
              { l: '½', f: () => setAmount(String(Math.max(lim.minBet, +(amt / 2).toFixed(2)))) },
              { l: '2×', f: () => setAmount(String(Math.min(lim.maxBet, +(amt * 2).toFixed(2) || lim.minBet))) },
              { l: 'Min', f: () => setAmount(String(lim.minBet)) },
              { l: 'Max', f: () => setAmount(String(Math.max(lim.minBet, Math.min(lim.maxBet, Math.floor(avail * 100) / 100)))) },
            ].map(x => <Btn key={x.l} small kind="secondary" title={x.l} disabled={locked} onPress={x.f} style={{ flex: 1 }} />)}
          </Row>
          <Row>
            <Switch value={autoOn} disabled={locked} onValueChange={setAutoOn} trackColor={{ true: c.gold }} />
            <Field label={t('cr_auto')} value={auto} editable={!locked && autoOn} onChangeText={setAuto} keyboardType="decimal-pad" suffix="x" style={{ flex: 1 }} />
          </Row>
          {autoOn && autoX >= 1.01 && amt > 0 && <Txt v="tiny" tone="muted">{t('cr_autoHint').replace('{x}', fmtX(autoX)).replace('{p}', num(amt * autoX))}</Txt>}
          <Btn kind={kind} title={label} busy={busy} disabled={!!me && !s} onPress={pressMain} style={{ height: 56 }} />
          {my?.cash ? <Txt tone="up" center bold>{t('cr_cashed')} {fmtX(my.cash)} · +{num((my.payout ?? 0) - my.amount)} USDT</Txt> : null}
          {s?.phase === 'crashed' && my && !my.cash ? <Txt tone="down" center bold>{t('cr_lost')} −{num(my.amount)} USDT</Txt> : null}
          {msg ? <Txt v="small" tone="down" center>{msg}</Txt> : null}
        </Card>

        <Seg items={[{ id: 'players', label: t('cr_players') }, { id: 'mine', label: t('cr_mine') }, { id: 'fair', label: t('cr_fair') }]} value={tab} onChange={setTab} />

        {tab === 'players' && s && (
          <View style={{ gap: 2 }}>
            <Row style={{ justifyContent: 'space-between' }}>
              <Txt v="small" tone="muted">{s.players} {t('cr_people')}</Txt>
              <Txt v="small" tone="muted">{t('cr_total')} <Txt v="small" num bold>{num(s.wagered)} USDT</Txt></Txt>
            </Row>
            {s.bets.length === 0 && <Empty text={t('cr_noBets')} />}
            {s.bets.map((b, i) => (
              <Row key={i} style={[styles.row, { borderBottomColor: c.line }]}>
                <Txt v="small" lines={1} style={{ flex: 1 }}>{b.nick}</Txt>
                <Txt v="small" num style={{ width: 80, textAlign: 'right' }}>{num(b.amount)}</Txt>
                <Txt v="small" num style={{ flex: 1, textAlign: 'right' }} tone={b.cash ? 'up' : s.phase === 'crashed' ? 'down' : 'muted'}>
                  {b.cash ? `${fmtX(b.cash)} · +${num((b.payout ?? 0) - b.amount)}` : s.phase === 'crashed' ? `−${num(b.amount)}` : '—'}
                </Txt>
              </Row>
            ))}
          </View>
        )}

        {tab === 'mine' && (
          !me ? <Empty text={t('cr_login')} />
            : mine.length === 0 ? <Empty text={t('cr_noBets')} />
            : mine.map(r => (
              <Row key={`${r.round}-${r.at}`} style={[styles.row, { borderBottomColor: c.line }]}>
                <Txt v="small" tone="muted" style={{ flex: 1 }}>#{r.round} · {r.refund ? t('cr_refund') : fmtX(r.point)}</Txt>
                <Txt v="small" num style={{ width: 80, textAlign: 'right' }}>{num(r.amount)}</Txt>
                <Txt v="small" num style={{ flex: 1, textAlign: 'right' }} tone={r.refund ? 'muted' : r.cash ? 'up' : 'down'}>
                  {r.refund ? '±0' : r.cash ? `${fmtX(r.cash)} · +${num(r.payout - r.amount)}` : `−${num(r.amount)}`}
                </Txt>
              </Row>
            ))
        )}

        {tab === 'fair' && s && (
          <View style={{ gap: 10 }}>
            <Txt v="small">{t('cr_rules')}</Txt>
            <Txt v="small" tone="muted">{t('cr_fairHow')}</Txt>
            <Card><Txt v="tiny" tone="muted">{t('cr_hash')} #{s.round}</Txt><Txt v="tiny" selectable>{s.hash}</Txt></Card>
            {s.history.map(r => (
              <Card key={r.id}>
                <Row style={{ justifyContent: 'space-between' }}>
                  <Txt v="small" bold>{fmtX(r.point)} · #{r.id}</Txt>
                  <Pressable hitSlop={8} onPress={() => { tap(); setChecked(x => ({ ...x, [r.id]: seedMatches(r.seed, r.hash) && crashPoint(r.seed, r.id) === Math.round(r.point * 100) })) }}>
                    <Txt v="small" tone={checked[r.id] === undefined ? 'gold' : checked[r.id] ? 'up' : 'down'}>
                      {checked[r.id] === undefined ? t('cr_verify') : checked[r.id] ? `✓ ${t('cr_verified')}` : `✗ ${t('cr_mismatch')}`}
                    </Txt>
                  </Pressable>
                </Row>
                <Txt v="tiny" tone="muted" selectable>{t('cr_seed')} {r.seed}</Txt>
              </Card>
            ))}
          </View>
        )}
        <Txt v="tiny" tone="muted" center>{t('gm_note')}</Txt>
      </Screen>
    </>
  )
}

const styles = StyleSheet.create({
  chart: { height: 260, borderRadius: 16, borderWidth: StyleSheet.hairlineWidth, overflow: 'hidden' },
  head: { position: 'absolute', top: '16%', left: 0, right: 0, alignItems: 'center' },
  bar: { width: 140, height: 4, borderRadius: 2, overflow: 'hidden', marginTop: 8 },
  chip: { paddingHorizontal: 8, paddingVertical: 3, borderRadius: 8 },
  row: { paddingVertical: 10, borderBottomWidth: StyleSheet.hairlineWidth },
})
