import { expect, test } from '@jest/globals'
import { bjShuffle, crashPoint, hmacSha256, seedMatches, sha256, toHex, utf8 } from '../fair'

const SEED = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff'

test('sha256 matches the standard vectors', () => {
  expect(toHex(sha256(utf8('')))).toBe('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')
  expect(toHex(sha256(utf8('abc')))).toBe('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
  const long = 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'
  expect(toHex(sha256(utf8(long)))).toBe('248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1')
})

test('hmac-sha256 matches RFC 4231 case 2', () => {
  expect(toHex(hmacSha256(utf8('Jefe'), utf8('what do ya want for nothing?'))))
    .toBe('5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843')
})

test('crash points match the server (crash.go)', () => {
  expect([1, 2, 42, 1000].map(r => crashPoint(SEED, r))).toEqual([667, 107, 573, 868])
})

test('blackjack shoe matches the server (blackjack.go)', () => {
  const shoe = bjShuffle(SEED, 7)
  expect(shoe.slice(0, 12)).toEqual([19, 23, 7, 41, 27, 17, 14, 38, 36, 42, 46, 46])
  const count: Record<number, number> = {}
  shoe.forEach(c => { count[c] = (count[c] ?? 0) + 1 })
  expect(Object.values(count).every(n => n === 6)).toBe(true)
})

test('seed hash check', () => {
  expect(seedMatches(SEED, toHex(sha256(Uint8Array.from(SEED.match(/../g)!.map(b => parseInt(b, 16))))))).toBe(true)
  expect(seedMatches(SEED, '00')).toBe(false)
})
