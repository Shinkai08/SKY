import { Platform } from 'react-native'

/**
 * The SKY site the app talks to. Native builds call it by absolute URL (the
 * session cookie is kept by iOS). The web build used for local checks is
 * served by skyd itself, so it calls its own origin.
 * Override with EXPO_PUBLIC_SKY_URL (e.g. a local test server).
 */
export const SITE = (process.env.EXPO_PUBLIC_SKY_URL ?? 'https://sky.shinkaicc.com').replace(/\/$/, '')
export const API = Platform.OS === 'web' ? '/api/v1' : `${SITE}/api/v1`
/** Absolute URL for site paths (avatars, uploads) on every platform. */
export const siteUrl = (path: string) => (Platform.OS === 'web' ? path : `${SITE}${path}`)
