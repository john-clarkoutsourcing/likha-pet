export enum PetState {
  EGG = 'Egg',
  HATCHED = 'Hatched',
}

export type Rarity = 'Common' | 'Uncommon' | 'Rare' | 'Epic' | 'Legendary';

export interface DNAAttributes {
  color: string;
  rarity: Rarity;
  basePower: number;
  element: string;
  pattern: string;
}

export interface PetDTO {
  id: string;
  dna: string;
  state: PetState;
  hatchTime: number;
  owner: string;
  attributes: DNAAttributes;
  name: string;
  createdAt: number;
  hatchedAt?: number;
}
