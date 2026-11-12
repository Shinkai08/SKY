import qrcode from 'qrcode-generator'
import { useMemo } from 'react'
import { Image } from 'expo-image'
import { View } from 'react-native'
import Svg, { Defs, G, LinearGradient, Rect, Stop } from 'react-native-svg'
import { SITE } from '@/config'

/** The link a user's SKY code opens: their profile page on the website. */
export const profileLink = (id: number) => `${SITE}/#/k7bg/${id}`
/** The user id in a SKY profile link, if the text is one. */
export const profileIdOf = (text: string) => {
  const m = text.match(/#\/k7bg\/(\d+)$/)
  return m ? Number(m[1]) : undefined
}

/** SKY-styled QR: soft modules, gold finder pupils, the emblem in the middle (level H). */
export function SkyQR({ text, size = 240 }: { text: string; size?: number }) {
  const { n, dots } = useMemo(() => {
    const qr = qrcode(0, 'H')
    qr.addData(text)
    qr.make()
    const n = qr.getModuleCount()
    const inFinder = (r: number, c: number) => (r < 7 && c < 7) || (r < 7 && c >= n - 7) || (r >= n - 7 && c < 7)
    const logo = Math.ceil(n * 0.22)
    const lo = Math.floor((n - logo) / 2), hi = lo + logo
    const dots: [number, number][] = []
    for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) {
      if (qr.isDark(r, c) && !inFinder(r, c) && !(r >= lo && r < hi && c >= lo && c < hi)) dots.push([r, c])
    }
    return { n, dots }
  }, [text])
  const q = 2, V = n + 2 * q, logo = n * 0.2
  const eye = (x: number, y: number) => (
    <G key={`${x},${y}`}>
      <Rect x={x + 0.5} y={y + 0.5} width={6} height={6} rx={1.6} fill="none" stroke="#14161a" strokeWidth={1} />
      <Rect x={x + 2} y={y + 2} width={3} height={3} rx={0.8} fill="url(#skyqrgold)" />
    </G>
  )
  const px = size / V
  return (
    <View style={{ width: size, height: size }}>
      <Svg viewBox={`0 0 ${V} ${V}`} width={size} height={size}>
        <Defs>
          <LinearGradient id="skyqrgold" x1="0" y1="0" x2="1" y2="1">
            <Stop offset="0" stopColor="#9a7428" /><Stop offset="0.55" stopColor="#7d5c1c" /><Stop offset="1" stopColor="#5c4210" />
          </LinearGradient>
        </Defs>
        <Rect width={V} height={V} rx={2.5} fill="#ffffff" />
        <G transform={`translate(${q} ${q})`}>
          {dots.map(([r, c]) => <Rect key={`${r}.${c}`} x={c + 0.04} y={r + 0.04} width={0.92} height={0.92} rx={0.3} fill="#14161a" />)}
          {eye(0, 0)}{eye(n - 7, 0)}{eye(0, n - 7)}
          <Rect x={(n - logo) / 2 - 0.6} y={(n - logo) / 2 - 0.6} width={logo + 1.2} height={logo + 1.2} rx={1.6} fill="#ffffff" />
        </G>
      </Svg>
      <Image source={require('@/assets/vip/emblem.png')} contentFit="cover"
        style={{ position: 'absolute', left: (q + (n - logo) / 2) * px, top: (q + (n - logo) / 2) * px, width: logo * px, height: logo * px }} />
    </View>
  )
}
