// Generates SKY/Generated/Lucide.swift from the website's lucide-react icons,
// so the app draws exactly the same strokes (24×24 grid, round caps/joins).
// Every SVG element is flattened to move / line / cubic / close commands
// (arcs are converted to cubics here, at build time).
//   node scripts/build-icons.mjs [path/to/apps/web]
import { readFileSync, writeFileSync, readdirSync, mkdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const web = process.argv[2] ?? 'D:/SKY/development/apps/web'
const dist = join(web, 'node_modules/lucide-react/dist/esm')

// Names the website imports, plus a few the app needs for native controls.
const extra = ['Minus', 'ChevronUp', 'Info', 'RefreshCw', 'Mail', 'KeyRound', 'CircleCheck', 'Share2', 'ExternalLink',
  'ImagePlus', 'Send', 'Smartphone', 'Languages', 'Palette', 'Vibrate', 'Trash', 'Shield', 'CircleUser', 'Ellipsis']
const used = new Set(extra)
const walk = dir => {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, e.name)
    if (e.isDirectory()) walk(p)
    else if (/\.tsx?$/.test(e.name)) {
      for (const m of readFileSync(p, 'utf8').matchAll(/import \{([^}]*)\} from 'lucide-react'/g)) {
        for (const raw of m[1].split(',')) {
          const name = raw.replace(/\s+as\s+\w+/, '').trim()
          if (name && !/^type\b/.test(name) && name !== 'LucideIcon') used.add(name)
        }
      }
    }
  }
}
walk(join(web, 'src'))

// Export name → icon file, from the package index.
const files = new Map()
for (const m of readFileSync(join(dist, 'lucide-react.js'), 'utf8').matchAll(/export \{([^}]*)\} from '\.\/icons\/([\w-]+)\.js'/g)) {
  for (const part of m[1].split(',')) {
    const name = part.trim().replace(/^default as /, '')
    files.set(name, m[2])
  }
}

function iconNode(file) {
  const src = readFileSync(join(dist, 'icons', file + '.js'), 'utf8')
  const body = src.slice(src.indexOf('createLucideIcon(') + 'createLucideIcon('.length)
  const arr = body.slice(body.indexOf('['), body.lastIndexOf(']') + 1)
  return Function(`return ${arr}`)()
}

// ---- SVG path → absolute M/L/C/Z ----
function tokenize(d) {
  const out = []
  const re = /([MmLlHhVvCcSsQqTtAaZz])|(-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)/g
  let m
  while ((m = re.exec(d))) out.push(m[1] ?? Number(m[2]))
  return out
}

function arcToCubics(x1, y1, rx, ry, phi, fa, fs, x2, y2) {
  // SVG implementation notes, F.6.5 / F.6.6
  if (rx === 0 || ry === 0) return [[x1, y1, x2, y2, x2, y2]]
  const rad = phi * Math.PI / 180, cos = Math.cos(rad), sin = Math.sin(rad)
  const dx = (x1 - x2) / 2, dy = (y1 - y2) / 2
  const x1p = cos * dx + sin * dy, y1p = -sin * dx + cos * dy
  rx = Math.abs(rx); ry = Math.abs(ry)
  const lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
  if (lambda > 1) { rx *= Math.sqrt(lambda); ry *= Math.sqrt(lambda) }
  const sign = fa === fs ? -1 : 1
  const num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
  const den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
  const coef = sign * Math.sqrt(Math.max(0, num / den))
  const cxp = coef * (rx * y1p / ry), cyp = coef * (-ry * x1p / rx)
  const cx = cos * cxp - sin * cyp + (x1 + x2) / 2, cy = sin * cxp + cos * cyp + (y1 + y2) / 2
  const ang = (ux, uy, vx, vy) => {
    const a = Math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
    return a
  }
  const t1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
  let dt = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
  if (!fs && dt > 0) dt -= 2 * Math.PI
  if (fs && dt < 0) dt += 2 * Math.PI
  const segs = Math.ceil(Math.abs(dt) / (Math.PI / 2))
  const delta = dt / segs, k = 4 / 3 * Math.tan(delta / 4)
  const out = []
  let a = t1
  const pt = th => {
    const x = rx * Math.cos(th), y = ry * Math.sin(th)
    return [cos * x - sin * y + cx, sin * x + cos * y + cy]
  }
  const der = th => {
    const x = -rx * Math.sin(th), y = ry * Math.cos(th)
    return [cos * x - sin * y, sin * x + cos * y]
  }
  for (let i = 0; i < segs; i++) {
    const b = a + delta
    const [p0x, p0y] = pt(a), [p3x, p3y] = pt(b), [d0x, d0y] = der(a), [d3x, d3y] = der(b)
    out.push([p0x + k * d0x, p0y + k * d0y, p3x - k * d3x, p3y - k * d3y, p3x, p3y])
    a = b
  }
  // land exactly on the end point
  out[out.length - 1][4] = x2; out[out.length - 1][5] = y2
  return out
}

