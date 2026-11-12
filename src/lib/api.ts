import { API } from '@/config'

// Client for skyd's /api/v1. The session is an HttpOnly cookie the platform
// keeps; a 401 outside the login calls means it has ended, and listeners
// (the auth state) are told so the app stops acting logged in.

export class ApiError extends Error {
  constructor(public status: number, public code: string) { super(code) }
}

const gone = new Set<() => void>()
export function onSessionGone(f: () => void) {
  gone.add(f)
  return () => { gone.delete(f) }
}

export async function api<T>(path: string, init?: { method?: string; body?: unknown }): Promise<T> {
  let r: Response
  try {
    r = await fetch(`${API}${path}`, {
      method: init?.method ?? (init?.body !== undefined ? 'POST' : 'GET'),
      credentials: 'include',
      headers: { Accept: 'application/json', ...(init?.body !== undefined ? { 'Content-Type': 'application/json' } : {}) },
      body: init?.body !== undefined ? JSON.stringify(init.body) : undefined,
    })
  } catch {
    throw new ApiError(0, 'service_unavailable')
  }
  const data = await r.json().catch(() => ({}))
  if (r.status === 401 && !path.startsWith('/auth/')) gone.forEach(f => f())
  if (!r.ok) throw new ApiError(r.status, (data as { error?: string }).error ?? `http_${r.status}`)
  return data as T
}

/** Error code of a failed call, for `t('err_' + code)`. */
export const errCode = (e: unknown) => (e instanceof ApiError ? e.code : 'service_unavailable')
