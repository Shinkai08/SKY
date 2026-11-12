import { CameraView, useCameraPermissions } from 'expo-camera'
import * as Clipboard from 'expo-clipboard'
import { router, Stack } from 'expo-router'
import * as WebBrowser from 'expo-web-browser'
import { useCallback, useEffect, useState } from 'react'
import { Pressable, Share, StyleSheet, View } from 'react-native'
import { SITE } from '@/config'
import { api } from '@/lib/api'
import { useAuth } from '@/lib/auth'
import { success, tap } from '@/lib/haptics'
import { useI18n } from '@/lib/i18n'
import { useColors } from '@/lib/theme'
import { tierFor } from '@/web/vip'
import { Avatar } from '@/ui/Avatar'
import { Btn, Card, Empty, Group, Icon, ListRow, Row, Screen, Seg, Txt } from '@/ui/kit'
import { Sheet } from '@/ui/Sheet'
import { SkyQR, profileIdOf, profileLink } from '@/ui/SkyQR'
import { tierName } from '@/ui/VipCard'

// Personal center (the website's MeDrawer) as a native screen with sheets.

type Center = {
  id: number; nick: string; avatar: string; frame?: string; photo?: string; verified: boolean
  email: string; kyc: boolean; joined: string; total: number; volume: number; vip?: number
}
type Gift = { enabled: boolean; claimed: boolean; amount: number }
type SheetId = '' | 'qr' | 'scan' | 'coupons' | 'support' | 'soon'

