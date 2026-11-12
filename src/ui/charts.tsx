import { useState } from 'react'
import { View, type LayoutChangeEvent } from 'react-native'
import Svg, { Defs, LinearGradient, Path, Polygon, Stop, Text as SvgText } from 'react-native-svg'
import { useColors } from '@/lib/theme'

/** Width of a view once laid out. */
export function useWidth(initial = 0): [number, (e: LayoutChangeEvent) => void] {
  const [w, setW] = useState(initial)
  return [w, e => setW(Math.round(e.nativeEvent.layout.width))]
}

/** Mini trend line (green / red, or gold filled). */
export function Spark({ data, w = 80, h = 30, up = true, fill = false }: { data: number[]; w?: number; h?: number; up?: boolean; fill?: boolean }) {
  const c = useColors()
  if (data.length < 2) return <View style={{ width: w, height: h }} />
  const min = Math.min(...data), max = Math.max(...data), span = max - min || 1
  const pts = data.map((v, i) => [(i / (data.length - 1)) * w, h - 2 - ((v - min) / span) * (h - 4)])
  const d = pts.map((p, i) => `${i ? 'L' : 'M'}${p[0].toFixed(1)},${p[1].toFixed(1)}`).join(' ')
  const color = fill ? c.gold : up ? c.up : c.down
  return (
    <Svg width={w} height={h}>
      {fill && (
        <>
          <Defs>
            <LinearGradient id="sparkfade" x1="0" y1="0" x2="0" y2="1">
              <Stop offset="0" stopColor={c.gold} stopOpacity={0.35} />
              <Stop offset="1" stopColor={c.gold} stopOpacity={0} />
            </LinearGradient>
          </Defs>
          <Path d={`${d} L${w},${h} L0,${h} Z`} fill="url(#sparkfade)" />
        </>
      )}
      <Path d={d} fill="none" stroke={color} strokeWidth={fill ? 2 : 1.5} strokeLinejoin="round" />
    </Svg>
  )
}

/** Fear & greed half-dial with a needle (0–100). */
export function Gauge({ score, label, size = 260 }: { score: number; label: string; size?: number }) {
  const c = useColors()
  const s = Math.max(0, Math.min(100, score))
  const a = Math.PI * (1 - s / 100)
  const dx = Math.cos(a), dy = -Math.sin(a)
  const x = 160 + 109 * dx, y = 155 + 109 * dy
  const points = `${x + 10 * dx},${y + 10 * dy} ${x - 7 * dx - 7 * dy},${y - 7 * dy + 7 * dx} ${x - 7 * dx + 7 * dy},${y - 7 * dy - 7 * dx}`
  return (
    <Svg width={size} height={size * 180 / 320} viewBox="0 0 320 180">
      <Defs>
        <LinearGradient id="fng" x1="0" y1="0" x2="1" y2="0">
          <Stop offset="0" stopColor="#f6465d" /><Stop offset="0.35" stopColor="#ff9c32" /><Stop offset="0.53" stopColor="#f0d64f" />
          <Stop offset="0.75" stopColor="#32c88f" /><Stop offset="1" stopColor="#0ecb81" />
        </LinearGradient>
      </Defs>
      <Path d="M 24 155 A 136 136 0 0 1 296 155" fill="none" stroke="url(#fng)" strokeWidth={20} />
      <Polygon points={points} fill={c.muted} />
      <SvgText x="160" y="121" textAnchor="middle" fontSize="44" fontWeight="700" fill={c.ink}>{String(Math.round(s))}</SvgText>
      <SvgText x="160" y="151" textAnchor="middle" fontSize="18" fill={c.ink2}>{label}</SvgText>
    </Svg>
  )
}
