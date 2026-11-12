import { router, Stack, useLocalSearchParams } from 'expo-router'
import { useCallback, useEffect, useState } from 'react'
import { StyleSheet, View } from 'react-native'
import { api, ApiError, errCode } from '@/lib/api'
import { useAuth } from '@/lib/auth'
import { success } from '@/lib/haptics'
import { useErr, useI18n } from '@/lib/i18n'
import { openTrade } from '@/lib/nav'
import { useColors } from '@/lib/theme'
import { Avatar } from '@/ui/Avatar'
import { Btn, Card, Empty, Icon, Loading, Row, Screen, Seg, Tabs, Txt } from '@/ui/kit'
import { AIBadge, PnlChart, PostCard, Verified, type SocialPost, type SocialReply } from '@/ui/Social'

type Badge = { key: string; n?: number }
type ProfileData = {
  id: number; nick: string; bio: string; avatar: string; frame?: string; photo?: string; tags?: string[]; ai: boolean; verified: boolean; joined: string; days: number; badges: Badge[]
  following: number; followers: number; likes: number; posts: number; isMe: boolean; isFollowing: boolean; publicPerf: boolean
}
type Pos = { sym: string; base: string; qty: number; entry: number; mark: number; upnl: number; lev: number; margin: number
  priceDec: number; qtyDec: number; cross: boolean; roe: number; marginRatio: number; liq: number }
type Closed = { sym: string; base: string; long: boolean; qty: number; entry: number; exit: number; pnl: number; t: number; priceDec: number }
type Perf = {
  days: number; total: number; netIn: number; pnl: number; ret: number; rangePnl: number; rangeRet: number; maxDrawdown: number; winRate: number
  curve: { t: number; pnl: number; ret: number; total: number }[]
  trader: { positions: Pos[]; closed: Closed[]; wins: number; losses: number }
}
type Feed = { posts: SocialPost[]; replies: (SocialReply & { postId: number; postTitle: string })[] }

