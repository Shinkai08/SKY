import NativeSegmented from '@react-native-segmented-control/segmented-control'
import { SymbolView, type SFSymbol } from 'expo-symbols'
import type { ReactNode } from 'react'
import {
  ActivityIndicator, Platform, Pressable, RefreshControl, ScrollView, StyleSheet, Text, TextInput, View,
  type StyleProp, type TextInputProps, type TextStyle, type ViewStyle,
} from 'react-native'
import { press, tap } from '@/lib/haptics'
import { radius, useColors, type Palette } from '@/lib/theme'

// SKY's small iOS-styled kit: text, cards, buttons, fields, segmented
// controls and SF Symbols, all reading the platinum palette.

// The library ships class typings that predate React 19's JSX types.
const SegmentedControl = NativeSegmented as unknown as React.ComponentType<{
  values: string[]; selectedIndex: number; appearance?: 'dark' | 'light'; style?: StyleProp<ViewStyle>
  onChange: (e: { nativeEvent: { selectedSegmentIndex: number } }) => void
}>

type Tone = 'ink' | 'ink2' | 'muted' | 'gold' | 'up' | 'down' | 'onGold'
const toneColor = (c: Palette, t: Tone) => (t === 'onGold' ? c.onGold : c[t])

const sizes = {
  hero: { fontSize: 34, fontWeight: '700' as const, letterSpacing: 0.3 },
  title: { fontSize: 22, fontWeight: '700' as const },
  h2: { fontSize: 17, fontWeight: '600' as const },
  body: { fontSize: 15 },
  small: { fontSize: 13 },
  tiny: { fontSize: 11 },
}

export function Txt({ children, v = 'body', tone = 'ink', num, bold, center, style, lines, selectable }: {
  children?: ReactNode; v?: keyof typeof sizes; tone?: Tone; num?: boolean; bold?: boolean; center?: boolean
  style?: StyleProp<TextStyle>; lines?: number; selectable?: boolean
}) {
  const c = useColors()
  return (
    <Text numberOfLines={lines} selectable={selectable} style={[sizes[v], { color: toneColor(c, tone) }, num && styles.num, bold && { fontWeight: '700' }, center && { textAlign: 'center' }, style]}>
      {children}
    </Text>
  )
}

export function Icon({ name, size = 20, color, weight }: { name: SFSymbol; size?: number; color?: string; weight?: 'regular' | 'medium' | 'semibold' | 'bold' }) {
  const c = useColors()
  return <SymbolView name={name} size={size} tintColor={color ?? c.ink} weight={weight} fallback={<View style={{ width: size, height: size }} />} />
}

export function Card({ children, style, onPress }: { children: ReactNode; style?: StyleProp<ViewStyle>; onPress?: () => void }) {
  const c = useColors()
  const box = [styles.card, { backgroundColor: c.surface, borderColor: c.line }, style]
  if (!onPress) return <View style={box}>{children}</View>
  return <Pressable onPress={() => { tap(); onPress() }} style={({ pressed }) => [box, pressed && { opacity: 0.75 }]}>{children}</Pressable>
}

export function Btn({ title, onPress, kind = 'primary', disabled, busy, small, style, icon }: {
  title: ReactNode; onPress: () => void; kind?: 'primary' | 'secondary' | 'up' | 'down' | 'ghost' | 'danger'
  disabled?: boolean; busy?: boolean; small?: boolean; style?: StyleProp<ViewStyle>; icon?: SFSymbol
}) {
  const c = useColors()
  const bg = { primary: c.gold, secondary: c.surface2, up: c.up, down: c.down, ghost: 'transparent', danger: c.redTint }[kind]
  const fg = { primary: c.onGold, secondary: c.ink, up: '#fff', down: '#fff', ghost: c.gold, danger: c.red }[kind]
  return (
    <Pressable disabled={disabled || busy} onPress={() => { press(); onPress() }}
      style={({ pressed }) => [styles.btn, small && styles.btnSmall, { backgroundColor: bg, opacity: disabled ? 0.4 : pressed ? 0.8 : 1 },
        kind === 'ghost' && { borderWidth: 1, borderColor: c.line }, style]}>
      {busy ? <ActivityIndicator color={fg} /> : (
        <View style={styles.row}>
          {icon && <Icon name={icon} size={small ? 14 : 17} color={fg} weight="semibold" />}
          {typeof title === 'string' ? <Text style={[styles.btnText, small && { fontSize: 14 }, { color: fg }]}>{title}</Text> : title}
        </View>
      )}
    </Pressable>
  )
}

