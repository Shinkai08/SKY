import * as Clipboard from 'expo-clipboard'
import { useEffect, useState } from 'react'
import { Pressable, ScrollView, StyleSheet, View } from 'react-native'
import { api, errCode } from '@/lib/api'
import { useDepositMeta } from '@/lib/deposit'
import { success, tap } from '@/lib/haptics'
import { useErr, useI18n } from '@/lib/i18n'
import { useAccount } from '@/lib/sky'
import { useColors } from '@/lib/theme'
import { Btn, Card, Field, Icon, Row, Screen, Txt } from '@/ui/kit'

// Deposit (the website's DepositPanel): asset, network, address, simulate.
export default function DepositScreen() {
  const { t } = useI18n()
  const err = useErr()
  const c = useColors()
  const meta = useDepositMeta()
  const { refresh } = useAccount()
  const [asset, setAsset] = useState('USDT')
  const [chain, setChain] = useState('TRX')
  const [addr, setAddr] = useState<{ address: string; demo: boolean }>()
  const [addrErr, setAddrErr] = useState('')
  const [copied, setCopied] = useState(false)
  const [amount, setAmount] = useState('100')
  const [msg, setMsg] = useState('')
  const [busy, setBusy] = useState(false)
  const cur = meta?.assets.find(x => x.symbol === asset)
  useEffect(() => { if (cur && !cur.chains.includes(chain)) setChain(cur.chains[0]) }, [cur, chain])
  useEffect(() => {
    if (!cur?.chains.includes(chain)) return
    setAddr(undefined); setAddrErr('')
    api<{ address: string; demo: boolean }>(`/deposit/address?asset=${asset}&chain=${chain}`).then(setAddr).catch(e => setAddrErr(err(errCode(e))))
  }, [asset, chain, cur]) // eslint-disable-line react-hooks/exhaustive-deps
  const copy = async () => {
    if (!addr) return
    await Clipboard.setStringAsync(addr.address)
    success(); setCopied(true); setTimeout(() => setCopied(false), 1500)
  }
  const simulate = async () => {
    setMsg(''); setBusy(true)
    try { await api('/deposit/simulate', { body: { asset, chain, amount: Number(amount.replace(/,/g, '.')) } }); success(); setMsg(t('saved')); refresh() }
    catch (e) { setMsg(err(errCode(e))) }
    finally { setBusy(false) }
  }
  const ch = meta?.chains[chain]
  const chip = (on: boolean, title: string, sub: string, onPress: () => void) => (
    <Pressable key={title} onPress={() => { tap(); onPress() }} style={[styles.chip, { backgroundColor: on ? c.gold : c.surface2 }]}>
      <Txt v="small" bold tone={on ? 'onGold' : 'ink'}>{title}</Txt>
      <Txt v="tiny" tone={on ? 'onGold' : 'muted'}>{sub}</Txt>
    </Pressable>
  )
  return (
    <Screen>
      <Txt v="small" tone="muted">{t('selectAsset')}</Txt>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
        {meta?.assets.map(x => chip(asset === x.symbol, x.symbol, x.name, () => setAsset(x.symbol)))}
      </ScrollView>
      <Txt v="small" tone="muted">{t('network')}</Txt>
      <View style={styles.wrap}>
        {cur?.chains.map(id => chip(chain === id, meta!.chains[id].name, meta!.chains[id].network, () => setChain(id)))}
      </View>
      <Card>
        <Txt v="small" tone="muted">{t('depositAddress')}</Txt>
        <Txt num selectable style={{ fontFamily: 'Menlo' }}>{addr?.address ?? (addrErr || '…')}</Txt>
        <Btn small kind="secondary" icon={copied ? 'checkmark' : 'doc.on.doc'} title={copied ? t('copied') : t('copy')} disabled={!addr} onPress={copy} />
      </Card>
      {addr?.demo && <Row style={{ alignItems: 'flex-start' }}><Icon name="exclamationmark.triangle" size={15} color={c.red} /><Txt v="small" tone="down" style={{ flex: 1 }}>{t('demoAddrWarn')}</Txt></Row>}
      {addr && !addr.demo && <Txt v="small" tone="gold">{t('liveAddrNote', { asset, network: `${ch?.name ?? chain} (${ch?.network ?? ''})` })}</Txt>}
      <Card>
        <Row style={{ justifyContent: 'space-between' }}><Txt v="small" tone="muted">{t('minDeposit')}</Txt><Txt v="small" num>{cur?.minDeposit} {asset}</Txt></Row>
        <Row style={{ justifyContent: 'space-between' }}><Txt v="small" tone="muted">{t('confirmations')}</Txt><Txt v="small" num>{ch?.confirmations}</Txt></Row>
      </Card>
      <Txt v="tiny" tone="muted">{t('convertNote')}</Txt>
      {meta?.simulate && (
        <Card>
          <Txt v="small">{t('simulateDeposit')}</Txt>
          <Field label={t('amount')} value={amount} onChangeText={setAmount} keyboardType="decimal-pad" suffix={asset} />
          <Btn title={t('submit')} busy={busy} onPress={simulate} />
          {msg ? <Txt v="small" tone="ink2">{msg}</Txt> : null}
        </Card>
      )}
    </Screen>
  )
}

const styles = StyleSheet.create({
  chip: { paddingHorizontal: 14, paddingVertical: 8, borderRadius: 12, gap: 2, minWidth: 90 },
  wrap: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
})
