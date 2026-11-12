import * as Haptics from 'expo-haptics'
import { Platform } from 'react-native'

const on = Platform.OS === 'ios' || Platform.OS === 'android'

export const tap = () => { if (on) Haptics.selectionAsync().catch(() => undefined) }
export const press = () => { if (on) Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => undefined) }
export const success = () => { if (on) Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => undefined) }
export const warn = () => { if (on) Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error).catch(() => undefined) }
