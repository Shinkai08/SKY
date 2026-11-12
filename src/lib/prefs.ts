import { persisted } from './storage'

export type Prefs = {
  theme: 'system' | 'dark' | 'light'
  /** green-up: green rises, red falls (international); red-up: the Chinese convention. */
  updown: 'green-up' | 'red-up'
  faceId: boolean
}

export const prefs = persisted<Prefs>('sky.prefs', { theme: 'dark', updown: 'green-up', faceId: false })

/** Watchlist (stars), shared by Markets and the pair picker. */
export const stars = persisted<string[]>('sky.stars', ['BTCUSDT', 'ETHUSDT'])
export const toggleStar = (sym: string) => stars.set(l => (l.includes(sym) ? l.filter(s => s !== sym) : [...l, sym]))

/** What the Trade tab shows: set by Markets / Home / positions before switching tabs. */
export const tradeTarget = persisted<{ sym: string; spot: boolean }>('sky.trade', { sym: 'BTCUSDT', spot: false })
