import { View } from 'react-native'
import { LANGS, useI18n } from '@/lib/i18n'
import { useColors } from '@/lib/theme'
import { PRIVACY } from '@/web/privacy'
import { Icon, Screen, Txt } from '@/ui/kit'

// The website's privacy notice, same text in the app.
export default function Privacy() {
  const { lang } = useI18n()
  const c = useColors()
  const doc = PRIVACY[Math.max(0, LANGS.indexOf(lang))] ?? PRIVACY[0]
  return (
    <Screen>
      <View style={{ alignItems: 'center', gap: 8, paddingVertical: 10 }}>
        <Icon name="lock.shield.fill" size={56} color={c.gold} />
        <Txt v="title" center>{doc.title}</Txt>
        <Txt tone="gold" center>{doc.commitment}</Txt>
      </View>
      {doc.intro.map((p, i) => <Txt key={i} tone={i === 0 ? 'ink' : 'ink2'} v={i === 0 ? 'h2' : 'body'}>{p}</Txt>)}
      <Txt v="title">{doc.noticeTitle}</Txt>
      {doc.meta.map(m => <Txt key={m} v="small" tone="muted">{m}</Txt>)}
      {doc.sections.map(s => (
        <View key={s.h} style={{ gap: 6 }}>
          <Txt v="h2">{s.h}</Txt>
          {s.p?.map((p, i) => <Txt key={i} v="small" tone="ink2">{p}</Txt>)}
          {s.list?.map((li, i) => <Txt key={i} v="small" tone="ink2">•  {li}</Txt>)}
        </View>
      ))}
      <Txt v="tiny" tone="muted" center>© 2026 SKY Global · Skyline Exchange 天际交易所</Txt>
    </Screen>
  )
}