export function Field({ label, suffix, style, ...props }: TextInputProps & { label?: string; suffix?: string; style?: StyleProp<ViewStyle> }) {
  const c = useColors()
  return (
    <View style={[styles.field, { backgroundColor: c.surface2 }, style]}>
      {label && <Text style={[styles.fieldLabel, { color: c.ink2 }]}>{label}</Text>}
      <TextInput placeholderTextColor={c.muted} selectionColor={c.gold} {...props}
        style={[styles.fieldInput, { color: c.ink }, !label && { textAlign: 'left' }]} />
      {suffix && <Text style={{ color: c.muted, fontSize: 13 }}>{suffix}</Text>}
    </View>
  )
}

export function Seg<T extends string>({ items, value, onChange, style }: {
  items: { id: T; label: string }[]; value: T; onChange: (v: T) => void; style?: StyleProp<ViewStyle>
}) {
  const c = useColors()
  return (
    <SegmentedControl style={[{ height: 34 }, style]} values={items.map(i => i.label)} selectedIndex={Math.max(0, items.findIndex(i => i.id === value))}
      appearance={c.dark ? 'dark' : 'light'} onChange={e => { tap(); onChange(items[e.nativeEvent.selectedSegmentIndex].id) }} />
  )
}

/** Underlined text tabs (like the website's tab rows). */
export function Tabs<T extends string>({ items, value, onChange, style }: {
  items: { id: T; label: string }[]; value: T; onChange: (v: T) => void; style?: StyleProp<ViewStyle>
}) {
  const c = useColors()
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={[{ gap: 18, paddingHorizontal: 16 }, style]}>
      {items.map(i => (
        <Pressable key={i.id} onPress={() => { tap(); onChange(i.id) }} style={styles.tab}>
          <Text style={{ fontSize: 16, fontWeight: i.id === value ? '700' : '500', color: i.id === value ? c.ink : c.muted }}>{i.label}</Text>
          <View style={[styles.tabBar, { backgroundColor: i.id === value ? c.gold : 'transparent' }]} />
        </Pressable>
      ))}
    </ScrollView>
  )
}

export function Chg({ v, digits = 2, pill }: { v: number; digits?: number; pill?: boolean }) {
  const c = useColors()
  const up = v >= 0
  const text = `${up ? '+' : '−'}${Math.abs(v).toFixed(digits)}%`
  if (!pill) return <Text style={[styles.num, { color: up ? c.up : c.down, fontSize: 13 }]}>{text}</Text>
  return (
    <View style={[styles.pill, { backgroundColor: up ? c.up : c.down }]}>
      <Text style={[styles.num, { color: '#fff', fontWeight: '600', fontSize: 13 }]}>{text}</Text>
    </View>
  )
}

/** A scrolling screen body with iOS large-title insets and optional pull-to-refresh. */
export function Screen({ children, refreshing, onRefresh, style, pad = true }: {
  children: ReactNode; refreshing?: boolean; onRefresh?: () => void; style?: StyleProp<ViewStyle>; pad?: boolean
}) {
  const c = useColors()
  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" style={{ flex: 1, backgroundColor: c.bg }}
      contentContainerStyle={[pad && { padding: 16, gap: 14 }, { paddingBottom: 40 }, style]} keyboardShouldPersistTaps="handled"
      refreshControl={onRefresh ? <RefreshControl refreshing={!!refreshing} onRefresh={onRefresh} tintColor={c.gold} /> : undefined}>
      {children}
    </ScrollView>
  )
}

