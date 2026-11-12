import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { api, onSessionGone } from './api'

export type Me = { id: number; email: string; role: 'user' | 'admin'; created: string }

type Ctx = {
  me: Me | null
  ready: boolean
  login: (email: string, password: string) => Promise<void>
  register: (email: string, password: string) => Promise<void>
  logout: () => Promise<void>
  refresh: () => Promise<void>
}
const AuthCtx = createContext<Ctx | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [me, setMe] = useState<Me | null>(null)
  const [ready, setReady] = useState(false)
  const refresh = useCallback(async () => {
    await api<Me>('/me').then(setMe).catch(() => setMe(null))
  }, [])
  useEffect(() => { refresh().finally(() => setReady(true)) }, [refresh])
  useEffect(() => onSessionGone(() => setMe(null)), [])
  const login = useCallback(async (email: string, password: string) => {
    setMe(await api<Me>('/auth/login', { body: { email, password } }))
  }, [])
  const register = useCallback(async (email: string, password: string) => {
    setMe(await api<Me>('/auth/register', { body: { email, password } }))
  }, [])
  const logout = useCallback(async () => {
    await api('/auth/logout', { body: {} }).catch(() => undefined)
    setMe(null)
  }, [])
  const value = useMemo(() => ({ me, ready, login, register, logout, refresh }), [me, ready, login, register, logout, refresh])
  return <AuthCtx.Provider value={value}>{children}</AuthCtx.Provider>
}

export function useAuth() {
  const c = useContext(AuthCtx)
  if (!c) throw new Error('useAuth outside provider')
  return c
}
