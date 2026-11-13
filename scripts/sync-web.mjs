// Copies what the app shares with the website (D:\SKY\development\apps\web):
//   strings (design/locales.json + i18n-extra.ts) → SKY/Resources/strings.json
//   privacy notice (privacy.ts)                   → SKY/Resources/privacy.json
//   images from public/                           → SKY/Resources/Web/…
//   node scripts/sync-web.mjs [path/to/apps/web]
import { readFileSync, writeFileSync, mkdirSync, copyFileSync, readdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { createRequire } from 'node:module'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const web = process.argv[2] ?? 'D:/SKY/development/apps/web'
const res = join(root, 'SKY/Resources')
mkdirSync(res, { recursive: true })

const esbuild = createRequire(join(web, 'package.json'))('esbuild')
async function loadTs(file) {
  const { code } = await esbuild.transform(readFileSync(file, 'utf8'), { loader: 'ts', format: 'esm' })
  const tmp = join(root, 'scripts', '.tmp-' + file.replace(/\W+/g, '_') + '.mjs')
  writeFileSync(tmp, code)
  return import(pathToFileURL(tmp).href + '?' + Date.now())
}

const locales = JSON.parse(readFileSync(join(web, 'src/design/locales.json'), 'utf8'))
const { EXTRA } = await loadTs(join(web, 'src/i18n-extra.ts'))
const strings = { ...locales.strings, ...EXTRA }
writeFileSync(join(res, 'strings.json'), JSON.stringify({ langs: locales.locales, strings }))
console.log(`strings: ${Object.keys(strings).length} keys`)

const { PRIVACY } = await loadTs(join(web, 'src/privacy.ts'))
writeFileSync(join(res, 'privacy.json'), JSON.stringify(PRIVACY))
console.log('privacy: ok')

// Images the app shows (same files as the website).
const images = [
  'logo.png', 'logo-full.jpg', 'sky-launch-logo.jpg', 'brand/sky-logo.webp',
  'vip-cards/bronze.webp', 'vip-cards/silver.webp', 'vip-cards/gold.webp', 'vip-cards/platinum.webp', 'vip-cards/blackgold.webp', 'vip-cards/emblem.png',
  'avatar-frames/orbit.webp', 'avatar-frames/frost.webp', 'avatar-frames/jade.webp', 'avatar-frames/noir.webp', 'avatar-frames/crown.png',
  ...readdirSync(join(web, 'public/share-posters')).filter(f => f.endsWith('.webp')).map(f => 'share-posters/' + f),
]
for (const rel of images) {
  const to = join(res, 'Web', rel.replace(/\//g, '-'))
  mkdirSync(dirname(to), { recursive: true })
  copyFileSync(join(web, 'public', rel), to)
}
console.log(`images: ${images.length}`)