// A trader's public profile: identity, follow, posts, replies, live record.
export default function Profile() {
  const { id: idParam } = useLocalSearchParams<{ id: string }>()
  const id = Number(idParam)
  const { t } = useI18n()
  const err = useErr()
  const c = useColors()
  const { me } = useAuth()
  const [p, setP] = useState<ProfileData>()
  const [issue, setIssue] = useState('')
  const [tab, setTab] = useState<'content' | 'replies' | 'live'>('content')
  const [feed, setFeed] = useState<Feed>()
  const [rev, setRev] = useState(0)
  useEffect(() => {
    let alive = true
    api<ProfileData>(`/users/${id}`).then(d => { if (!alive) return; setP(d); if (rev === 0) setTab(d.ai || d.publicPerf ? 'live' : 'content') })
      .catch(e => alive && setIssue(errCode(e)))
    api<Feed>(`/users/${id}/posts`).then(d => alive && setFeed(d)).catch(() => undefined)
    return () => { alive = false }
  }, [id, rev, me?.id]) // eslint-disable-line react-hooks/exhaustive-deps
  const follow = async () => {
    if (!me) { router.push('/login'); return }
    try { await api(`/users/${id}/follow`, { body: {} }); success(); setRev(r => r + 1) } catch (e) { setIssue(errCode(e)) }
  }
  const like = async (post: SocialPost) => {
    if (!me) { router.push('/login'); return }
    await api(`/community/${post.id}/like`, { body: {} }).catch(() => undefined)
    setRev(r => r + 1)
  }
  if (!p) return <Screen>{issue ? <Empty text={err(issue)} /> : <Loading />}</Screen>
  return (
    <>
      <Stack.Screen options={{ title: p.nick }} />
      <Screen>
        <Row gap={14}>
          <Avatar a={p} size={80} />
          <View style={{ flex: 1, gap: 4 }}>
            <Row gap={6} style={{ flexWrap: 'wrap' }}><Txt v="title">{p.nick}</Txt>{p.verified && <Verified size={18} />}{p.ai && <AIBadge />}</Row>
            <Row gap={14}>
              <Txt v="small" tone="muted"><Txt v="small" bold>{p.following}</Txt> {t('pf_followingN')}</Txt>
              <Txt v="small" tone="muted"><Txt v="small" bold>{p.followers}</Txt> {t('pf_followers')}</Txt>
              <Txt v="small" tone="muted"><Txt v="small" bold>{p.likes}</Txt> {t('pf_likes')}</Txt>
            </Row>
          </View>
        </Row>
        {p.bio ? <Txt tone="ink2">{p.bio}</Txt> : null}
        <Row gap={6} style={{ flexWrap: 'wrap' }}>
          {p.badges.filter(b => b.key !== 'ai').map(b => (
            <View key={b.key} style={[styles.chip, { backgroundColor: c.surface2 }]}><Txt v="tiny" tone="gold">{t(`pf_badge_${b.key}`, { n: String(b.n ?? '') })}</Txt></View>
          ))}
          {(p.tags ?? []).map(x => <View key={x} style={[styles.chip, { backgroundColor: c.surface2 }]}><Txt v="tiny" tone="ink2">{x}</Txt></View>)}
        </Row>
        {p.ai && <Txt v="small" tone="muted">{t('pf_aiNote')}</Txt>}
        {p.isMe
          ? <Btn kind="ghost" icon="pencil" title={t('pf_edit')} onPress={() => router.push('/settings')} />
          : <Btn kind={p.isFollowing ? 'secondary' : 'primary'} icon={p.isFollowing ? 'checkmark' : 'person.badge.plus'}
              title={`${t(p.isFollowing ? 'pf_following' : 'pf_follow')} · ${p.followers}`} onPress={follow} />}
        {issue ? <Txt v="small" tone="down">{err(issue)}</Txt> : null}

        <Tabs style={{ paddingHorizontal: 0 }} items={[{ id: 'content', label: t('pf_content') }, { id: 'replies', label: t('pf_replies') }, { id: 'live', label: t('pf_live') }]} value={tab} onChange={setTab} />
        {tab === 'content' && (feed?.posts.length
          ? feed.posts.map(post => <PostCard key={post.id} p={post} onLike={() => like(post)} onOpen={() => router.push(`/community/${post.id}`)} />)
          : <Empty text={t('pf_noPosts')} />)}
        {tab === 'replies' && (feed?.replies.length
          ? feed.replies.map(r => (
            <Card key={`${r.postId}-${r.id}`} onPress={() => router.push(`/community/${r.postId}`)}>
              <Txt v="tiny" tone="muted">{t('pf_repliedTo')} 「{r.postTitle}」 · {new Date(r.created).toLocaleString()}</Txt>
              <Txt v="small" tone="ink2">{r.body}</Txt>
            </Card>
          ))
          : <Empty text={t('pf_noPosts')} />)}
        {tab === 'live' && <Live id={id} rev={rev} joinedDays={p.days} />}
      </Screen>
    </>
  )
}