export default function Me() {
  const { t, num } = useI18n()
  const c = useColors()
  const { me, logout } = useAuth()
  const [info, setInfo] = useState<Center>()
  const [gift, setGift] = useState<Gift>()
  const [sheet, setSheet] = useState<SheetId>('')
  const [showMail, setShowMail] = useState(false)
  const [copied, setCopied] = useState(false)
  const load = useCallback(() => {
    api<Center>('/me/center').then(setInfo).catch(() => undefined)
    api<Gift>('/welcome-gift').then(setGift).catch(() => undefined)
  }, [])
  useEffect(() => { if (me) load(); else router.back() }, [me, load])
  const level = info?.vip ?? tierFor('spot', info?.total ?? 0, 0).level
  const mail = info?.email ?? ''
  const masked = mail.replace(/^(.{2})[^@]*(@.*)$/, '$1***$2')
  const copyId = async () => {
    if (!info) return
    await Clipboard.setStringAsync(String(info.id))
    success(); setCopied(true); setTimeout(() => setCopied(false), 1200)
  }
  const go = (s: SheetId) => { tap(); setSheet(s) }

  return (
    <>
      <Stack.Screen options={{
        headerRight: () => (
          <Row gap={18}>
            <Pressable hitSlop={8} onPress={() => go('qr')}><Icon name="qrcode" size={21} color={c.gold} /></Pressable>
            <Pressable hitSlop={8} onPress={() => go('scan')}><Icon name="qrcode.viewfinder" size={21} color={c.gold} /></Pressable>
            <Pressable hitSlop={8} onPress={() => { tap(); router.push('/settings') }}><Icon name="gearshape" size={21} color={c.gold} /></Pressable>
          </Row>
        ),
      }} />
      <Screen>
        <Card onPress={info ? () => router.push(`/user/${info.id}`) : undefined}>
          <Row gap={14}>
            <Avatar a={info ?? { nick: '?' }} size={72} />
            <View style={{ flex: 1, gap: 4 }}>
              <Txt v="title" lines={1}>{info?.nick ?? '…'}</Txt>
              <Pressable onPress={copyId}><Row gap={6}><Txt v="small" tone="muted">ID: {info?.id ?? '—'}</Txt><Icon name={copied ? 'checkmark' : 'doc.on.doc'} size={12} color={copied ? c.gold : c.muted} /></Row></Pressable>
              <Row gap={6}>
                <View style={[styles.badge, { backgroundColor: info?.kyc ? c.greenTint : c.surface2 }]}><Txt v="tiny" tone={info?.kyc ? 'up' : 'muted'}>{t(info?.kyc ? 'me_kycYes' : 'me_kycNo')}</Txt></View>
                <View style={[styles.badge, { backgroundColor: c.surface2 }]}><Txt v="tiny" tone="gold">{tierName(level, t)}</Txt></View>
              </Row>
            </View>
            <Icon name="chevron.right" size={14} color={c.muted} />
          </Row>
        </Card>

        <Row gap={10}>
          {[{ icon: 'person.2' as const, k: 'me_invite', s: 'me_inviteSub' }, { icon: 'sparkles' as const, k: 'me_guess', s: 'me_guessSub' }].map(x => (
            <Card key={x.k} style={{ flex: 1 }} onPress={() => go('soon')}>
              <Icon name={x.icon} size={26} color={c.gold} />
              <Txt v="small" tone="muted">{t(x.k)}</Txt>
              <Txt bold>{t(x.s)}</Txt>
              <Txt v="tiny" tone="gold">{t('me_soon')}</Txt>
            </Card>
          ))}
        </Row>

        <Card onPress={() => go('coupons')}>
          <Row style={{ justifyContent: 'space-between' }}><Txt tone="muted">{t('me_coupons')}</Txt><Icon name="chevron.right" size={13} color={c.muted} /></Row>
          <CouponSummary gift={gift} />
        </Card>

        <Group title={t('me_account')}>
          <ListRow icon="checkmark.seal" label={t('me_kycCenter')} value={t(info?.kyc ? 'me_kycYes' : 'me_kycNo')} onPress={() => go('soon')} />
          <ListRow icon="envelope" label={t('me_regInfo')} value={
            <Pressable onPress={() => setShowMail(v => !v)}><Row gap={6}><Txt tone="muted">{showMail ? mail : masked}</Txt><Icon name={showMail ? 'eye.slash' : 'eye'} size={13} color={c.muted} /></Row></Pressable>
          } />
          <ListRow icon="crown" label="VIP" value={tierName(level, t)} onPress={() => router.push('/vip')} />
          <ListRow icon="shield.lefthalf.filled" label={t('me_security')} onPress={() => router.push('/settings')} last />
        </Group>

        <Group>
          <ListRow icon="bubble.left.and.bubble.right" label={t('community')} onPress={() => router.push('/community')} />
          <ListRow icon="chart.pie" label={t('predictNav')} onPress={() => router.push('/predict')} />
          <ListRow icon="headphones" label={t('me_support')} onPress={() => go('support')} />
          <ListRow icon="doc.text" label={t('privacyNotice')} onPress={() => router.push('/privacy')} last={me?.role !== 'admin'} />
          {me?.role === 'admin' && <ListRow icon="safari" label={t('app_admin')} onPress={() => WebBrowser.openBrowserAsync(`${SITE}/`)} last />}
        </Group>

        <Btn kind="danger" title={t('me_logout')} onPress={() => { logout(); router.back() }} />
        {info && <Txt v="tiny" tone="muted" center>{t('me_uid')} {info.id} · {num(info.volume, 0)} USDT</Txt>}
      </Screen>

      <Sheet visible={sheet === 'qr'} title={t('me_qrTitle')} onClose={() => setSheet('')}>{info && <QrBody info={info} />}</Sheet>
      <Sheet visible={sheet === 'scan'} title={t('me_scanTitle')} onClose={() => setSheet('')}>{sheet === 'scan' && <ScanBody onDone={() => setSheet('')} />}</Sheet>
      <Sheet visible={sheet === 'coupons'} title={t('me_coupons')} onClose={() => setSheet('')}><Coupons gift={gift} onChange={load} /></Sheet>
      <Sheet visible={sheet === 'support'} title={t('me_support')} onClose={() => setSheet('')}>
        <Empty text={t('me_supportBody')} icon="headphones" />
        <Txt bold center>{t('me_supportTitle')}</Txt>
        <Btn title={t('community')} onPress={() => { setSheet(''); router.push('/community') }} />
      </Sheet>
      <Sheet visible={sheet === 'soon'} title={t('me_soon')} onClose={() => setSheet('')}><Empty text={t('me_soonBody')} icon="gift" /></Sheet>
    </>
  )
}

function CouponSummary({ gift }: { gift?: Gift }) {
  const { t, num } = useI18n()
  const got = gift?.enabled ? 1 : 0, used = gift?.claimed ? 1 : 0
  return (
    <Row style={{ justifyContent: 'space-between' }}>
      <Txt v="small" tone="muted">{t('me_totalReward')} <Txt v="small" bold>{num(used ? gift!.amount : 0, 0)} USDT</Txt></Txt>
      <Txt v="small" tone="muted">{t('me_used')} <Txt v="small" bold>{used}</Txt></Txt>
      <Txt v="small" tone="muted">{t('me_received')} <Txt v="small" bold>{got}</Txt></Txt>
    </Row>
  )
}