function pathOps(d) {
  const t = tokenize(d), ops = []
  let i = 0, cmd = '', x = 0, y = 0, sx = 0, sy = 0, lcx = 0, lcy = 0, lqx = 0, lqy = 0, prev = ''
  const n = () => t[i++]
  while (i < t.length) {
    if (typeof t[i] === 'string') cmd = t[i++]
    else if (cmd === 'M') cmd = 'L'
    else if (cmd === 'm') cmd = 'l'
    const rel = cmd === cmd.toLowerCase(), C = cmd.toUpperCase()
    const ox = rel ? x : 0, oy = rel ? y : 0
    switch (C) {
      case 'M': x = ox + n(); y = oy + n(); sx = x; sy = y; ops.push(['M', x, y]); break
      case 'L': x = ox + n(); y = oy + n(); ops.push(['L', x, y]); break
      case 'H': x = ox + n(); ops.push(['L', x, y]); break
      case 'V': y = (rel ? y : 0) + n(); ops.push(['L', x, y]); break
      case 'C': {
        const c1x = ox + n(), c1y = oy + n(), c2x = ox + n(), c2y = oy + n(); x = ox + n(); y = oy + n()
        ops.push(['C', c1x, c1y, c2x, c2y, x, y]); lcx = c2x; lcy = c2y; break
      }
      case 'S': {
        const c1x = /[CS]/.test(prev) ? 2 * x - lcx : x, c1y = /[CS]/.test(prev) ? 2 * y - lcy : y
        const c2x = ox + n(), c2y = oy + n(); x = ox + n(); y = oy + n()
        ops.push(['C', c1x, c1y, c2x, c2y, x, y]); lcx = c2x; lcy = c2y; break
      }
      case 'Q': {
        const qx = ox + n(), qy = oy + n(), ex = ox + n(), ey = oy + n()
        ops.push(['C', x + 2 / 3 * (qx - x), y + 2 / 3 * (qy - y), ex + 2 / 3 * (qx - ex), ey + 2 / 3 * (qy - ey), ex, ey])
        lqx = qx; lqy = qy; x = ex; y = ey; break
      }
      case 'T': {
        const qx = /[QT]/.test(prev) ? 2 * x - lqx : x, qy = /[QT]/.test(prev) ? 2 * y - lqy : y
        const ex = ox + n(), ey = oy + n()
        ops.push(['C', x + 2 / 3 * (qx - x), y + 2 / 3 * (qy - y), ex + 2 / 3 * (qx - ex), ey + 2 / 3 * (qy - ey), ex, ey])
        lqx = qx; lqy = qy; x = ex; y = ey; break
      }
      case 'A': {
        const rx = n(), ry = n(), phi = n(), fa = n(), fs = n(), ex = ox + n(), ey = oy + n()
        for (const c of arcToCubics(x, y, rx, ry, phi, fa, fs, ex, ey)) ops.push(['C', ...c])
        x = ex; y = ey; break
      }
      case 'Z': ops.push(['Z']); x = sx; y = sy; break
      default: throw new Error('bad path command ' + cmd + ' in ' + d)
    }
    prev = C
  }
  return ops
}

const num = v => {
  const r = Math.round(v * 1000) / 1000
  return Number.isInteger(r) ? r.toFixed(0) : String(r)
}
const pt = (x, y) => `P(${num(x)}, ${num(y)})`

