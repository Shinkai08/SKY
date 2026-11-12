import { useI18n } from '@/lib/i18n'
import { TabStack } from '@/ui/TabStack'

export default function Layout() {
  const { t } = useI18n()
  return <TabStack title={t('app_tabAssets')} large={true} />
}
