import { useColorScheme } from 'react-native'
import { prefs } from './prefs'

// SKY platinum palette (mirrors the website's design/tokens.css).
const dark = {
  bg: '#0b0c0e', surface: '#14161a', surface2: '#1b1e23', hover: '#22262c',
  ink: '#edebe6', ink2: '#c3c2bd', muted: '#858891', line: '#262a30',
  gold: '#d9b560', goldHi: '#f3dc9a', goldLo: '#b8892f', onGold: '#2a1f05',
  green: '#2ebd85', red: '#f0566f', greenTint: 'rgba(46,189,133,0.14)', redTint: 'rgba(240,86,111,0.14)',
}
const light: typeof dark = {
  bg: '#f6f5f2', surface: '#ffffff', surface2: '#f3f1ec', hover: '#efece5',
  ink: '#181c20', ink2: '#3c4046', muted: '#737672', line: '#e7e4dd',
  gold: '#a67c2a', goldHi: '#e9c76f', goldLo: '#8a6420', onGold: '#2a1f05',
  green: '#1f8f6b', red: '#d04a5c', greenTint: '#e8f4ee', redTint: '#faecee',
}

export type Palette = typeof dark & { dark: boolean; up: string; down: string; upTint: string; downTint: string }

export function useColors(): Palette {
  const system = useColorScheme()
  const p = prefs.useValue()
  const isDark = p.theme === 'system' ? system !== 'light' : p.theme === 'dark'
  const c = isDark ? dark : light
  const redUp = p.updown === 'red-up'
  return {
    ...c, dark: isDark,
    up: redUp ? c.red : c.green, down: redUp ? c.green : c.red,
    upTint: redUp ? c.redTint : c.greenTint, downTint: redUp ? c.greenTint : c.redTint,
  }
}

export const radius = { s: 8, m: 12, l: 16, xl: 22 }
