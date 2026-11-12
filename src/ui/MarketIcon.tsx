import { Image } from 'expo-image'
import { useState } from 'react'
import { Text, View } from 'react-native'

// Coin / stock / FX logos, same sources as the website's MarketIcon; a
// coloured monogram when no logo loads.

type Asset = { base: string; icon?: string; cat?: string; sub?: string; chain?: string }

const companies: Record<string, string> = {
  AAPL: 'apple.com', NVDA: 'nvidia.com', MSFT: 'microsoft.com', AMZN: 'amazon.com',
  GOOG: 'google.com', GOOGL: 'google.com', AVGO: 'broadcom.com', META: 'meta.com',
  TSLA: 'tesla.com', BRK: 'berkshirehathaway.com', BRKB: 'berkshirehathaway.com',
  LLY: 'lilly.com', JPM: 'jpmorganchase.com', AMD: 'amd.com', MU: 'micron.com',
  V: 'visa.com', JNJ: 'jnj.com', XOM: 'exxonmobil.com', WMT: 'walmart.com',
  MA: 'mastercard.com', ABBV: 'abbvie.com', COST: 'costco.com', CVX: 'chevron.com',
  PG: 'pg.com', PLTR: 'palantir.com', CSCO: 'cisco.com', KO: 'coca-colacompany.com',
  INTC: 'intel.com', ORCL: 'oracle.com', IBM: 'ibm.com', NFLX: 'netflix.com',
  NKE: 'nike.com', HD: 'homedepot.com', DIS: 'disney.com', UBER: 'uber.com',
  COIN: 'coinbase.com', MSTR: 'strategy.com', HOOD: 'robinhood.com', QCOM: 'qualcomm.com',
  TSM: 'tsmc.com', BABA: 'alibabagroup.com', ASML: 'asml.com', CRM: 'salesforce.com',
  ADBE: 'adobe.com', ARM: 'arm.com', MRK: 'merck.com', UNH: 'unitedhealthgroup.com',
  BAC: 'bankofamerica.com', GS: 'goldmansachs.com', MCD: 'mcdonalds.com',
  SKHYNIX: 'skhynix.com', SAMSUNG: 'samsung.com', SAMSUNGEM: 'samsungsem.com',
  HYUNDAI: 'hyundai.com', HANMI: 'hanmisemi.com', LGELECTRONICS: 'lg.com',
  NAVER: 'naver.com', KODEX200: 'samsungfund.com', TENCENT: 'tencent.com',
  HK0700: 'tencent.com', HK1810: 'mi.com', BYD: 'byd.com', HK0992: 'lenovo.com',
  POPMART: 'popmart.com', MEITUAN: 'meituan.com', KUAISHOU: 'kuaishou.com',
  OPENAI: 'openai.com', ANTHROPIC: 'anthropic.com', OURA: 'ouraring.com',
  UNITREE: 'unitree.com', CXMT: 'cxmt.com', MINIMAX: 'minimax.io',
  QQQ: 'invesco.com', SPY: 'ssga.com', IWM: 'ishares.com', EWY: 'ishares.com', EWJ: 'ishares.com',
}
const country: Record<string, string> = {
  EUR: 'eu', USD: 'us', GBP: 'gb', JPY: 'jp', CHF: 'ch', CAD: 'ca', AUD: 'au', NZD: 'nz',
  CNY: 'cn', HKD: 'hk', SGD: 'sg', KRW: 'kr', INR: 'in', BRL: 'br', MXN: 'mx',
  ZAR: 'za', SEK: 'se', NOK: 'no', DKK: 'dk', PLN: 'pl', CZK: 'cz', HUF: 'hu',
  RON: 'ro', TRY: 'tr', THB: 'th', IDR: 'id', MYR: 'my', PHP: 'ph', ILS: 'il', UAH: 'ua',
}

function logoURL(it: Asset, base: string) {
  if (it.icon) return it.icon
  if (it.sub === 'fx') {
    const flag = country[base.slice(0, 3)]
    return flag ? `https://flagcdn.com/w80/${flag}.png` : undefined
  }
  if (!it.chain && (it.cat === 'crypto' || it.sub === 'spot' || !it.cat) && /^[A-Z0-9]{2,12}$/.test(base)) {
    return `https://cdn.jsdelivr.net/npm/cryptocurrency-icons@0.18.1/128/color/${base.toLowerCase()}.png`
  }
  const domain = !it.chain && companies[base]
  return domain ? `https://www.google.com/s2/favicons?domain=${domain}&sz=64` : undefined
}

export function MarketIcon({ it, size = 28 }: { it: Asset; size?: number }) {
  const base = it.base.toUpperCase().replace(/[\s.-]/g, '')
  const src = logoURL(it, base)
  const [failed, setFailed] = useState<string>()
  if (src && src !== failed) {
    return <Image source={{ uri: src }} style={{ width: size, height: size, borderRadius: size / 2 }} onError={() => setFailed(src)} cachePolicy="memory-disk" />
  }
  let hue = 0
  for (const ch of base) hue = (hue * 31 + ch.charCodeAt(0)) % 360
  return (
    <View style={{ width: size, height: size, borderRadius: size / 2, backgroundColor: `hsl(${hue}, 48%, 36%)`, alignItems: 'center', justifyContent: 'center' }}>
      <Text style={{ color: '#fff', fontSize: size * 0.36, fontWeight: '700' }}>{base.slice(0, 2)}</Text>
    </View>
  )
}
