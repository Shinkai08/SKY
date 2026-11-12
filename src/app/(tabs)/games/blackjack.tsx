import { router, Stack } from 'expo-router'
import { useEffect, useState } from 'react'
import { Pressable, StyleSheet, Text, View } from 'react-native'
import { api, errCode } from '@/lib/api'
import { useAuth } from '@/lib/auth'
import { bjShuffle, seedMatches } from '@/lib/fair'
import { useGameState } from '@/lib/games'
import { press, success, tap, warn } from '@/lib/haptics'
import { useErr, useI18n } from '@/lib/i18n'
import { useAccount } from '@/lib/sky'
import { loadJSON, saveJSON } from '@/lib/storage'
import { useColors } from '@/lib/theme'
import { Avatar } from '@/ui/Avatar'
import { Btn, Card, Empty, Field, Row, Screen, Seg, Txt } from '@/ui/kit'

// Blackjack (21点): one shared table, 7 seats, the house deals. The server
// runs the table; this screen shows it and sends sit / bet / actions.

type Phase = 'waiting' | 'betting' | 'insurance' | 'playing' | 'dealer' | 'settled'
type Hand = { cards: number[] | null; total: number; soft?: boolean; bet: number; double?: boolean; done?: boolean; result?: string; payout?: number }
type Seat = { seat: number; nick: string; me?: boolean; hands: Hand[]; ins?: number; insSet?: boolean; leaving?: boolean }
type RoundRow = { id: number; hash: string; seed: string; drawn: number[]; dealer: number[]; total: number; at: number; players: number }
type Table = {
  phase: Phase; round: number; hash?: string; seed?: string; now: number; deadline?: number; turn: number; hand: number
  dealer: number[]; dealerTotal: number; seats: (Seat | null)[]; mySeat: number; actions: string[]; players: number
  history: RoundRow[]; limits: { minBet: number; maxBet: number }
}
type Rec = { round: number; staked: number; paid: number; ins?: number; dealer?: number[]; hands?: { cards: number[]; bet: number; result: string; payout: number }[]; at: number; refund?: boolean }

const MU = 1e8
const RANKS = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K']
const SUITS = ['♠', '♥', '♦', '♣']
const CHIPS = [1, 5, 10, 50, 100, 500]
const CHIP_COLORS: Record<number, string> = { 1: '#8a8f99', 5: '#c8283c', 10: '#2a6fd6', 50: '#1f9d5c', 100: '#23252b', 500: '#7b3fd0' }

function Card52({ c, size = 'm' }: { c: number; size?: 's' | 'm' | 'l' }) {
  const dim = { s: [22, 31, 10], m: [34, 48, 14], l: [46, 64, 19] }[size]
  if (c < 0) return <View style={[styles.card, { width: dim[0], height: dim[1], backgroundColor: '#a32c3f', borderWidth: 2, borderColor: '#fbfaf6' }]} />
  const suit = Math.floor(c / 13) % 4
  const red = suit === 1 || suit === 2
  return (
    <View style={[styles.card, { width: dim[0], height: dim[1] }]}>
      <Text style={{ fontSize: dim[2], fontWeight: '700', color: red ? '#c8283c' : '#17181c', fontFamily: 'Georgia' }}>{RANKS[c % 13]}</Text>
      <Text style={{ fontSize: dim[2], alignSelf: 'flex-end', color: red ? '#c8283c' : '#17181c' }}>{SUITS[suit]}</Text>
    </View>
  )
}

function Cards({ cards, size, overlap }: { cards: number[]; size?: 's' | 'm' | 'l'; overlap: number }) {
  return <View style={{ flexDirection: 'row' }}>{cards.map((c, i) => <View key={i} style={{ marginLeft: i ? -overlap : 0 }}><Card52 c={c} size={size} /></View>)}</View>
}

// Seats on an arc, seat 1 on the players' right (the dealer's left).
const seatPos = (i: number) => {
  const t = Math.PI * (0.12 + (0.76 * i) / 6)
  return { left: `${50 + 42 * Math.cos(t)}%` as const, top: `${24 + 58 * Math.sin(t)}%` as const }
}

