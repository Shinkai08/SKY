import { router, Stack } from 'expo-router'
import { useEffect, useState } from 'react'
import { Pressable, StyleSheet, View } from 'react-native'
import { api } from '@/lib/api'
import { useAuth } from '@/lib/auth'
import { useDepositMeta, type Deposit } from '@/lib/deposit'
import { tap } from '@/lib/haptics'
import { useI18n } from '@/lib/i18n'
import { openTrade } from '@/lib/nav'
import { useAccount, usePoll } from '@/lib/sky'
import { persisted } from '@/lib/storage'
import { useColors } from '@/lib/theme'
import { Btn, Card, Empty, Icon, Row, Screen, Txt } from '@/ui/kit'
import { MarketIcon } from '@/ui/MarketIcon'
import { Sheet } from '@/ui/Sheet'
import { MeButton } from '@/ui/TabStack'

const hidden = persisted('sky.hideBalance', false)

/** Wallet: total value, today's P&L, four actions and the balance list. */
export default function Assets() {
  const { t, num } = useI18n()
  const c = useColors()
  const { me } = useAuth()
  const { account: a, refresh } = useAccount()
  const hide = hidden.useValue()
  const [today, setToday] = useState<{ pnl: number; ret: number }>()
  const [sheet, setSheet] = useState<'' | 'withdraw' | 'transfer' | 'history'>('')
  const [refreshing, setRefreshing] = useState(false)
  usePoll(() => {
    if (me) api<{ rangePnl: number; rangeRet: number }>(`/users/${me.id}/perf?days=1`).then(p => setToday({ pnl: p.rangePnl, ret: p.rangeRet })).catch(() => undefined)
  }, 15_000, [me?.id])

  if (!me) {
    return (
      <Screen>
        <Empty text={t('loginToTrade')} icon="lock" />
        <Btn title={t('login')} onPress={() => router.push('/login')} />
      </Screen>
    )
  }
  const v = (n: number, d = 2) => (hide ? '******' : num(n, d))
  const pnl = today?.pnl ?? 0, ret = today?.ret ?? 0
  const sign = (n: number) => (n >= 0 ? '+' : '−')
  const actions = [
    { icon: 'arrow.down.to.line' as const, label: t('deposit'), go: () => router.push('/deposit') },
    { icon: 'arrow.up.to.line' as const, label: t('withdraw'), go: () => setSheet('withdraw') },
    { icon: 'arrow.left.arrow.right' as const, label: t('transfer'), go: () => setSheet('transfer') },
    { icon: 'chart.xyaxis.line' as const, label: t('trade'), go: () => openTrade('BTCUSDT', false) },
  ]

  return (
    <>
      <Stack.Screen options={{
        headerRight: () => (
          <Row gap={18}>
            <Pressable hitSlop={8} onPress={() => { tap(); setSheet('history') }}><Icon name="clock.arrow.circlepath" size={22} color={c.gold} /></Pressable>
            <MeButton />
          </Row>
        ),
      }} />
      <Screen refreshing={refreshing} onRefresh={() => { setRefreshing(true); refresh().finally(() => setRefreshing(false)) }}>
        <View style={{ gap: 6 }}>
          <Pressable onPress={() => { tap(); hidden.set(h => !h) }}>
            <Row gap={6}><Txt v="small" tone="muted">{t('totalValue')}</Txt><Icon name={hide ? 'eye.slash' : 'eye'} size={14} color={c.muted} /></Row>
          </Pressable>
          <Txt v="hero" num>{v(a?.total ?? 0)} <Txt v="small" tone="muted">USDT</Txt></Txt>
          {a?.usdtUsd ? <Txt v="small" tone="muted" num>≈ ${v((a.total ?? 0) * a.usdtUsd)}</Txt> : null}
          <Row gap={6}>
            <Txt v="small" tone="muted">{t('todayPnl')}</Txt>
            <Txt v="small" num tone={pnl >= 0 ? 'up' : 'down'}>{hide ? '******' : `${sign(pnl)}${num(Math.abs(pnl))} USDT (${sign(ret)}${num(Math.abs(ret))}%)`}</Txt>
          </Row>
        </View>

        <Row style={{ justifyContent: 'space-between' }}>
          {actions.map(x => (
            <Pressable key={x.label} onPress={() => { tap(); x.go() }} style={styles.action}>
              <View style={[styles.actionIcon, { backgroundColor: c.surface2 }]}><Icon name={x.icon} size={20} color={c.gold} /></View>
              <Txt v="small">{x.label}</Txt>
            </Pressable>
          ))}
        </Row>

        <Card style={{ paddingHorizontal: 0, paddingVertical: 6, gap: 0 }}>
          <Txt v="small" tone="muted" style={{ paddingHorizontal: 16, paddingVertical: 8 }}>{t('balance')}</Txt>
          <Pressable onPress={() => openTrade('BTCUSDT', false)} style={styles.bal}>
            <View style={[styles.usdt, { backgroundColor: '#26a17b' }]}><Txt bold style={{ color: '#fff' }}>₮</Txt></View>
            <View style={{ flex: 1 }}><Txt bold>USDT</Txt><Txt v="tiny" tone="muted">TetherUS</Txt></View>
            <View style={{ alignItems: 'flex-end' }}>
              <Txt num bold>{v(a?.equity ?? 0, 4)}</Txt>
              <Txt v="tiny" tone="muted" num>≈ {v(a?.equity ?? 0)} USDT</Txt>
            </View>
          </Pressable>
          {a?.balances.map(b => (
            <Pressable key={b.sym} onPress={() => openTrade(b.sym, true)} style={styles.bal}>
              <MarketIcon it={{ base: b.base, cat: b.cat }} size={36} />
              <View style={{ flex: 1 }}><Txt bold>{b.base}</Txt><Txt v="tiny" tone="muted">{b.sym === 'SKY-STOCKUSDT' ? 'SKY' : t(b.cat === 'crypto' ? 'crypto' : b.cat)}</Txt></View>
              <View style={{ alignItems: 'flex-end' }}>
                <Txt num bold>{hide ? '******' : num(b.free + b.locked, Math.max(0, b.qtyDec))}</Txt>
                <Txt v="tiny" tone="muted" num>≈ {v(b.value)} USDT</Txt>
              </View>
            </Pressable>
          ))}
        </Card>
      </Screen>

      <Sheet visible={sheet === 'withdraw'} title={t('withdraw')} onClose={() => setSheet('')}><Txt tone="ink2">{t('demoNote')}</Txt></Sheet>
      <Sheet visible={sheet === 'transfer'} title={t('transfer')} onClose={() => setSheet('')}><Txt tone="ink2">{t('transferNote')}</Txt></Sheet>
      <Sheet visible={sheet === 'history'} title={t('depositRecords')} onClose={() => setSheet('')}>{sheet === 'history' && <DepositHistory />}</Sheet>
    </>
  )
}

