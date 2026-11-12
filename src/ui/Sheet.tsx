import type { ReactNode } from 'react'
import { KeyboardAvoidingView, Modal, Platform, Pressable, ScrollView, StyleSheet, View } from 'react-native'
import { useColors } from '@/lib/theme'
import { Icon, Txt } from './kit'

/** Native iOS page sheet (swipe down to dismiss) with a title row. */
export function Sheet({ visible, title, onClose, children }: { visible: boolean; title: string; onClose: () => void; children: ReactNode }) {
  const c = useColors()
  return (
    <Modal visible={visible} animationType="slide" presentationStyle="pageSheet" onRequestClose={onClose} transparent={Platform.OS === 'web'}>
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={[styles.root, { backgroundColor: c.bg }]}>
        <View style={styles.head}>
          <Txt v="h2" style={{ flex: 1 }} lines={1}>{title}</Txt>
          <Pressable hitSlop={12} onPress={onClose} style={[styles.close, { backgroundColor: c.surface2 }]}>
            <Icon name="xmark" size={13} color={c.ink2} weight="bold" />
          </Pressable>
        </View>
        <ScrollView contentContainerStyle={styles.body} keyboardShouldPersistTaps="handled">{children}</ScrollView>
      </KeyboardAvoidingView>
    </Modal>
  )
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  head: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 20, paddingTop: 18, paddingBottom: 8 },
  close: { width: 30, height: 30, borderRadius: 15, alignItems: 'center', justifyContent: 'center' },
  body: { padding: 20, gap: 14, paddingBottom: 60 },
})
