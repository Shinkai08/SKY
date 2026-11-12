import * as Application from 'expo-application'
import { Image } from 'expo-image'
import { manipulateAsync, SaveFormat } from 'expo-image-manipulator'
import * as ImagePicker from 'expo-image-picker'
import * as LocalAuthentication from 'expo-local-authentication'
import { router } from 'expo-router'
import { useEffect, useState } from 'react'
import { Platform, Pressable, StyleSheet, Switch, TextInput, View } from 'react-native'
import { API } from '@/config'
import { api, errCode } from '@/lib/api'
import { useAuth } from '@/lib/auth'
import { success, tap } from '@/lib/haptics'
import { LANGS, LANG_NAMES, useErr, useI18n, type Lang } from '@/lib/i18n'
import { prefs } from '@/lib/prefs'
import { radius, useColors } from '@/lib/theme'
import { Avatar } from '@/ui/Avatar'
import { Btn, Group, Icon, ListRow, Row, Screen, Txt } from '@/ui/kit'
import { Sheet } from '@/ui/Sheet'

type Mine = { id: number; nick: string; bio: string; avatar: string; frame?: string; photo?: string; tags: string[]; publicPerf: boolean }
const EMOJI = ['🐂', '🦊', '🦌', '🐶', '🐱', '🐼', '🐯', '🦁', '🐻', '🐳', '🦅', '🐲', '🚀', '💎', '🌙', '⭐']
const FRAMES = ['', 'orbit', 'frost', 'jade', 'noir', 'crown'] as const

function useMine() {
  const { me } = useAuth()
  const [mine, setMine] = useState<Mine>()
  const reload = () => (me ? api<Mine>(`/users/${me.id}`).then(setMine).catch(() => undefined) : Promise.resolve())
  useEffect(() => { reload() }, [me?.id]) // eslint-disable-line react-hooks/exhaustive-deps
  return { mine, reload }
}

export default function Settings() {
  const { t, lang } = useI18n()
  const c = useColors()
  const { me } = useAuth()
  const p = prefs.useValue()
  const { mine, reload } = useMine()
  const [sheet, setSheet] = useState<'' | 'lang' | 'profile' | 'frames' | 'about'>('')
  const [bio, setBio] = useState(false)
  useEffect(() => {
    if (Platform.OS === 'web') return
    LocalAuthentication.hasHardwareAsync().then(h => LocalAuthentication.isEnrolledAsync().then(e => setBio(h && e))).catch(() => setBio(false))
  }, [])
  const setFaceId = async (on: boolean) => {
    if (on) {
      const r = await LocalAuthentication.authenticateAsync({ promptMessage: t('app_faceId'), cancelLabel: t('app_cancel') })
      if (!r.success) return
    }
    prefs.set(x => ({ ...x, faceId: on }))
  }
  const togglePerf = async () => {
    if (!mine) return
    await api('/me/privacy', { method: 'PUT', body: { publicPerf: !mine.publicPerf } }).catch(() => undefined)
    reload()
  }
  const themes = [{ id: 'system', k: 'app_themeSystem' }, { id: 'dark', k: 'app_themeDark' }, { id: 'light', k: 'app_themeLight' }] as const
  const nextTheme = () => {
    const i = themes.findIndex(x => x.id === p.theme)
    prefs.set(x => ({ ...x, theme: themes[(i + 1) % themes.length].id }))
  }

  return (
    <Screen>
      <Group title={t('set_general')}>
        <ListRow icon="globe" label={t('language')} value={LANG_NAMES[lang]} onPress={() => setSheet('lang')} />
        <ListRow icon="dollarsign.circle" label={t('currency')} value="USDT" />
        {bio && <ListRow icon="faceid" label={t('app_faceId')} value={<Switch value={p.faceId} onValueChange={setFaceId} trackColor={{ true: c.gold }} />} last />}
      </Group>

      <Group title={t('set_theme')}>
        <ListRow icon="circle.lefthalf.filled" label={t('app_theme')} value={t(themes.find(x => x.id === p.theme)?.k ?? 'app_themeDark')} onPress={nextTheme} />
        <ListRow icon="arrow.up.arrow.down" label={t('set_colorConf')} onPress={() => prefs.set(x => ({ ...x, updown: x.updown === 'green-up' ? 'red-up' : 'green-up' }))}
          value={<Row gap={2}><Txt bold style={{ color: p.updown === 'green-up' ? '#2ebd85' : '#f0566f' }}>↑</Txt><Txt bold style={{ color: p.updown === 'green-up' ? '#f0566f' : '#2ebd85' }}>↓</Txt></Row>} />
        <ListRow icon="clock" label={t('set_tz')} value={`${t('set_24h')} · UTC+8`} last />
      </Group>

      {me && (
        <Group title={t('set_account')}>
          <ListRow icon="person.crop.circle" label={t('set_profile')} onPress={() => setSheet('profile')} />
          <ListRow icon="circle.dashed" label={t('avatarFrames')} onPress={() => setSheet('frames')} />
          <ListRow icon="eye" label={t('pf_public')} value={<Switch value={!!mine?.publicPerf} onValueChange={togglePerf} trackColor={{ true: c.gold }} />} />
          <ListRow icon="crown" label={t('vipTitle')} onPress={() => router.push('/vip')} last />
        </Group>
      )}

      <Group title={t('set_other')}>
        <ListRow icon="doc.text" label={t('set_privacyCenter')} onPress={() => router.push('/privacy')} />
        <ListRow icon="info.circle" label={t('set_about')} onPress={() => setSheet('about')} />
        <ListRow icon="number" label={t('app_version')} value={`${Application.nativeApplicationVersion ?? '1.0.0'} (${Application.nativeBuildVersion ?? '1'})`} last />
      </Group>

      <Sheet visible={sheet === 'lang'} title={t('language')} onClose={() => setSheet('')}><LangList onDone={() => setSheet('')} /></Sheet>
      <Sheet visible={sheet === 'profile'} title={t('set_profile')} onClose={() => setSheet('')}>{mine && <ProfileForm mine={mine} reload={reload} />}</Sheet>
      <Sheet visible={sheet === 'frames'} title={t('avatarFrames')} onClose={() => setSheet('')}>{mine && <Frames mine={mine} reload={reload} />}</Sheet>
      <Sheet visible={sheet === 'about'} title={t('set_about')} onClose={() => setSheet('')}>
        <View style={{ alignItems: 'center', gap: 10 }}>
          <Image source={require('@/assets/brand/sky-logo.webp')} style={{ width: 140, height: 124 }} contentFit="contain" />
          <Txt v="h2">{t('brandFull')}</Txt>
          <Txt v="small" tone="ink2" center>{t('about_body')}</Txt>
        </View>
        <Group>
          <ListRow label={t('about_company')} value="SKY Global" />
          <ListRow label={t('about_founder')} value="Shinkai.CC" last />
        </Group>
        <Txt v="tiny" tone="muted" center>© 2026 SKY Global · Skyline Exchange 天际交易所</Txt>
      </Sheet>
    </Screen>
  )
}

