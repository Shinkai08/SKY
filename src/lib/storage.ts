import AsyncStorage from '@react-native-async-storage/async-storage'
import { useSyncExternalStore } from 'react'

export async function loadJSON<T>(key: string, fallback: T): Promise<T> {
  try {
    const raw = await AsyncStorage.getItem(key)
    return raw === null ? fallback : (JSON.parse(raw) as T)
  } catch {
    return fallback
  }
}

export function saveJSON(key: string, value: unknown) {
  AsyncStorage.setItem(key, JSON.stringify(value)).catch(() => undefined)
}

/**
 * A small app-wide value persisted under `key`: starts at `initial`, then the
 * stored value once it has loaded. Components read it with `useValue()`.
 */
export function persisted<T>(key: string, initial: T) {
  let value = initial
  const listeners = new Set<() => void>()
  const publish = (next: T) => { value = next; listeners.forEach(l => l()) }
  loadJSON(key, initial).then(publish)
  return {
    get: () => value,
    set(next: T | ((prev: T) => T)) {
      const v = typeof next === 'function' ? (next as (p: T) => T)(value) : next
      publish(v)
      saveJSON(key, v)
    },
    useValue: () => useSyncExternalStore(l => { listeners.add(l); return () => { listeners.delete(l) } }, () => value, () => value),
  }
}