function swiftFor(node) {
  const lines = []
  for (const [tag, a] of node) {
    switch (tag) {
      case 'path':
        for (const op of pathOps(a.d)) {
          if (op[0] === 'M') lines.push(`p.move(to: ${pt(op[1], op[2])})`)
          else if (op[0] === 'L') lines.push(`p.addLine(to: ${pt(op[1], op[2])})`)
          else if (op[0] === 'C') lines.push(`p.addCurve(to: ${pt(op[5], op[6])}, control1: ${pt(op[1], op[2])}, control2: ${pt(op[3], op[4])})`)
          else lines.push('p.closeSubpath()')
        }
        break
      case 'circle':
        lines.push(`p.addEllipse(in: R(${num(+a.cx - +a.r)}, ${num(+a.cy - +a.r)}, ${num(2 * a.r)}, ${num(2 * a.r)}))`); break
      case 'ellipse':
        lines.push(`p.addEllipse(in: R(${num(+a.cx - +a.rx)}, ${num(+a.cy - +a.ry)}, ${num(2 * a.rx)}, ${num(2 * a.ry)}))`); break
      case 'rect': {
        const rx = +(a.rx ?? a.ry ?? 0), ry = +(a.ry ?? a.rx ?? 0)
        const r = `R(${num(+(a.x ?? 0))}, ${num(+(a.y ?? 0))}, ${num(+a.width)}, ${num(+a.height)})`
        lines.push(rx || ry ? `p.addRoundedRect(in: ${r}, cornerSize: CGSize(width: ${num(rx)}, height: ${num(ry)}))` : `p.addRect(${r})`)
        break
      }
      case 'line':
        lines.push(`p.move(to: ${pt(+a.x1, +a.y1)})`, `p.addLine(to: ${pt(+a.x2, +a.y2)})`); break
      case 'polyline': case 'polygon': {
        const v = a.points.trim().split(/[\s,]+/).map(Number)
        lines.push(`p.move(to: ${pt(v[0], v[1])})`)
        for (let k = 2; k < v.length; k += 2) lines.push(`p.addLine(to: ${pt(v[k], v[k + 1])})`)
        if (tag === 'polygon') lines.push('p.closeSubpath()')
        break
      }
      default: throw new Error('unsupported element ' + tag)
    }
  }
  return lines
}

const caseName = name => name[0].toLowerCase() + name.slice(1)
const names = [...used].filter(n => {
  if (!files.has(n)) { console.warn('skip (not in lucide-react):', n); return false }
  return true
}).sort()

let out = `// Generated by scripts/build-icons.mjs from lucide-react (ISC licence). Do not edit.
import SwiftUI

enum Lucide: String, CaseIterable {
${names.map(n => `    case ${caseName(n)}`).join('\n')}
}

private func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
private func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x, y: y, width: w, height: h) }

extension Lucide {
    /// The icon in its 24×24 design grid.
    var path: Path {
        switch self {
${names.map(n => `        case .${caseName(n)}: return Self.${caseName(n)}Path`).join('\n')}
        }
    }
}

extension Lucide {
`
for (const n of names) {
  const body = swiftFor(iconNode(files.get(n)))
  out += `    static let ${caseName(n)}Path: Path = {\n        var p = Path()\n${body.map(l => '        ' + l).join('\n')}\n        return p\n    }()\n`
}
out += '}\n'

// SVG preview of the flattened paths, to compare with the originals in a browser.
let preview = '<html><body style="background:#111;color:#ddd;font:12px sans-serif;display:flex;flex-wrap:wrap;gap:8px">'
for (const n of names) {
  const node = iconNode(files.get(n))
  const orig = node.map(([tag, a]) => `<${tag} ${Object.entries(a).filter(([k]) => k !== 'key').map(([k, v]) => `${k}="${v}"`).join(' ')}/>`).join('')
  const flat = swiftFor(node).join(';').length
  let d = ''
  for (const [tag, a] of node) if (tag === 'path') for (const op of pathOps(a.d)) d += op[0] === 'Z' ? 'Z' : `${op[0]}${op.slice(1).map(num).join(' ')}`
  preview += `<div style="width:110px;text-align:center"><svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#e8c878" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${orig}</svg><svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#6cf" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${node.filter(([t]) => t !== 'path').map(([tag, a]) => `<${tag} ${Object.entries(a).filter(([k]) => k !== 'key').map(([k, v]) => `${k}="${v}"`).join(' ')}/>`).join('')}<path d="${d}"/></svg><br>${n} ${flat}</div>`
}
preview += '</body></html>'

mkdirSync(join(root, 'SKY/Generated'), { recursive: true })
writeFileSync(join(root, 'SKY/Generated/Lucide.swift'), out)
writeFileSync(join(root, 'scripts/icons-preview.html'), preview)
console.log(`${names.length} icons → SKY/Generated/Lucide.swift`)