function LangList({ onDone }: { onDone: () => void }) {
  const { lang, setLang } = useI18n()
  const c = useColors()
  return (
    <Group>
      {LANGS.map((l, i) => (
        <ListRow key={l} label={LANG_NAMES[l]} last={i === LANGS.length - 1}
          value={lang === l ? <Icon name="checkmark" size={16} color={c.gold} /> : undefined}
          onPress={() => { setLang(l as Lang); onDone() }} />
      ))}
    </Group>
  )
}

function ProfileForm({ mine, reload }: { mine: Mine; reload: () => Promise<unknown> }) {
  const { t } = useI18n()
  const err = useErr()
  const c = useColors()
  const [f, setF] = useState({ nick: mine.nick, bio: mine.bio, avatar: mine.avatar, tags: mine.tags ?? [] })
  const [tag, setTag] = useState('')
  const [busy, setBusy] = useState(false)
  const [msg, setMsg] = useState('')
  const input = [styles.input, { backgroundColor: c.surface2, color: c.ink }]

  const upload = async () => {
    const pick = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], allowsEditing: true, aspect: [1, 1], quality: 1 })
    if (pick.canceled || !pick.assets[0]) return
    setBusy(true); setMsg('')
    try {
      const img = await manipulateAsync(pick.assets[0].uri, [{ resize: { width: 512, height: 512 } }], { compress: 0.9, format: SaveFormat.JPEG })
      const blob = await (await fetch(img.uri)).blob()
      const r = await fetch(`${API}/me/photo`, { method: 'POST', credentials: 'include', headers: { 'Content-Type': 'image/jpeg' }, body: blob })
      if (!r.ok) throw new Error(((await r.json().catch(() => ({}))) as { error?: string }).error ?? 'invalid_photo')
      await reload(); success(); setMsg(t('saved'))
    } catch (e) { setMsg(err(e instanceof Error && e.message ? e.message : 'invalid_photo')) }
    finally { setBusy(false) }
  }
  const removePhoto = async () => {
    setBusy(true)
    try { await api('/me/photo', { method: 'DELETE' }); await reload() } catch (e) { setMsg(err(errCode(e))) } finally { setBusy(false) }
  }
  const addTag = () => {
    const v = tag.trim()
    if (!v || [...v].length > 10 || f.tags.length >= 5 || f.tags.some(x => x.toLowerCase() === v.toLowerCase())) return
    setF({ ...f, tags: [...f.tags, v] }); setTag('')
  }
  const save = async () => {
    setBusy(true); setMsg('')
    try { await api('/me/profile', { method: 'PUT', body: f }); await reload(); success(); setMsg(t('saved')) } catch (e) { setMsg(err(errCode(e))) } finally { setBusy(false) }
  }
  return (
    <>
      <Row gap={16}>
        <Avatar a={{ nick: f.nick || mine.nick, avatar: f.avatar, frame: mine.frame, photo: mine.photo }} size={84} />
        <View style={{ flex: 1, gap: 8 }}>
          <Btn small icon="camera" title={t('pf_upload')} busy={busy} onPress={upload} />
          {mine.photo ? <Btn small kind="secondary" icon="trash" title={t('pf_removePhoto')} onPress={removePhoto} /> : null}
          <Txt v="tiny" tone="muted">{t('pf_photoHint')}</Txt>
        </View>
      </Row>
      {!mine.photo && (
        <View style={{ gap: 6 }}>
          <Txt v="small" tone="ink2">{t('pf_avatar')}</Txt>
          <View style={styles.emojis}>
            {['', ...EMOJI].map(a => (
              <Pressable key={a || 'letter'} onPress={() => { tap(); setF({ ...f, avatar: a }) }}
                style={[styles.emoji, { backgroundColor: c.surface2, borderColor: f.avatar === a ? c.gold : 'transparent' }]}>
                <Txt v="h2">{a || [...(f.nick || '?')][0]?.toUpperCase()}</Txt>
              </Pressable>
            ))}
          </View>
        </View>
      )}
      <Txt v="small" tone="ink2">{t('pf_nick')}</Txt>
      <TextInput style={input} value={f.nick} maxLength={20} onChangeText={v => setF({ ...f, nick: v })} selectionColor={c.gold} />
      <Txt v="small" tone="ink2">{t('pf_bio')} · {[...f.bio].length}/80</Txt>
      <TextInput style={input} value={f.bio} maxLength={80} onChangeText={v => setF({ ...f, bio: v })} selectionColor={c.gold} />
      <Txt v="small" tone="ink2">{t('pf_tags')} · {f.tags.length}/5</Txt>
      <View style={styles.emojis}>
        {f.tags.map(x => (
          <Pressable key={x} onPress={() => setF({ ...f, tags: f.tags.filter(y => y !== x) })} style={[styles.tag, { backgroundColor: c.surface2 }]}>
            <Txt v="small">{x} ✕</Txt>
          </Pressable>
        ))}
      </View>
      {f.tags.length < 5 && (
        <Row>
          <TextInput style={[input, { flex: 1 }]} value={tag} maxLength={10} placeholder={t('pf_tagsHint')} placeholderTextColor={c.muted}
            onChangeText={setTag} onSubmitEditing={addTag} selectionColor={c.gold} />
          <Btn small kind="secondary" icon="plus" title="" onPress={addTag} disabled={!tag.trim()} />
        </Row>
      )}
      {msg ? <Txt v="small" tone="ink2">{msg}</Txt> : null}
      <Btn title={t('pf_save')} busy={busy} disabled={f.nick.trim().length < 2} onPress={save} />
    </>
  )
}

