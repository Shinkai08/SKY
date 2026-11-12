import { router, useLocalSearchParams } from 'expo-router'
import { useState } from 'react'
import { KeyboardAvoidingView, Platform, Pressable, StyleSheet, TextInput, View } from 'react-native'
import { api, errCode } from '@/lib/api'
import { useAuth } from '@/lib/auth'
import { success, tap } from '@/lib/haptics'
import { useErr, useI18n } from '@/lib/i18n'
import { usePoll } from '@/lib/sky'
import { radius, useColors } from '@/lib/theme'
import { Btn, Card, Empty, Icon, Loading, Row, Screen, Txt } from '@/ui/kit'
import { AuthorLine, PnlCard, type SocialPost } from '@/ui/Social'

// One discussion: the post, likes, replies and a reply box.
export default function Thread() {
  const { id } = useLocalSearchParams<{ id: string }>()
  const { t } = useI18n()
  const err = useErr()
  const c = useColors()
  const { me } = useAuth()
  const [post, setPost] = useState<SocialPost & { topic: string }>()
  const [issue, setIssue] = useState('')
  const [rev, setRev] = useState(0)
  const [reply, setReply] = useState('')
  const [busy, setBusy] = useState(false)
  usePoll(() => {
    api<SocialPost & { topic: string }>(`/community/${id}`).then(setPost).catch(e => setIssue(errCode(e)))
  }, 5000, [id, rev])
  const like = async () => {
    if (!me) { router.push('/login'); return }
    tap()
    await api(`/community/${id}/like`, { body: {} }).catch(() => undefined)
    setRev(x => x + 1)
  }
  const send = async () => {
    setBusy(true); setIssue('')
    try { await api(`/community/${id}/replies`, { body: { body: reply } }); success(); setReply(''); setRev(x => x + 1) }
    catch (e) { setIssue(errCode(e)) } finally { setBusy(false) }
  }
  if (!post) return <Screen>{issue ? <Empty text={err(issue)} /> : <Loading />}</Screen>
  const date = (v: string) => new Date(v).toLocaleString()
  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined} keyboardVerticalOffset={90}>
      <Screen>
        <View style={[styles.topic, { backgroundColor: c.surface2 }]}><Txt v="tiny" tone="gold">{t(`topic_${post.topic}`)}</Txt></View>
        <Txt v="title">{post.title}</Txt>
        <AuthorLine a={post.authorInfo} id={post.author} sub={`· ${date(post.created)}`} />
        <Txt tone="ink2" selectable>{post.body}</Txt>
        {post.card && <PnlCard c={post.card} />}
        <Pressable onPress={like} hitSlop={8}>
          <Row gap={6}><Icon name={post.liked ? 'heart.fill' : 'heart'} size={18} color={post.liked ? c.red : c.muted} /><Txt tone="muted">{post.likes}</Txt></Row>
        </Pressable>
        <Txt v="h2">{t('discussionReplies')} · {post.replyCount}</Txt>
        {post.replies?.map(r => (
          <Card key={r.id}>
            <AuthorLine a={r.authorInfo} id={r.author} sub={`· ${date(r.created)}`} />
            <Txt v="small" tone="ink2" selectable>{r.body}</Txt>
          </Card>
        ))}
        {issue ? <Txt v="small" tone="down">{err(issue)}</Txt> : null}
        {me ? (
          <View style={{ gap: 8 }}>
            <TextInput style={[styles.input, { backgroundColor: c.surface2, color: c.ink }]} multiline maxLength={1200} value={reply}
              onChangeText={setReply} placeholder={t('writeReply')} placeholderTextColor={c.muted} selectionColor={c.gold} />
            <Btn title={t('writeReply')} busy={busy} disabled={!reply.trim()} onPress={send} />
          </View>
        ) : <Btn kind="secondary" title={t('login')} onPress={() => router.push('/login')} />}
      </Screen>
    </KeyboardAvoidingView>
  )
}

const styles = StyleSheet.create({
  topic: { alignSelf: 'flex-start', paddingHorizontal: 8, paddingVertical: 3, borderRadius: 6 },
  input: { minHeight: 90, borderRadius: radius.m, paddingHorizontal: 14, paddingTop: 12, fontSize: 16, textAlignVertical: 'top' },
})
