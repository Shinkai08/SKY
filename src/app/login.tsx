import { Image } from 'expo-image'
import { router } from 'expo-router'
import { useState } from 'react'
import { KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, TextInput, View } from 'react-native'
import { errCode } from '@/lib/api'
import { useAuth } from '@/lib/auth'
import { success, tap, warn } from '@/lib/haptics'
import { useErr, useI18n } from '@/lib/i18n'
import { radius, useColors } from '@/lib/theme'
import { Btn, Icon, Row, Seg, Txt } from '@/ui/kit'

// Login / register in one modal sheet (the website's AuthPage).
export default function Login() {
  const { t } = useI18n()
  const err = useErr()
  const c = useColors()
  const { login, register } = useAuth()
  const [mode, setMode] = useState<'login' | 'register'>('login')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [show, setShow] = useState(false)
  const [agree, setAgree] = useState(false)
  const [busy, setBusy] = useState(false)
  const [msg, setMsg] = useState('')
  const reg = mode === 'register'
  const ok = !!email && password.length >= 1 && (!reg || agree)

  const submit = async () => {
    if (busy || !ok) return
    setBusy(true); setMsg('')
    try {
      await (reg ? register : login)(email.trim(), password)
      success()
      if (router.canGoBack()) router.back()
      else router.replace('/')
      if (reg) router.navigate('/(tabs)/assets')
    } catch (e) {
      warn()
      setMsg(err(errCode(e)))
    } finally {
      setBusy(false)
    }
  }

  const input = [styles.input, { backgroundColor: c.surface2, color: c.ink }]
  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1, backgroundColor: c.bg }}>
      <ScrollView contentContainerStyle={styles.body} keyboardShouldPersistTaps="handled">
        <Row style={{ justifyContent: 'flex-end' }}>
          <Pressable hitSlop={12} onPress={() => router.back()} accessibilityLabel={t('me_back')}><Icon name="xmark" size={20} color={c.muted} /></Pressable>
        </Row>
        <Image source={require('@/assets/brand/sky-logo.webp')} style={styles.logo} contentFit="contain" />
        <Txt v="title" center>{reg ? t('authWelcome') : t('authWelcomeBack')}</Txt>
        <Seg items={[{ id: 'login', label: t('login') }, { id: 'register', label: t('register') }]} value={mode} onChange={m => { setMode(m); setMsg('') }} />

        <View style={{ gap: 6 }}>
          <Txt v="small" tone="ink2">{t('email')}</Txt>
          <TextInput style={input} value={email} onChangeText={setEmail} placeholder={t('emailPh')} placeholderTextColor={c.muted}
            autoCapitalize="none" autoCorrect={false} keyboardType="email-address" textContentType="emailAddress" autoComplete="email" selectionColor={c.gold} />
        </View>
        <View style={{ gap: 6 }}>
          <Txt v="small" tone="ink2">{t('password')}</Txt>
          <View>
            <TextInput style={[input, { paddingRight: 48 }]} value={password} onChangeText={setPassword} secureTextEntry={!show}
              placeholder={reg ? t('passwordHint') : t('passwordPh')} placeholderTextColor={c.muted} selectionColor={c.gold}
              textContentType={reg ? 'newPassword' : 'password'} autoComplete={reg ? 'new-password' : 'current-password'} onSubmitEditing={submit} returnKeyType="go" />
            <Pressable style={styles.eye} hitSlop={8} onPress={() => { tap(); setShow(s => !s) }}>
              <Icon name={show ? 'eye.slash' : 'eye'} size={18} color={c.muted} />
            </Pressable>
          </View>
        </View>

        {reg && (
          <Pressable onPress={() => { tap(); setAgree(a => !a) }} style={styles.agree}>
            <Icon name={agree ? 'checkmark.square.fill' : 'square'} size={20} color={agree ? c.gold : c.muted} />
            <Txt v="small" tone="ink2" style={{ flex: 1 }}>
              {t('agreePrefix')}
              <Txt v="small" tone="gold" style={{ textDecorationLine: 'underline' }}>{t('privacyNotice')}</Txt>
              {t('agreeSuffix')}
            </Txt>
          </Pressable>
        )}
        {reg && <Pressable onPress={() => router.push('/privacy')}><Txt v="small" tone="muted">{t('privacyNotice')} ›</Txt></Pressable>}

        {msg ? <Txt v="small" tone="down" center>{msg}</Txt> : null}
        <Btn title={reg ? t('register') : t('login')} onPress={submit} disabled={!ok} busy={busy} />
      </ScrollView>
    </KeyboardAvoidingView>
  )
}

const styles = StyleSheet.create({
  body: { padding: 24, gap: 18, paddingBottom: 60 },
  logo: { width: 120, height: 107, alignSelf: 'center' },
  input: { height: 52, borderRadius: radius.m, paddingHorizontal: 16, fontSize: 17 },
  eye: { position: 'absolute', right: 14, top: 16 },
  agree: { flexDirection: 'row', alignItems: 'flex-start', gap: 10 },
})