function Frames({ mine, reload }: { mine: Mine; reload: () => Promise<unknown> }) {
  const { t } = useI18n()
  const c = useColors()
  const [frame, setFrame] = useState(mine.frame ?? '')
  const [busy, setBusy] = useState(false)
  const [msg, setMsg] = useState('')
  const save = async () => {
    setBusy(true); setMsg('')
    try { await api('/me/avatar-frame', { method: 'PUT', body: { frame } }); await reload(); success(); setMsg(t('saved')) } catch { setMsg(t('frameSaveFailed')) } finally { setBusy(false) }
  }
  const who = { nick: mine.nick, avatar: mine.avatar, photo: mine.photo }
  return (
    <>
      <Txt v="small" tone="muted">{t('frameDescription')}</Txt>
      <View style={styles.frames}>
        {FRAMES.map(v => (
          <Pressable key={v || 'none'} onPress={() => { tap(); setFrame(v) }} style={[styles.frame, { borderColor: frame === v ? c.gold : c.line, backgroundColor: c.surface }]}>
            <Avatar a={{ ...who, frame: v }} size={64} />
            <Txt v="tiny">{t(`frame_${v || 'none'}`)}</Txt>
          </Pressable>
        ))}
      </View>
      {msg ? <Txt v="small" tone="ink2">{msg}</Txt> : null}
      <Btn title={t('saveFrame')} busy={busy} disabled={frame === (mine.frame ?? '')} onPress={save} />
    </>
  )
}

const styles = StyleSheet.create({
  input: { height: 46, borderRadius: radius.m, paddingHorizontal: 14, fontSize: 16 },
  emojis: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  emoji: { width: 44, height: 44, borderRadius: 12, alignItems: 'center', justifyContent: 'center', borderWidth: 2 },
  tag: { paddingHorizontal: 10, paddingVertical: 6, borderRadius: 14 },
  frames: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  frame: { width: '30%', alignItems: 'center', gap: 6, paddingVertical: 12, borderRadius: 14, borderWidth: 1.5 },
})
