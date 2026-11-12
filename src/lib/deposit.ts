import { useEffect, useState } from 'react'
import { api } from './api'

export type DepAsset = { symbol: string; name: string; chains: string[]; minDeposit: number }
export type DepChain = { id: string; name: string; network: string; kind: string; confirmations: number }
export type DepMeta = { assets: DepAsset[]; chains: Record<string, DepChain>; live: boolean; simulate: boolean }
export type Deposit = {
  id: number; userId: number; email: string; asset: string; chain: string; amount: number; address: string; txHash: string
  confirmations: number; required: number; status: 'confirming' | 'credited'; priceUsdt: number; creditUsdt: number
  simulated: boolean; created: string
}

export function useDepositMeta() {
  const [meta, setMeta] = useState<DepMeta>()
  useEffect(() => { api<DepMeta>('/deposit/assets').then(setMeta).catch(() => undefined) }, [])
  return meta
}
