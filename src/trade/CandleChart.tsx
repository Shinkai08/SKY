import { useMemo } from 'react'
import { View } from 'react-native'
import Svg, { G, Line, Rect, Text as SvgText } from 'react-native-svg'
import { useColors } from '@/lib/theme'
import type { Candle } from '@/web/data'
import { useWidth } from '@/ui/charts'

/**
 * Candlestick chart with volume bars and a last-price line. Fits the latest
 * candles to the width (≈ 7 px each), price axis on the right.
 */
export function CandleChart({ data, height = 300, digits = 2 }: { data: Candle[]; height?: number; digits?: number }) {
  const c = useColors()
  const [w, onLayout] = useWidth()
  const axis = 58
  const plotW = Math.max(0, w - axis)
  const n = Math.max(10, Math.floor(plotW / 7))
  const shown = useMemo(() => data.slice(-n), [data, n])
  const volH = height * 0.18
  const priceH = height - volH - 16
  if (!shown.length || !w) return <View style={{ height }} onLayout={onLayout} />
  const hi = Math.max(...shown.map(k => k.h)), lo = Math.min(...shown.map(k => k.l))
  const span = hi - lo || hi * 0.01 || 1
  const top = hi + span * 0.06, bot = lo - span * 0.06
  const y = (p: number) => ((top - p) / (top - bot)) * priceH
  const vmax = Math.max(...shown.map(k => k.v), 1e-12)
  const cw = plotW / shown.length
  const body = Math.max(1, cw * 0.62)
  const last = shown[shown.length - 1].c
  const lastUp = last >= shown[shown.length - 1].o
  const ticks = [0, 0.25, 0.5, 0.75, 1].map(f => top - (top - bot) * f)
  return (
    <View style={{ height }} onLayout={onLayout}>
      <Svg width={w} height={height}>
        {ticks.map((p, i) => (
          <Line key={i} x1={0} x2={plotW} y1={y(p)} y2={y(p)} stroke={c.line} strokeWidth={0.5} />
        ))}
        {ticks.map((p, i) => (
          <SvgText key={'t' + i} x={w - 4} y={y(p) + 4} fontSize={10} fill={c.muted} textAnchor="end">{p.toFixed(digits)}</SvgText>
        ))}
        {shown.map((k, i) => {
          const x = i * cw + cw / 2
          const up = k.c >= k.o
          const col = up ? c.up : c.down
          const yo = y(k.o), yc = y(k.c)
          return (
            <G key={i}>
              <Line x1={x} x2={x} y1={y(k.h)} y2={y(k.l)} stroke={col} strokeWidth={1} />
              <Rect x={x - body / 2} y={Math.min(yo, yc)} width={body} height={Math.max(1, Math.abs(yc - yo))} fill={col} />
              <Rect x={x - body / 2} y={height - (k.v / vmax) * volH} width={body} height={(k.v / vmax) * volH} fill={col} opacity={0.35} />
            </G>
          )
        })}
        <Line x1={0} x2={plotW} y1={y(last)} y2={y(last)} stroke={lastUp ? c.up : c.down} strokeWidth={0.8} strokeDasharray="3,3" />
        <Rect x={plotW + 2} y={y(last) - 8} width={axis - 4} height={16} rx={3} fill={lastUp ? c.up : c.down} />
        <SvgText x={w - 4} y={y(last) + 4} fontSize={10} fill="#fff" textAnchor="end" fontWeight="bold">{last.toFixed(digits)}</SvgText>
      </Svg>
    </View>
  )
}
