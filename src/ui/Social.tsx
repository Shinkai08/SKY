import { router } from 'expo-router'
import { Pressable, StyleSheet, View } from 'react-native'
import Svg, { Defs, Line, LinearGradient, Path, Stop } from 'react-native-svg'
import { tap } from '@/lib/haptics'
import { useI18n } from '@/lib/i18n'
import { useColors } from '@/lib/theme'
import { Avatar } from './Avatar'
import { useWidth } from './charts'
import { Icon, Row, Txt } from './kit'

export type AuthorInfo = { id: number; nick: string; avatar: string; frame?: string; photo?: string; ai: boolean; verified?: boolean }
export type PnlCardData = { days: number; ret: number; pnl: number; winRate: number; maxDrawdown: number; equity: number; curve: number[]; position?: string }
export type SocialReply = { id: number; author: number; body: string; created: string; authorInfo?: AuthorInfo }
export type SocialPost = SocialReply & { title: string; topic: string; replyCount: number; replies?: SocialReply[]; likes: number; liked: boolean; card?: PnlCardData }

export function Verified({ size = 14 }: { size?: number }) {
  const c = useColors()
  return <Icon name="checkmark.seal.fill" size={size} color={c.gold} />
}

export function AIBadge({ small }: { small?: boolean }) {
  const { t } = useI18n()
  const c = useColors()
  return (
    <View style={[styles.ai, { backgroundColor: c.surface2 }]}>
      <Txt v="tiny" bold tone="gold">{small ? 'AI' : t('pf_badge_ai')}</Txt>
    </View>
  )
}

/** Avatar + nickname (opens the profile) + badges + a small subtitle. */
export function AuthorLine({ a, id, sub }: { a?: AuthorInfo; id: number; sub?: string }) {
  return (
    <Pressable onPress={() => { tap(); router.push(`/user/${id}`) }}>
      <Row>
        <Avatar a={a} size={32} />
        <Row gap={4} style={{ flex: 1, flexWrap: 'wrap' }}>
          <Txt bold>{a?.nick ?? `SKY #${id}`}</Txt>
          {a?.verified && <Verified />}
          {a?.ai && <AIBadge small />}
          {sub ? <Txt v="tiny" tone="muted">{sub}</Txt> : null}
        </Row>
      </Row>
    </Pressable>
  )
}

/** Area line: green above zero, red below. */
export function PnlChart({ values, height = 160, zero = true }: { values: number[]; height?: number; zero?: boolean }) {
  const c = useColors()
  const [W, onLayout] = useWidth()
  const H = height, pad = 6
  if (values.length < 2 || !W) return <View style={{ height }} onLayout={onLayout} />
  const lo = Math.min(...values, zero ? 0 : Infinity), hi = Math.max(...values, zero ? 0 : -Infinity)
  const span = hi - lo || 1
  const x = (i: number) => pad + (i / (values.length - 1)) * (W - 2 * pad)
  const y = (v: number) => pad + (1 - (v - lo) / span) * (H - 2 * pad)
  const line = values.map((v, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(' ')
  const zy = Math.max(pad, Math.min(H - pad, zero ? y(0) : H - pad))
  const split = Math.max(0, Math.min(1, zy / H))
  return (
    <View style={{ height }} onLayout={onLayout}>
      <Svg width={W} height={H}>
        <Defs>
          <LinearGradient id="pnlsplit" x1="0" y1="0" x2="0" y2={String(H)} gradientUnits="userSpaceOnUse">
            <Stop offset={split} stopColor={c.up} /><Stop offset={split} stopColor={c.down} />
          </LinearGradient>
        </Defs>
        {zero && <Line x1={0} x2={W} y1={zy} y2={zy} stroke={c.line} strokeDasharray="4,4" />}
        <Path d={`${line} L${x(values.length - 1)},${zy} L${x(0)},${zy} Z`} fill="url(#pnlsplit)" opacity={0.14} />
        <Path d={line} fill="none" stroke="url(#pnlsplit)" strokeWidth={2} strokeLinejoin="round" />
      </Svg>
    </View>
  )
}

/** Return card attached to a post (numbers come from the author's account). */
export function PnlCard({ c: d }: { c: PnlCardData }) {
  const { t, num, signed } = useI18n()
  const c = useColors()
  const tone = d.ret >= 0 ? 'up' : 'down'
  return (
    <View style={[styles.pnl, { backgroundColor: c.surface2 }]}>
      <Row style={{ justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <View>
          <Txt v="tiny" tone="muted">{t('pf_card', { n: String(d.days) })}</Txt>
          <Txt v="title" num tone={tone}>{signed(d.ret, 2, '%')}</Txt>
        </View>
        <View style={{ alignItems: 'flex-end', gap: 2 }}>
          <Txt v="tiny" num tone={tone}>{t('pf_pnl')} {signed(d.pnl)} USDT</Txt>
          <Txt v="tiny" num tone="muted">{t('pf_win')} {num(d.winRate, 1)}%</Txt>
          <Txt v="tiny" num tone="muted">{t('pf_mdd')} {num(d.maxDrawdown, 2)}%</Txt>
        </View>
      </Row>
      <PnlChart values={d.curve} height={80} />
      {d.position ? <Txt v="tiny" tone="ink2">{d.position}</Txt> : null}
    </View>
  )
}

export function PostCard({ p, onOpen, onLike }: { p: SocialPost; onOpen?: () => void; onLike?: () => void }) {
  const c = useColors()
  return (
    <Pressable onPress={onOpen} style={({ pressed }) => [styles.post, { backgroundColor: c.surface, borderColor: c.line }, pressed && { opacity: 0.8 }]}>
      <AuthorLine a={p.authorInfo} id={p.author} sub={`· ${new Date(p.created).toLocaleString()}`} />
      <Txt v="h2">{p.title}</Txt>
      <Txt v="small" tone="ink2" lines={4}>{p.body}</Txt>
      {p.card && <PnlCard c={p.card} />}
      <Row gap={18}>
        <Row gap={4}><Icon name="bubble.right" size={15} color={c.muted} /><Txt v="small" tone="muted">{p.replyCount}</Txt></Row>
        <Pressable hitSlop={8} disabled={!onLike} onPress={() => { tap(); onLike?.() }}>
          <Row gap={4}><Icon name={p.liked ? 'heart.fill' : 'heart'} size={15} color={p.liked ? c.red : c.muted} /><Txt v="small" tone="muted">{p.likes}</Txt></Row>
        </Pressable>
      </Row>
    </Pressable>
  )
}

const styles = StyleSheet.create({
  ai: { paddingHorizontal: 5, paddingVertical: 1, borderRadius: 4 },
  pnl: { borderRadius: 12, padding: 12, gap: 6 },
  post: { borderRadius: 16, padding: 14, gap: 10, borderWidth: StyleSheet.hairlineWidth },
})