export function Row({ children, style, gap = 8 }: { children: ReactNode; style?: StyleProp<ViewStyle>; gap?: number }) {
  return <View style={[styles.row, { gap }, style]}>{children}</View>
}

export function Sep() {
  const c = useColors()
  return <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: c.line }} />
}

/** iOS settings-style list row. */
export function ListRow({ icon, label, value, onPress, danger, last }: {
  icon?: SFSymbol; label: string; value?: ReactNode; onPress?: () => void; danger?: boolean; last?: boolean
}) {
  const c = useColors()
  return (
    <Pressable disabled={!onPress} onPress={() => { tap(); onPress?.() }} style={({ pressed }) => [styles.listRow, pressed && { backgroundColor: c.hover }]}>
      {icon && <View style={[styles.listIcon, { backgroundColor: c.surface2 }]}><Icon name={icon} size={16} color={danger ? c.red : c.gold} /></View>}
      <View style={[styles.listBody, !last && { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: c.line }]}>
        <Text style={{ flex: 1, fontSize: 16, color: danger ? c.red : c.ink }}>{label}</Text>
        {typeof value === 'string' ? <Text style={{ color: c.muted, fontSize: 15 }}>{value}</Text> : value}
        {onPress && <Icon name="chevron.right" size={13} color={c.muted} />}
      </View>
    </Pressable>
  )
}

export function Group({ children, title }: { children: ReactNode; title?: string }) {
  const c = useColors()
  return (
    <View style={{ gap: 6 }}>
      {title && <Text style={{ color: c.muted, fontSize: 13, marginLeft: 16, textTransform: 'uppercase' }}>{title}</Text>}
      <View style={[styles.group, { backgroundColor: c.surface }]}>{children}</View>
    </View>
  )
}

export function Empty({ text, icon = 'tray' }: { text: string; icon?: SFSymbol }) {
  const c = useColors()
  return (
    <View style={styles.empty}>
      <Icon name={icon} size={30} color={c.muted} />
      <Text style={{ color: c.muted, fontSize: 14 }}>{text}</Text>
    </View>
  )
}

export function Loading() {
  const c = useColors()
  return <View style={styles.empty}><ActivityIndicator color={c.gold} /></View>
}

const styles = StyleSheet.create({
  num: { fontVariant: ['tabular-nums'] },
  row: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  card: { borderRadius: radius.l, padding: 16, borderWidth: StyleSheet.hairlineWidth, gap: 10 },
  btn: { height: 50, borderRadius: radius.m, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 16 },
  btnSmall: { height: 36, borderRadius: 10, paddingHorizontal: 12 },
  btnText: { fontSize: 16, fontWeight: '700' },
  field: { flexDirection: 'row', alignItems: 'center', gap: 10, minWidth: 0, minHeight: 48, borderRadius: radius.m, paddingHorizontal: 14 },
  fieldLabel: { fontSize: 14 },
  fieldInput: { flex: 1, minWidth: 0, fontSize: 17, fontWeight: '600', textAlign: 'right', paddingVertical: Platform.OS === 'web' ? 12 : 10, fontVariant: ['tabular-nums'] },
  tab: { paddingTop: 6, alignItems: 'center', gap: 6 },
  tabBar: { height: 3, width: 18, borderRadius: 2 },
  pill: { minWidth: 76, paddingHorizontal: 8, paddingVertical: 6, borderRadius: 7, alignItems: 'center' },
  listRow: { flexDirection: 'row', alignItems: 'center', paddingLeft: 14, gap: 12 },
  listIcon: { width: 30, height: 30, borderRadius: 8, alignItems: 'center', justifyContent: 'center' },
  listBody: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: 8, minHeight: 50, paddingRight: 14 },
  group: { borderRadius: radius.m, overflow: 'hidden' },
  empty: { alignItems: 'center', justifyContent: 'center', gap: 10, paddingVertical: 40 },
})