export default function Blackjack() {
  const { t, num } = useI18n()
  const err = useErr()
  const c = useColors()
  const { me } = useAuth()
  const { account, refresh: refreshAcct } = useAccount()
  const { s, down, now, refresh } = useGameState<Table>('/games/blackjack', () => 450)
  const [amount, setAmount] = useState('10')
  const [busy, setBusy] = useState(false)
  const [msg, setMsg] = useState('')
  const [tab, setTab] = useState<'rules' | 'mine' | 'fair'>('rules')
  const [mine, setMine] = useState<Rec[]>([])
  const [checked, setChecked] = useState<Record<number, boolean>>({})
  const [, setTick] = useState(0)
  useEffect(() => { loadJSON<string | number>('sky.bjBet', '10').then(v => setAmount(String(v))) }, [])
  useEffect(() => { const id = setInterval(() => setTick(x => x + 1), 250); return () => clearInterval(id) }, [])

  const avail = account?.available ?? 0
  const lim = s?.limits ?? { minBet: 1, maxBet: 5000 }
  const amt = Number(amount.replace(/,/g, '.')) || 0
  const my = s && s.mySeat >= 0 ? s.seats[s.mySeat] : null
  const myTurn = !!s && s.phase === 'playing' && s.turn === s.mySeat && s.mySeat >= 0
  const left = s?.deadline && s.phase !== 'waiting' ? Math.max(0, (s.deadline - now()) / 1000) : 0

  useEffect(() => { if (myTurn) press() }, [myTurn])
  useEffect(() => {
    if (tab !== 'mine' || !me) return
    api<Rec[]>('/games/blackjack/me').then(setMine).catch(() => undefined)
  }, [tab, me, s?.history[0]?.id])

  const call = async (path: string, body: object = {}) => {
    setBusy(true); setMsg('')
    try { await api(`/games/blackjack/${path}`, { body }); tap(); await refresh(); refreshAcct() }
    catch (e) { warn(); setMsg(err(errCode(e))); await refresh() } finally { setBusy(false) }
  }
  const sit = (seat: number) => { if (!me) { router.push('/login'); return } if (!my) call('sit', { seat }) }
  const placeBet = () => {
    if (!(amt >= lim.minBet && amt <= lim.maxBet)) { setMsg(t('cr_range').replace('{a}', num(lim.minBet)).replace('{b}', num(lim.maxBet))); return }
    if (amt > avail) { setMsg(t('err_crash_insufficient')); return }
    saveJSON('sky.bjBet', String(amt))
    call('bet', { amount: String(Math.floor(amt * 100) / 100) })
  }
  useEffect(() => {
    if (s?.phase !== 'settled' || !my?.hands.length) return
    const net = my.hands.reduce((a, h) => a + (h.payout ?? 0) - h.bet, 0)
    if (net > 0) success(); else if (net < 0) warn()
  }, [s?.phase]) // eslint-disable-line react-hooks/exhaustive-deps

  const phaseText = () => {
    if (!s) return down ? t('cr_down') : t('connecting')
    switch (s.phase) {
      case 'waiting': return t('bj_waiting')
      case 'betting': return `${t('bj_betting')} ${left.toFixed(0)}s`
      case 'insurance': return `${t('bj_insurance')} ${left.toFixed(0)}s`
      case 'playing': {
        const who = s.seats[s.turn]
        return who?.me ? `${t('bj_yourTurn')} ${left.toFixed(0)}s` : `${t('bj_turnOf').replace('{n}', who?.nick ?? '')} ${left.toFixed(0)}s`
      }
      case 'dealer': return t('bj_dealerPlays')
      case 'settled': return t('bj_settled')
    }
  }
  const res = (r?: string) => (r ? t(`bj_r_${r}`) : '')
  const resTone = (r?: string) => (r === 'win' || r === 'blackjack' ? 'up' : r === 'lose' || r === 'bust' ? 'down' : 'muted')
  const dealerBJ = s?.dealer.length === 2 && s.dealerTotal === 21
  const myNet = my && s?.phase === 'settled' ? my.hands.reduce((a, h) => a + (h.payout ?? 0) - h.bet, 0) + (my.ins ? (dealerBJ ? my.ins * 2 : -my.ins) : 0) : 0

  const verify = (r: RoundRow) => {
    tap()
    const shoe = bjShuffle(r.seed, r.id)
    setChecked(x => ({ ...x, [r.id]: seedMatches(r.seed, r.hash) && r.drawn.every((card, i) => shoe[i] === card) }))
  }

  return (
    <>
      <Stack.Screen options={{ title: t('gm_blackjack') }} />
      <Screen>
        <View style={styles.felt}>
          <View style={styles.dealer}>
            <Cards cards={s?.dealer ?? []} overlap={14} />
            {s && s.dealer.length > 0 && <View style={styles.total}><Text style={styles.totalTxt}>{s.dealerTotal}</Text></View>}
            <Text style={styles.dealerLbl}>{t('bj_dealer')}</Text>
          </View>
          <View style={styles.print} pointerEvents="none">
            <Text style={styles.pays}>{t('bj_pays')}</Text>
            <Text style={styles.printSub}>{t('bj_print')}</Text>
          </View>
          {[0, 1, 2, 3, 4, 5, 6].map(i => {
            const st = s?.seats[i]
            const active = s?.phase === 'playing' && s.turn === i
            return (
              <View key={i} style={[styles.seat, seatPos(i)]}>
                {st && st.hands.length > 0 && (
                  <View style={styles.hands}>
                    {st.hands.map((h, j) => (
                      <View key={j} style={[styles.mini, active && s?.hand === j && { borderColor: c.gold }]}>
                        <Cards cards={h.cards ?? []} size="s" overlap={11} />
                        {(h.cards ?? []).length > 0 && (
                          <View style={[styles.total, styles.totalS, h.result && { backgroundColor: resTone(h.result) === 'up' ? '#1f9d5c' : resTone(h.result) === 'down' ? '#b3263a' : 'rgba(0,0,0,.55)' }]}>
                            <Text style={[styles.totalTxt, { fontSize: 10 }]}>{h.total}</Text>
                          </View>
                        )}
                      </View>
                    ))}
                  </View>
                )}
                <Pressable disabled={!!st || !!my || busy} onPress={() => { tap(); sit(i) }}
                  style={[styles.chair, st ? styles.chairTaken : null, st?.me && { borderColor: c.gold }, active && { borderColor: c.goldHi, borderWidth: 3 }]}>
                  {st ? <Avatar a={{ nick: st.nick }} size={36} /> : <Text style={styles.chairNum}>{i + 1}</Text>}
                </Pressable>
                {st && st.hands[0] ? <View style={styles.betTag}><Text style={styles.betTxt}>{num(st.hands.reduce((a, h) => a + h.bet, 0))}</Text></View>
                  : !st && !my ? <Text style={styles.sitLbl}>{t('bj_sit')}</Text> : st ? <Text style={styles.sitLbl} numberOfLines={1}>{st.nick.slice(-6)}</Text> : null}
              </View>
            )
          })}
        </View>

        <Card style={[{ flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 12 }, myTurn && { borderColor: c.gold }]}>
          <Txt bold tone={myTurn ? 'gold' : 'ink'}>{phaseText()}</Txt>
          {s && s.phase !== 'waiting' ? <Txt v="small" tone="muted">#{s.round} · {s.players}/7</Txt> : null}
        </Card>

        <Card>
          <Row style={{ justifyContent: 'space-between' }}><Txt v="small" tone="muted">{t('cr_balance')}</Txt><Txt v="small" num bold>{me ? `${num(avail)} USDT` : '—'}</Txt></Row>
          {my && my.hands.length > 0 && my.hands.map((h, j) => (
            <View key={j} style={[styles.myHand, { backgroundColor: c.surface2 }, myTurn && s?.hand === j && { borderColor: c.gold }]}>
              <Cards cards={h.cards ?? []} size="l" overlap={16} />
              <View style={{ gap: 2 }}>
                <Txt v="title" num>{h.cards?.length ? `${h.soft && h.total < 21 ? `${h.total - 10}/` : ''}${h.total}` : '—'}</Txt>
                <Txt v="tiny" tone="muted" num>{num(h.bet)} USDT{h.double ? ' ×2' : ''}</Txt>
                {h.result ? <Txt v="small" bold tone={resTone(h.result)}>{res(h.result)}{h.payout ? ` +${num(h.payout)}` : ''}</Txt> : null}
              </View>
            </View>
          ))}
          {s?.phase === 'settled' && my && my.hands.length > 0 && (
            <Txt v="h2" center num tone={myNet > 0 ? 'up' : myNet < 0 ? 'down' : 'muted'}>{myNet > 0 ? '+' : myNet < 0 ? '−' : '±'}{num(Math.abs(myNet))} USDT</Txt>
          )}
          {!me && <Btn title={t('bj_login')} onPress={() => router.push('/login')} />}
          {me && !my && <Txt v="small" tone="muted" center>{t('bj_pickSeat')}</Txt>}
          {my && s?.actions.includes('bet') && (
            <>
              <Field label={t('cr_amount')} value={amount} onChangeText={setAmount} keyboardType="decimal-pad" suffix="USDT" />
              <Row gap={8} style={{ flexWrap: 'wrap', justifyContent: 'center' }}>
                {CHIPS.map(v => (
                  <Pressable key={v} onPress={() => { tap(); setAmount(String(Math.min(lim.maxBet, +(amt + v).toFixed(2)))) }}
                    style={[styles.chip, { backgroundColor: CHIP_COLORS[v] }]}><Text style={styles.chipTxt}>{v}</Text></Pressable>
                ))}
                <Btn small kind="ghost" title={t('bj_clear')} onPress={() => setAmount('0')} />
              </Row>
              <Btn title={`${t('cr_bet')} ${amt > 0 ? `${num(amt)} USDT` : ''}`} busy={busy} onPress={placeBet} />
            </>
          )}
          {my && s?.phase === 'betting' && !s.actions.includes('bet') && <Txt v="small" tone="muted" center>{t('bj_betPlaced')}</Txt>}
          {my && s?.actions.includes('insurance') && (
            <>
              <Txt center>{t('bj_insAsk').replace('{x}', num((my.hands[0]?.bet ?? 0) / 2))}</Txt>
              <Row>
                <Btn title={t('bj_insYes')} busy={busy} onPress={() => call('insurance', { take: true })} style={{ flex: 1 }} />
                <Btn kind="secondary" title={t('bj_insNo')} busy={busy} onPress={() => call('insurance', { take: false })} style={{ flex: 1 }} />
              </Row>
            </>
          )}
          {myTurn && (
            <Row gap={8}>
              {(['hit', 'stand', 'double', 'split'] as const).map(a => (
                <Btn key={a} kind={a === 'hit' ? 'primary' : a === 'stand' ? 'secondary' : a === 'double' ? 'up' : 'down'} title={t(`bj_${a}`)}
                  disabled={busy || !s?.actions.includes(a)} onPress={() => call('action', { action: a })} style={{ flex: 1, paddingHorizontal: 4 }} />
              ))}
            </Row>
          )}
          {msg ? <Txt v="small" tone="down" center>{msg}</Txt> : null}
          {my && <Btn small kind="ghost" title={my.leaving ? t('bj_leaving') : t('bj_leave')} disabled={busy} onPress={() => call('leave')} />}
        </Card>

        <Seg items={[{ id: 'rules', label: t('bj_rulesTab') }, { id: 'mine', label: t('cr_mine') }, { id: 'fair', label: t('cr_fair') }]} value={tab} onChange={setTab} />
        {tab === 'rules' && <Txt v="small" tone="ink2">{t('bj_rules')}</Txt>}
        {tab === 'mine' && (
          !me ? <Empty text={t('bj_login')} />
            : mine.length === 0 ? <Empty text={t('cr_noBets')} />
            : mine.map(r => {
              const net = (r.paid - r.staked) / MU
              return (
                <Card key={`${r.round}-${r.at}`}>
                  <Row style={{ justifyContent: 'space-between' }}>
                    <Txt v="small" tone="muted">#{r.round}{r.refund ? ` · ${t('cr_refund')}` : ''}</Txt>
                    <Txt num bold tone={r.refund ? 'muted' : net > 0 ? 'up' : net < 0 ? 'down' : 'muted'}>{r.refund ? '±0' : `${net > 0 ? '+' : net < 0 ? '−' : '±'}${num(Math.abs(net))}`}</Txt>
                  </Row>
                  {(r.hands ?? []).map((h, i) => (
                    <Txt key={i} v="small">{h.cards.map(x => RANKS[x % 13]).join(' ')} · <Txt v="small" bold tone={resTone(h.result)}>{res(h.result)}</Txt></Txt>
                  ))}
                  {r.dealer ? <Txt v="tiny" tone="muted">{t('bj_dealer')} {r.dealer.map(x => RANKS[x % 13]).join(' ')}</Txt> : null}
                </Card>
              )
            })
        )}
        {tab === 'fair' && s && (
          <View style={{ gap: 10 }}>
            <Txt v="small" tone="muted">{t('bj_fairHow')}</Txt>
            {s.hash ? <Card><Txt v="tiny" tone="muted">{t('cr_hash')} #{s.round}</Txt><Txt v="tiny" selectable>{s.hash}</Txt></Card> : null}
            {s.history.map(r => (
              <Card key={r.id}>
                <Row style={{ justifyContent: 'space-between' }}>
                  <Txt v="small" bold>#{r.id} · {t('bj_dealer')} {r.total} · {r.drawn.length} {t('bj_cardsDrawn')}</Txt>
                  <Pressable hitSlop={8} onPress={() => verify(r)}>
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
  felt: {
    height: 400, borderTopLeftRadius: 24, borderTopRightRadius: 24, borderBottomLeftRadius: 200, borderBottomRightRadius: 200,
    backgroundColor: '#0e4a31', borderWidth: 2, borderColor: 'rgba(212,175,95,.55)', overflow: 'hidden',
  },
  dealer: { position: 'absolute', top: 12, left: 0, right: 0, alignItems: 'center', gap: 4 },
  dealerLbl: { color: 'rgba(255,255,255,.6)', fontSize: 11, letterSpacing: 1 },
  print: { position: 'absolute', top: '30%', left: 30, right: 30, alignItems: 'center', gap: 3 },
  pays: { color: 'rgba(232,200,120,.85)', fontSize: 13, letterSpacing: 2, fontWeight: '700' },
  printSub: { color: 'rgba(255,255,255,.45)', fontSize: 10, textAlign: 'center' },
  card: { borderRadius: 5, backgroundColor: '#fbfaf6', padding: 3, justifyContent: 'space-between', shadowColor: '#000', shadowOpacity: 0.35, shadowRadius: 3, shadowOffset: { width: 0, height: 2 } },
  total: { minWidth: 22, paddingHorizontal: 6, paddingVertical: 1, borderRadius: 9, backgroundColor: 'rgba(0,0,0,.55)', alignItems: 'center' },
  totalS: { minWidth: 16, paddingHorizontal: 4 },
  totalTxt: { color: '#fff', fontSize: 12, fontWeight: '700', fontVariant: ['tabular-nums'] },
  seat: { position: 'absolute', width: 64, marginLeft: -32, marginTop: -26, alignItems: 'center', gap: 3 },
  hands: { position: 'absolute', bottom: 44, alignItems: 'center', gap: 2 },
  mini: { flexDirection: 'row', alignItems: 'center', gap: 2, padding: 1, borderRadius: 5, borderWidth: 2, borderColor: 'transparent' },
  chair: { width: 44, height: 44, borderRadius: 22, borderWidth: 2, borderStyle: 'dashed', borderColor: 'rgba(255,255,255,.35)', backgroundColor: 'rgba(0,0,0,.25)', alignItems: 'center', justifyContent: 'center' },
  chairTaken: { borderStyle: 'solid', borderColor: 'rgba(255,255,255,.55)' },
  chairNum: { color: 'rgba(255,255,255,.75)', fontWeight: '700' },
  betTag: { paddingHorizontal: 6, borderRadius: 8, backgroundColor: 'rgba(232,200,120,.92)' },
  betTxt: { color: '#2a1f05', fontSize: 10, fontWeight: '800' },
  sitLbl: { color: 'rgba(255,255,255,.55)', fontSize: 10 },
  myHand: { flexDirection: 'row', alignItems: 'center', gap: 12, padding: 8, borderRadius: 12, borderWidth: 2, borderColor: 'transparent' },
  chip: { width: 44, height: 44, borderRadius: 22, borderWidth: 3, borderStyle: 'dashed', borderColor: 'rgba(255,255,255,.7)', alignItems: 'center', justifyContent: 'center' },
  chipTxt: { color: '#fff', fontSize: 12, fontWeight: '800' },
})