function Live({ id, rev, joinedDays }: { id: number; rev: number; joinedDays: number }) {
  const { t, num, signed } = useI18n()
  const [days, setDays] = useState('30')
  const [view, setView] = useState<'ret' | 'pnl' | 'total'>('pnl')
  const [list, setList] = useState<'pos' | 'hist'>('pos')
  const [perf, setPerf] = useState<Perf>()
  const [priv, setPriv] = useState(false)
  const load = useCallback(() => api<Perf>(`/users/${id}/perf?days=${days}`).then(d => { setPerf(d); setPriv(false) })
    .catch(e => { if (e instanceof ApiError && e.status === 403) setPriv(true) }), [id, days])
  useEffect(() => { load(); const timer = setInterval(load, 15_000); return () => clearInterval(timer) }, [load, rev])
  if (priv) return <Empty text={t('pf_private')} icon="lock" />
  if (!perf) return <Loading />
  const tone = (v: number) => (v >= 0 ? 'up' : 'down')
  const series = perf.curve.map(x => (view === 'ret' ? x.ret : view === 'pnl' ? x.pnl : x.total))
  const tr = perf.trader
  const cell = (k: string, v: string, tn?: 'up' | 'down') => (
    <View style={{ width: '33%', gap: 2, paddingVertical: 6 }}><Txt v="tiny" tone="muted">{k}</Txt><Txt v="small" num bold tone={tn}>{v}</Txt></View>
  )
  return (
    <>
      <Card>
        <Txt v="h2">{t('pf_perf')}</Txt>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap' }}>
          {cell(t('pf_cumRet'), signed(perf.ret, 2, '%'), tone(perf.ret))}
          {cell(t('pf_totalPnl'), signed(perf.pnl), tone(perf.pnl))}
          {cell(t('pf_assets'), num(perf.total))}
          {cell(t('pf_days'), String(joinedDays))}
          {cell(t('pf_win'), `${num(perf.winRate, 2)}%`)}
          {cell(t('pf_mdd'), `${num(perf.maxDrawdown, 2)}%`)}
        </View>
        <Seg items={[{ id: 'ret', label: t('pf_ret') }, { id: 'pnl', label: t('pf_pnl') }, { id: 'total', label: t('pf_assetsShort') }]} value={view} onChange={setView} />
        <Seg items={[{ id: '7', label: t('pf_d7') }, { id: '30', label: t('pf_d30') }, { id: '90', label: t('pf_d90') }]} value={days} onChange={setDays} />
        <Txt v="small" num tone={tone(perf.rangePnl)}>{signed(perf.rangePnl)} USDT · {signed(perf.rangeRet, 2, '%')}</Txt>
        <PnlChart values={series} height={170} zero={view !== 'total'} />
      </Card>
      <Seg items={[{ id: 'pos', label: `${t('pf_positions')} (${tr.positions.length})` }, { id: 'hist', label: t('pf_history') }]} value={list} onChange={setList} />
      {list === 'pos'
        ? (tr.positions.length ? tr.positions.map(x => (
          <Card key={x.sym} onPress={() => openTrade(x.sym, false)}>
            <Row style={{ justifyContent: 'space-between' }}>
              <Row><Txt bold tone={x.qty > 0 ? 'up' : 'down'}>{x.qty > 0 ? 'B' : 'S'}</Txt><Txt bold>{x.sym}</Txt><Txt v="tiny" tone="muted">{t('pf_perp')} · {x.lev}x</Txt></Row>
              <Icon name="chevron.right" size={13} />
            </Row>
            <Row style={{ justifyContent: 'space-between' }}>
              <Txt v="h2" num tone={tone(x.upnl)}>{signed(x.upnl)}</Txt>
              <Txt v="h2" num tone={tone(x.roe)}>{signed(x.roe, 2, '%')}</Txt>
            </Row>
            <Row style={{ justifyContent: 'space-between' }}>
              <Txt v="tiny" tone="muted" num>{t('pf_entry')} {num(x.entry, x.priceDec)}</Txt>
              <Txt v="tiny" tone="muted" num>{t('pf_mark')} {num(x.mark, x.priceDec)}</Txt>
              <Txt v="tiny" tone="muted" num>{t('pf_liq')} {x.liq > 0 ? num(x.liq, x.priceDec) : '—'}</Txt>
            </Row>
          </Card>
        )) : <Empty text={t('pf_noPositions')} />)
        : (tr.closed.length ? tr.closed.map((x, i) => (
          <Row key={i} style={{ justifyContent: 'space-between', paddingVertical: 6 }}>
            <View style={{ flex: 1 }}>
              <Txt v="small" bold>{x.long ? 'B' : 'S'} · {x.sym}</Txt>
              <Txt v="tiny" tone="muted" num>{num(x.entry, x.priceDec)} → {num(x.exit, x.priceDec)} · {new Date(x.t).toLocaleString()}</Txt>
            </View>
            <Txt num bold tone={tone(x.pnl)}>{signed(x.pnl)}</Txt>
          </Row>
        )) : <Empty text={t('pf_noPositions')} />)}
    </>
  )
}

const styles = StyleSheet.create({
  chip: { paddingHorizontal: 8, paddingVertical: 4, borderRadius: 10 },
})
