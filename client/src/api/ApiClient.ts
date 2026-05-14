export type PetState = 'Egg' | 'Hatched';
export type Rarity = 'Common' | 'Uncommon' | 'Rare' | 'Epic' | 'Legendary';

export interface PetData {
  id: string;
  dna: string;
  state: PetState;
  hatchTime: number;
  owner: string;
  attributes: {
    color: string;
    rarity: Rarity;
    basePower: number;
    element: string;
    pattern: string;
  };
  name: string;
  createdAt: number;
  hatchedAt?: number;
}

const BASE_URL = '/api';

async function request<T>(url: string, options?: RequestInit): Promise<T> {
  const res = await fetch(url, options);
  const body = await res.json();
  if (!res.ok) throw new Error(body.error ?? `HTTP ${res.status}`);
  return body as T;
}

export const ApiClient = {
  spawnEgg: (owner: string) =>
    request<PetData>(`${BASE_URL}/spawn-egg`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ owner }),
    }),

  getInventory: (owner: string) =>
    request<PetData[]>(`${BASE_URL}/inventory?owner=${encodeURIComponent(owner)}`),

  hatchEgg: (id: string, owner: string) =>
    request<PetData>(`${BASE_URL}/hatch/${id}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ owner }),
    }),
};