function DepositHistory() {
  const { t, num } = useI18n()
  const meta = useDepositMeta()
  const [deps, setDeps] = useState<Deposit[]>()
  useEffect(() => {
    const load = () => api<Deposit[]>('/deposits').then(setDeps).catch(() => undefined)
    load()
    const id = setInterval(load, 3000)
    return () => clearInterval(id)
  }, [])
  if (!deps) return null
  if (!deps.length) return <Empty text={t('noData')} />
  return (
    <>
      {deps.map(d => (
        <Card key={d.id}>
          <Row style={{ justifyContent: 'space-between' }}>
            <Txt bold num>{d.amount} {d.asset}</Txt>
            <Txt v="small" tone={d.status === 'credited' ? 'up' : 'gold'}>
              {d.status === 'credited' ? t('status_credited') : `${t('status_confirming')} ${d.confirmations}/${d.required}`}
            </Txt>
          </Row>
          <Row style={{ justifyContent: 'space-between' }}>
            <Txt v="tiny" tone="muted">{meta?.chains[d.chain]?.name ?? d.chain} · {new Date(d.created).toLocaleString()}</Txt>
            {d.status === 'credited' && <Txt v="tiny" num tone="muted">+{num(d.creditUsdt)} USDT</Txt>}
          </Row>
        </Card>
      ))}
    </>
  )
}

const styles = StyleSheet.create({
  action: { alignItems: 'center', gap: 6, width: 76 },
  actionIcon: { width: 50, height: 50, borderRadius: 16, alignItems: 'center', justifyContent: 'center' },
  bal: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 16, paddingVertical: 12 },
  usdt: { width: 36, height: 36, borderRadius: 18, alignItems: 'center', justifyContent: 'center' },
})