function Coupons({ gift, onChange }: { gift?: Gift; onChange: () => void }) {
  const { t } = useI18n()
  const c = useColors()
  const [tab, setTab] = useState<'ok' | 'used'>('ok')
  const [busy, setBusy] = useState(false)
  const list = gift?.enabled ? [gift] : []
  const shown = list.filter(g => (tab === 'used') === g.claimed)
  const use = async () => {
    setBusy(true)
    try { await api('/welcome-gift/claim', { body: {} }); success(); onChange() } catch { /* already used */ } finally { setBusy(false) }
  }
  return (
    <>
      <CouponSummary gift={gift} />
      <Seg items={[{ id: 'ok', label: t('me_available') }, { id: 'used', label: t('me_used') }]} value={tab} onChange={setTab} />
      {shown.length ? shown.map((g, i) => (
        <Card key={i} style={{ flexDirection: 'row', alignItems: 'center', gap: 14, opacity: g.claimed ? 0.55 : 1 }}>
          <View style={{ alignItems: 'center' }}><Txt v="title" num tone="gold">{g.amount}</Txt><Txt v="tiny" tone="muted">USDT</Txt></View>
          <View style={{ flex: 1, gap: 2 }}>
            <Txt bold>{t('me_couponWelcome')}</Txt>
            <Txt v="tiny" tone="muted">{t('me_couponWelcomeDesc')}</Txt>
            <Txt v="tiny" tone="muted">{t('me_noExpiry')}</Txt>
          </View>
          {g.claimed ? <Txt v="small" tone="muted">{t('me_used')}</Txt> : <Btn small title={t('me_use')} busy={busy} onPress={use} />}
        </Card>
      )) : <Empty text={t('me_noCoupons')} icon="ticket" />}
      <Txt v="tiny" tone="muted">{t('me_couponRule')}</Txt>
      <View style={{ height: 1, backgroundColor: c.line }} />
    </>
  )
}

function QrBody({ info }: { info: Center }) {
  const { t } = useI18n()
  const [copied, setCopied] = useState(false)
  const link = profileLink(info.id)
  return (
    <>
      <Card style={{ alignItems: 'center', gap: 14, backgroundColor: '#ffffff' }}>
        <Row style={{ alignSelf: 'stretch' }}>
          <Avatar a={info} size={44} />
          <View><Txt bold style={{ color: '#14161a' }}>{info.nick}</Txt><Txt v="tiny" style={{ color: '#737672' }}>SKY ID {info.id}</Txt></View>
        </Row>
        <SkyQR text={link} size={232} />
        <Txt v="small" center style={{ color: '#737672' }}>{t('me_qrHint')}</Txt>
        <Txt v="tiny" style={{ color: '#a67c2a', letterSpacing: 2 }}>SKYLINE EXCHANGE</Txt>
      </Card>
      <Row>
        <Btn kind="secondary" icon="doc.on.doc" title={copied ? t('copied') : t('me_copyLink')} style={{ flex: 1 }}
          onPress={async () => { await Clipboard.setStringAsync(link); success(); setCopied(true); setTimeout(() => setCopied(false), 1200) }} />
        <Btn icon="square.and.arrow.up" title={t('pc_share')} style={{ flex: 1 }} onPress={() => Share.share({ message: link }).catch(() => undefined)} />
      </Row>
    </>
  )
}

function ScanBody({ onDone }: { onDone: () => void }) {
  const { t } = useI18n()
  const c = useColors()
  const [perm, ask] = useCameraPermissions()
  const [result, setResult] = useState('')
  const [scanning, setScanning] = useState(true)
  const handle = (text: string) => {
    if (!scanning) return
    setScanning(false)
    success()
    const id = profileIdOf(text)
    if (id) { onDone(); router.push(`/user/${id}`); return }
    setResult(text)
  }
  if (!perm) return null
  if (!perm.granted) {
    return (
      <>
        <Empty text={perm.canAskAgain ? t('me_camAsk') : t('me_camDenied')} icon="camera" />
        <Btn title={t('me_camAllow')} onPress={ask} />
      </>
    )
  }
  return (
    <>
      <View style={[styles.cam, { borderColor: c.gold }]}>
        {scanning
          ? <CameraView style={StyleSheet.absoluteFill} facing="back" barcodeScannerSettings={{ barcodeTypes: ['qr'] }} onBarcodeScanned={e => handle(e.data)} />
          : <View style={[StyleSheet.absoluteFill, { alignItems: 'center', justifyContent: 'center', padding: 16, backgroundColor: c.surface }]}>
              <Txt v="small" tone="muted">{t('me_scanResult')}</Txt>
              <Txt selectable center>{result}</Txt>
            </View>}
      </View>
      <Txt v="small" tone="muted" center>{t('me_scanHint')}</Txt>
      {!scanning && <Btn kind="secondary" title={t('me_scanAgain')} onPress={() => { setResult(''); setScanning(true) }} />}
    </>
  )
}

const styles = StyleSheet.create({
  badge: { paddingHorizontal: 8, paddingVertical: 3, borderRadius: 6 },
  cam: { height: 320, borderRadius: 18, overflow: 'hidden', borderWidth: 2 },
})
