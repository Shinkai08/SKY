import * as LocalAuthentication from 'expo-local-authentication'
import { Image } from 'expo-image'
import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react'
import { AppState, Platform, StyleSheet, View } from 'react-native'
import { useI18n } from '@/lib/i18n'
import { prefs } from '@/lib/prefs'
import { useColors } from '@/lib/theme'
import { Btn, Txt } from './kit'

const RELOCK_AFTER = 60_000 // back from the background after a minute: ask again

/** Face ID gate: covers the app until the owner authenticates (when turned on in settings). */
export function Lock({ children }: { children: ReactNode }) {
  const { faceId } = prefs.useValue()
  const enabled = faceId && Platform.OS !== 'web'
  const [locked, setLocked] = useState(enabled)
  const away = useRef(0)
  const c = useColors()
  const { t } = useI18n()

  const unlock = useCallback(async () => {
    const r = await LocalAuthentication.authenticateAsync({ promptMessage: t('app_unlock'), cancelLabel: t('app_cancel') })
    if (r.success) setLocked(false)
  }, [t])

  useEffect(() => { setLocked(enabled) }, [enabled])
  useEffect(() => { if (locked) unlock() }, [locked, unlock])
  useEffect(() => {
    if (!enabled) return
    const sub = AppState.addEventListener('change', s => {
      if (s === 'background') away.current = Date.now()
      if (s === 'active' && away.current && Date.now() - away.current > RELOCK_AFTER) setLocked(true)
    })
    return () => sub.remove()
  }, [enabled])

  return (
    <View style={{ flex: 1 }}>
      {children}
      {locked && (
        <View style={[StyleSheet.absoluteFill, styles.cover, { backgroundColor: c.bg }]}>
          <Image source={require('@/assets/brand/sky-logo.webp')} style={styles.logo} contentFit="contain" />
          <Txt v="title">{t('app_unlock')}</Txt>
          <Btn title={t('app_unlockBtn')} icon="faceid" onPress={unlock} style={{ alignSelf: 'stretch' }} />
        </View>
      )}
    </View>
  )
}

const styles = StyleSheet.create({
  cover: { alignItems: 'center', justifyContent: 'center', gap: 20, padding: 40 },
  logo: { width: 140, height: 124 },
})
