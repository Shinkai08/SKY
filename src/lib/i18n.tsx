import { getLocales } from 'expo-localization'
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import data from '@/web/design/locales.json'
import { EXTRA } from '@/web/i18n-extra'
import { APP_STRINGS } from './strings'
import { loadJSON, saveJSON } from './storage'

// Same strings and API as the website's i18n (t / num / signed), plus a few
// app-only keys. Defaults to the phone's language.

export type Lang = 'en' | 'nl' | 'es' | 'zh-CN' | 'zh-TW'
export const LANGS = data.locales as Lang[]
export const LANG_NAMES: Record<Lang, string> = {
  en: 'English', nl: 'Nederlands', es: 'Español', 'zh-CN': '简体中文', 'zh-TW': '繁體中文',
}
const strings: Record<string, string[]> = { ...(data.strings as Record<string, string[]>), ...EXTRA, ...APP_STRINGS }

type Ctx = {
  lang: Lang
  setLang: (l: Lang) => void
  t: (key: string, vars?: Record<string, string>) => string
  num: (n: number, digits?: number) => string
  signed: (n: number, digits?: number, suffix?: string) => string
}
const I18n = createContext<Ctx | null>(null)

function phoneLang(): Lang {
  const l = getLocales()[0]
  const tag = l?.languageTag ?? 'en'
  if (tag.startsWith('zh')) return /TW|HK|MO|Hant/.test(tag) ? 'zh-TW' : 'zh-CN'
  const short = tag.slice(0, 2) as Lang
  return LANGS.includes(short) ? short : 'en'
}

function formatter(lang: string, digits: number) {
  try {
    return new Intl.NumberFormat(lang, { minimumFractionDigits: digits, maximumFractionDigits: digits, useGrouping: true })
  } catch {
    return { format: (n: number) => n.toFixed(digits) }
  }
}

export function I18nProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>(phoneLang)
  useEffect(() => {
    loadJSON<Lang | null>('sky.lang', null).then(l => { if (l && LANGS.includes(l)) setLangState(l) })
  }, [])
  const setLang = useCallback((l: Lang) => { setLangState(l); saveJSON('sky.lang', l) }, [])
  const value = useMemo<Ctx>(() => {
    const idx = LANGS.indexOf(lang)
    const cache = new Map<number, { format: (n: number) => string }>()
    const nf = (d: number) => {
      let f = cache.get(d)
      if (!f) { f = formatter(lang, d); cache.set(d, f) }
      return f
    }
    return {
      lang, setLang,
      t: (key, vars) => {
        const s = strings[key]?.[idx] ?? strings[key]?.[0] ?? key
        return vars ? s.replace(/\{(\w+)\}/g, (_, k: string) => vars[k] ?? '') : s
      },
      num: (n, d = 2) => nf(d).format(Number.isFinite(n) ? n : 0),
      signed: (n, d = 2, suffix = '') => `${n >= 0 ? '+' : '−'}${nf(d).format(Math.abs(n))}${suffix}`,
    }
  }, [lang, setLang])
  return <I18n.Provider value={value}>{children}</I18n.Provider>
}

export const useI18n = () => {
  const c = useContext(I18n)
  if (!c) throw new Error('useI18n outside provider')
  return c
}

/** Error message for an API error code (falls back to the code). */
export function useErr() {
  const { t } = useI18n()
  return (code: string) => {
    const k = `err_${code}`, v = t(k)
    return v === k ? code : v
  }
}
