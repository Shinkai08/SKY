import { router, useLocalSearchParams } from 'expo-router'
import { useMemo, useState } from 'react'
import { FlatList, Pressable, ScrollView, StyleSheet, TextInput, View } from 'react-native'
import { tap } from '@/lib/haptics'
import { useI18n } from '@/lib/i18n'
import { usePriceFmt } from '@/lib/nav'
import { stars, tradeTarget } from '@/lib/prefs'
import { useColors } from '@/lib/theme'
import { useAllCatalog, useCatalog, type Category } from '@/web/market/catalog'
import { Chg, Empty, Icon, Row, Txt } from '@/ui/kit'
import { MarketIcon } from '@/ui/MarketIcon'

// Pair switcher sheet for the Trade tab: search, category chips, favourites.
export default function Pair() {
  const { spot: spotParam } = useLocalSearchParams<{ spot?: string }>()
  const spot = spotParam === '1'
  const { t } = useI18n()
  const c = useColors()
  const fmt = usePriceFmt()
  const starred = stars.useValue()
  const current = tradeTarget.useValue()
  const [cat, setCat] = useState<Category | 'fav'>('crypto')
  const [q, setQ] = useState('')
  const one = useCatalog(cat === 'fav' ? 'crypto' : cat, cat !== 'fav')
  const all = useAllCatalog(cat === 'fav')
  const items = cat === 'fav' ? all.items : one.items
  const rows = useMemo(() => {
    const qq = q.trim().toLowerCase()
    return items.filter(x => (spot ? x.spot : x.tradable) && (cat !== 'fav' || starred.includes(x.sym)) &&
      (!qq || x.base.toLowerCase().includes(qq) || (x.name ?? '').toLowerCase().includes(qq))).slice(0, 200)
  }, [items, q, cat, starred, spot])
  const tabs: { id: Category | 'fav'; label: string }[] = [
    { id: 'fav', label: '★' }, { id: 'crypto', label: t('crypto') }, { id: 'tradfi', label: t('tradfi') },
    { id: 'commodities', label: t('commodities') }, ...(spot ? [] : [{ id: 'onchain' as const, label: t('onchain') }]),
  ]
  const pick = (sym: string) => { tap(); tradeTarget.set({ sym, spot }); router.back() }
  return (
    <View style={{ flex: 1, backgroundColor: c.bg, paddingTop: 16 }}>
      <View style={[styles.search, { backgroundColor: c.surface2 }]}>
        <Icon name="magnifyingglass" size={15} color={c.muted} />
        <TextInput value={q} onChangeText={setQ} placeholder={t('search')} placeholderTextColor={c.muted} autoCapitalize="characters" autoCorrect={false}
          style={{ flex: 1, color: c.ink, fontSize: 16 }} selectionColor={c.gold} />
      </View>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ flexGrow: 0 }} contentContainerStyle={styles.chips}>
        {tabs.map(x => (
          <Pressable key={x.id} onPress={() => { tap(); setCat(x.id) }} style={[styles.chip, { backgroundColor: cat === x.id ? c.gold : c.surface2 }]}>
            <Txt v="small" bold tone={cat === x.id ? 'onGold' : 'ink2'}>{x.label}</Txt>
          </Pressable>
        ))}
      </ScrollView>
      <FlatList data={rows} keyExtractor={x => x.sym} keyboardShouldPersistTaps="handled"
        ListEmptyComponent={<Empty text={t('noData')} />}
        renderItem={({ item: x }) => (
          <Pressable onPress={() => pick(x.sym)} style={({ pressed }) => [styles.row, (pressed || (x.sym === current.sym && spot === current.spot)) && { backgroundColor: c.hover }]}>
            {starred.includes(x.sym) && <Icon name="star.fill" size={11} color={c.gold} />}
            <MarketIcon it={x} size={24} />
            <View style={{ flex: 1, minWidth: 0 }}>
              <Txt bold lines={1}>{x.base}<Txt v="tiny" tone="muted"> {x.chain ?? (spot ? '/USDT' : 'USDT')}</Txt></Txt>
            </View>
            <Txt num>{fmt(x.price)}</Txt>
            <View style={{ width: 70, alignItems: 'flex-end' }}><Chg v={x.chg} /></View>
          </Pressable>
        )} />
    </View>
  )
}

const styles = StyleSheet.create({
  search: { flexDirection: 'row', alignItems: 'center', gap: 8, height: 40, borderRadius: 10, paddingHorizontal: 12, marginHorizontal: 16 },
  chips: { gap: 8, paddingHorizontal: 16, paddingVertical: 12 },
  chip: { height: 30, paddingHorizontal: 14, borderRadius: 15, justifyContent: 'center' },
  row: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 16, height: 52 },
})
