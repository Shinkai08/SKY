import { router, Stack } from 'expo-router'
import { useState } from 'react'
import { Pressable, StyleSheet, TextInput, View } from 'react-native'
import { api, errCode } from '@/lib/api'
import { useAuth } from '@/lib/auth'
import { success, tap } from '@/lib/haptics'
import { useErr, useI18n } from '@/lib/i18n'
import { usePoll } from '@/lib/sky'
import { radius, useColors } from '@/lib/theme'
import { Btn, Empty, Icon, Loading, Screen, Seg, Tabs, Txt } from '@/ui/kit'
import { Sheet } from '@/ui/Sheet'
import { PostCard, type SocialPost } from '@/ui/Social'

export type Topic = 'general' | 'market' | 'developer' | 'feedback'
type Post = SocialPost & { topic: Topic }
const topics: Topic[] = ['general', 'market', 'developer', 'feedback']

// Community feed: topics, posts, likes, and a composer sheet.
export default function Community() {
  const { t } = useI18n()
  const err = useErr()
  const c = useColors()
  const { me } = useAuth()
  const [topic, setTopic] = useState<Topic | 'all'>('all')
  const [posts, setPosts] = useState<Post[]>()
  const [down, setDown] = useState(false)
  const [rev, setRev] = useState(0)
  const [compose, setCompose] = useState(false)
  const [draft, setDraft] = useState({ title: '', body: '', topic: 'general' as Topic })
  const [busy, setBusy] = useState(false)
  const [msg, setMsg] = useState('')
  const name = (v: Topic | 'all') => t(v === 'all' ? 'sub_all' : `topic_${v}`)
  usePoll(() => {
    api<Post[]>(`/community${topic === 'all' ? '' : `?topic=${topic}`}`).then(d => { setPosts(d); setDown(false) }).catch(() => setDown(true))
  }, 10_000, [topic, rev])
  const like = async (id: number) => {
    if (!me) { router.push('/login'); return }
    await api(`/community/${id}/like`, { body: {} }).catch(() => undefined)
    setRev(x => x + 1)
  }
  const publish = async () => {
    setBusy(true); setMsg('')
    try {
      const post = await api<Post>('/community', { body: draft })
      success()
      setDraft({ title: '', body: '', topic: draft.topic })
      setCompose(false)
      setRev(x => x + 1)
      router.push(`/community/${post.id}`)
    } catch (e) { setMsg(err(errCode(e))) } finally { setBusy(false) }
  }
  const input = [styles.input, { backgroundColor: c.surface2, color: c.ink }]
  return (
    <>
      <Stack.Screen options={{
        headerRight: () => (
          <Pressable hitSlop={8} onPress={() => { tap(); if (me) setCompose(true); else router.push('/login') }}>
            <Icon name="square.and.pencil" size={22} color={c.gold} />
          </Pressable>
        ),
      }} />
      <Screen pad={false} style={{ paddingTop: 10 }} refreshing={false} onRefresh={() => setRev(x => x + 1)}>
        <Tabs items={(['all', ...topics] as const).map(id => ({ id, label: name(id) }))} value={topic} onChange={setTopic} />
        <View style={{ padding: 16, gap: 12 }}>
          {!posts ? (down ? <Empty text={t('err_service_unavailable')} /> : <Loading />)
            : posts.length === 0 ? <Empty text={t('communityEmpty')} icon="bubble.left.and.bubble.right" />
            : posts.map(p => <PostCard key={p.id} p={p} onOpen={() => router.push(`/community/${p.id}`)} onLike={() => like(p.id)} />)}
        </View>
      </Screen>
      <Sheet visible={compose} title={t('newDiscussion')} onClose={() => setCompose(false)}>
        <Seg items={topics.map(id => ({ id, label: name(id) }))} value={draft.topic} onChange={v => setDraft({ ...draft, topic: v })} />
        <Txt v="small" tone="ink2">{t('discussionTitle')}</Txt>
        <TextInput style={input} maxLength={100} value={draft.title} onChangeText={v => setDraft({ ...draft, title: v })} selectionColor={c.gold} />
        <Txt v="small" tone="ink2">{t('discussionBody')}</Txt>
        <TextInput style={[input, { height: 160, paddingTop: 12, textAlignVertical: 'top' }]} multiline maxLength={1500} value={draft.body}
          onChangeText={v => setDraft({ ...draft, body: v })} selectionColor={c.gold} />
        {msg ? <Txt v="small" tone="down">{msg}</Txt> : null}
        <Btn title={t('publishDiscussion')} busy={busy} disabled={!draft.title.trim() || !draft.body.trim()} onPress={publish} />
      </Sheet>
    </>
  )
}

const styles = StyleSheet.create({
  input: { minHeight: 46, borderRadius: radius.m, paddingHorizontal: 14, fontSize: 16 },
})
