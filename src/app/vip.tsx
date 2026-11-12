import { useState } from 'react'
import { ScrollView, StyleSheet, View } from 'react-native'
import { useI18n } from '@/lib/i18n'
import { useAccount } from '@/lib/sky'
import { useColors } from '@/lib/theme'
import { TIERS, nextTier, pct, vipOf, type Market } from '@/web/vip'
import { Card, Row, Screen, Seg, Txt } from '@/ui/kit'
import { CARD_TIERS, JoyCard, cardFor, tierName } from '@/ui/VipCard'

// VIP: your card, fees, progress to the next tier, the card gallery, the tier table.
export default function Vip() {
  const { t, num } = useI18n()
  const c = useColors()
  const { account } = useAccount()
  const [m, setM] = useState<Market>('spot')
  const v = vipOf(account)
  const { spot, perp, assetsUsd, volume30d } = v
  const current = v[m]
  const next = nextTier(spot)
  const progress = next ? Math.min(1, assetsUsd / next.minAssets) : 1
  const short = (x: number) => num(x, Number.isInteger(x) ? 0 : 1)
  const usd = (n: number) => (n >= 1e9 ? `${short(n / 1e9)}B` : n >= 1e6 ? `${short(n / 1e6)}M` : num(n, 0))
  return (
    <Screen>
      <Txt v="small" tone="muted">{t('vipSubtitle')}</Txt>
      <View style={{ alignItems: 'center' }}><JoyCard level={spot.level} width={330} /></View>
      <Card>
        <Row style={{ justifyContent: 'space-between' }}><Txt v="small" tone="muted">{t('vipCardFees')}</Txt><Txt v="small" tone="muted">{t('maker')} / {t('taker')}</Txt></Row>
        <Row style={{ justifyContent: 'space-between' }}><Txt>{t('spot')}</Txt><Txt num>{pct(spot.maker.spot)} / {pct(spot.taker.spot)}</Txt></Row>
        <Row style={{ justifyContent: 'space-between' }}><Txt>{t('perpetual')}</Txt><Txt num>{pct(perp.maker.perp)} / {pct(perp.taker.perp)}</Txt></Row>
        {next ? (
          <View style={{ gap: 6 }}>
            <Row style={{ justifyContent: 'space-between' }}>
              <Txt v="small">{t('toNext', { tier: tierName(next.level, t) })}</Txt>
              <Txt v="small" tone="muted" num>{Math.round(progress * 100)}%</Txt>
            </Row>
            <View style={[styles.bar, { backgroundColor: c.surface2 }]}><View style={{ width: `${progress * 100}%`, height: '100%', backgroundColor: c.gold }} /></View>
            <Txt v="tiny" tone="muted">{t('needAssets', { x: num(Math.max(0, next.minAssets - assetsUsd)) })} {t('needVol', { x: num(Math.max(0, next.minVolume.spot - volume30d.spot), 0) })}</Txt>
          </View>
        ) : <Txt v="small" tone="muted">{t('topTier')}</Txt>}
      </Card>

      <Txt v="h2">{t('vipCardGallery')}</Txt>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 12 }}>
        {CARD_TIERS.map(x => (
          <View key={x.tier} style={{ gap: 6, opacity: cardFor(current.level).tier === x.tier ? 1 : 0.7 }}>
            <JoyCard level={x.levels[0]} width={220} />
            <Txt v="small">{t(`vipTier_${x.tier}`)} · <Txt v="small" tone="muted">{x.levels.map(l => tierName(l, t)).join(' – ')}</Txt></Txt>
          </View>
        ))}
      </ScrollView>

      <Card style={{ paddingHorizontal: 0 }}>
        <Row style={{ paddingHorizontal: 16, justifyContent: 'space-between' }}>
          <Seg items={[{ id: 'spot', label: t('spot') }, { id: 'perp', label: t('perpetual') }]} value={m} onChange={setM} style={{ width: 170 }} />
          <Txt v="small" tone="gold">{t('yourTier')} · {tierName(current.level, t)}</Txt>
        </Row>
        <Row style={[styles.tr, { borderBottomColor: c.line }]}>
          <Txt v="tiny" tone="muted" style={styles.c1}>{t('tier')}</Txt>
          <Txt v="tiny" tone="muted" style={styles.c2}>{t('assetReq')} / {t('volReq')}</Txt>
          <Txt v="tiny" tone="muted" style={styles.c3}>{t('maker')}</Txt>
          <Txt v="tiny" tone="muted" style={styles.c3}>{t('taker')}</Txt>
        </Row>
        {TIERS.map(x => (
          <Row key={x.level} style={[styles.tr, { borderBottomColor: c.line }, x.level === current.level && { backgroundColor: c.surface2 }]}>
            <Txt v="small" bold tone={x.level === current.level ? 'gold' : 'ink'} style={styles.c1}>{tierName(x.level, t)}</Txt>
            <Txt v="tiny" num style={styles.c2}>
              {x.level === 0 ? `< ${usd(TIERS[1].minAssets)}` : `≥ ${usd(x.minAssets)}`} {t('or')} {x.level === 0 ? `< ${usd(TIERS[1].minVolume[m])}` : `≥ ${usd(x.minVolume[m])}`}
            </Txt>
            <Txt v="tiny" num tone={x.maker[m] < 0 ? 'up' : 'ink'} style={styles.c3}>{pct(x.maker[m])}</Txt>
            <Txt v="tiny" num style={styles.c3}>{pct(x.taker[m])}</Txt>
          </Row>
        ))}
        <Txt v="tiny" tone="muted" style={{ paddingHorizontal: 16 }}>{t('orRule')}</Txt>
      </Card>
    </Screen>
  )
}

const styles = StyleSheet.create({
  bar: { height: 6, borderRadius: 3, overflow: 'hidden' },
  tr: { paddingHorizontal: 16, paddingVertical: 9, borderBottomWidth: StyleSheet.hairlineWidth },
  c1: { width: 64 },
  c2: { flex: 1 },
  c3: { width: 66, textAlign: 'right' },
})
