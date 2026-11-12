import { Image } from 'expo-image'
import { Text, View } from 'react-native'
import { siteUrl } from '@/config'
import { useColors } from '@/lib/theme'

export type AvatarInfo = { nick?: string; avatar?: string; frame?: string; photo?: string }

const FRAMES: Record<string, number> = {
  orbit: require('@/assets/frames/orbit.webp'), frost: require('@/assets/frames/frost.webp'), jade: require('@/assets/frames/jade.webp'),
  noir: require('@/assets/frames/noir.webp'), crown: require('@/assets/frames/crown.png'),
}

/** Uploaded photo, else emoji, else first letter; with the chosen frame ring. */
export function Avatar({ a, size = 40 }: { a?: AvatarInfo; size?: number }) {
  const c = useColors()
  const nick = a?.nick ?? '?'
  const frame = a?.frame && FRAMES[a.frame] ? a.frame : ''
  const face = frame ? size * (frame === 'crown' ? 0.65 : 0.69) : size
  const photo = a?.photo?.startsWith('/api/v1/avatars/') ? siteUrl(a.photo) : ''
  const inner = photo
    ? <Image source={{ uri: photo }} style={{ width: face, height: face, borderRadius: face / 2 }} />
    : (
      <View style={{ width: face, height: face, borderRadius: face / 2, backgroundColor: a?.avatar ? c.surface2 : c.goldLo, alignItems: 'center', justifyContent: 'center' }}>
        <Text style={{ fontSize: a?.avatar ? face * 0.56 : face * 0.42, color: '#fff', fontWeight: '700' }}>{a?.avatar || [...nick][0]?.toUpperCase()}</Text>
      </View>
    )
  if (!frame) return inner
  return (
    <View style={{ width: size, height: size, alignItems: 'center', justifyContent: 'center' }}>
      {inner}
      <Image source={FRAMES[frame]} style={{ position: 'absolute', width: size, height: size }} contentFit="contain" />
    </View>
  )
}
