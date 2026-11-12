import { useCallback, useEffect, useRef, useState } from 'react'
import { api } from './api'
import { useAppActive } from './sky'
import { useIsFocused } from 'expo-router'

/**
 * Polls a game's state and keeps an estimate of the server clock from the
 * quickest replies, so countdowns and curves line up with the server.
 * `delay` picks the next interval from the latest state.
 */
export function useGameState<T extends { now: number }>(path: string, delay: (s?: T) => number) {
  const [s, setS] = useState<T>()
  const [down, setDown] = useState(false)
  const offset = useRef(0)
  const best = useRef(Infinity)
  const last = useRef<T | undefined>(undefined)
  const delayRef = useRef(delay)
  delayRef.current = delay
  const focused = useIsFocused()
  const active = useAppActive()
  const load = useCallback(async () => {
    const t0 = Date.now()
    try {
      const v = await api<T>(path)
      const t1 = Date.now()
      best.current += 5
      if (t1 - t0 <= best.current) { best.current = t1 - t0; offset.current = v.now - (t0 + t1) / 2 }
      last.current = v
      setS(v)
      setDown(false)
    } catch { setDown(true) }
  }, [path])
  useEffect(() => {
    if (!focused || !active) return
    let alive = true, timer: ReturnType<typeof setTimeout> | undefined
    const loop = async () => {
      await load()
      if (alive) timer = setTimeout(loop, delayRef.current(last.current))
    }
    loop()
    return () => { alive = false; clearTimeout(timer) }
  }, [load, focused, active])
  const now = useCallback(() => Date.now() + offset.current, [])
  return { s, down, now, refresh: load }
}

/** Re-renders on every animation frame while `on`. */
export function useFrame(on: boolean) {
  const [, setTick] = useState(0)
  useEffect(() => {
    if (!on) return
    let raf = 0
    const step = () => { setTick(x => (x + 1) % 1e6); raf = requestAnimationFrame(step) }
    raf = requestAnimationFrame(step)
    return () => cancelAnimationFrame(raf)
  }, [on])
}
