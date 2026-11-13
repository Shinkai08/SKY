// Records the JSON the app reads in demo mode (-demo) into SKY/Resources/Demo,
// from a LOCAL test skyd (never the live site) plus Binance public data.
//   node scripts/record-demo.mjs http://127.0.0.1:8091 email password
// File names match Demo.key(url) in SKY/Core/API.swift.
import { writeFileSync, mkdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const out = join(root, 'SKY/Resources/Demo')
mkdirSync(out, { recursive: true })
const [local = 'http://127.0.0.1:8091', email, password] = process.argv.slice(2)
const SITE = 'https://sky.shinkaicc.com'

function key(u) {
  const url = new URL(u)
  let s = ''
  if (url.host !== 'sky.shinkaicc.com') s += url.host + '_'
  s += url.pathname
  if (url.search.length > 1) s += '_' + url.search.slice(1)
  return s.replace(/[^A-Za-z0-9]/g, '_').slice(0, 150)
}

let cookie = ''
async function sky(path, init = {}) {
  const r = await fetch(local + '/api/v1' + path, { ...init, headers: { 'content-type': 'application/json', cookie, ...(init.headers ?? {}) } })
  const set = r.headers.get('set-cookie')
  if (set) cookie = set.split(';')[0]
  return { status: r.status, text: await r.text() }
}

function save(url, text) {
  writeFileSync(join(out, key(url) + '.json'), text)
}

const login = await sky('/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) })
if (login.status !== 200) throw new Error('login failed: ' + login.status)
const me = JSON.parse(login.text)

const skyPaths = [
  '/me', '/account', '/me/avatar', '/me/center', '/me/profile', '/me/privacy', '/sky/markets', '/listings', '/market-sentiment',
  `/users/${me.id}`, `/users/${me.id}/posts`, `/users/${me.id}/perf?days=1`, `/users/${me.id}/perf?days=7`, `/users/${me.id}/perf?days=30`,
  '/markets?cat=crypto', '/markets?cat=tradfi', '/markets?cat=commodities', '/markets?cat=onchain',
  '/snapshot?sym=BTCUSDT', '/snapshot?sym=BTCUSDT&type=spot', '/deposits', '/deposit/assets',
  '/predictions', '/predictions/me', '/games/crash', '/games/crash/me', '/games/blackjack', '/games/blackjack/me',
  '/community', '/welcome-gift',
  '/klines/ref?sym=BTCUSDT&i=1h&perp=1', '/klines/ref?sym=BTCUSDT&i=1h', '/klines/ref?sym=BTCUSDT&i=15m&perp=1',
]
for (const p of skyPaths) {
  const r = await sky(p)
  if (r.status === 200) save(SITE + '/api/v1' + p, r.text)
  console.log(r.status, p)
}

// Binance (public).
const homeSyms = ['BTCUSDT', 'ETHUSDT', 'SOLUSDT', 'XRPUSDT', 'DOGEUSDT', 'AVAXUSDT', 'LINKUSDT', 'PAXGUSDT']
const binance = [
  `https://data-api.binance.vision/api/v3/ticker/tradingDay?symbols=${encodeURIComponent(JSON.stringify(homeSyms))}&timeZone=8`,
  'https://fapi.binance.com/fapi/v1/ticker/24hr?symbol=BTCUSDT',
]
for (const u of binance) {
  const r = await fetch(u)
  if (r.ok) save(u, await r.text())
  console.log(r.status, u.slice(0, 90))
}
