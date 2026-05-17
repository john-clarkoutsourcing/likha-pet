export type ResolvedCardEffect = {
  traitId: string;
  cardId?: string;
  effectType: string;
  effectValue: number;
  target: string;
  buffType?: string;
  debuffType?: string;
  duration?: number;
  selfShield: number;
  lifeSteal: boolean;
  energySteal: boolean;
  energyDrain: boolean;
};

const SPECIAL_CARD_EFFECTS: Record<string, Partial<ResolvedCardEffect>> = {
  'plant-mouth-02': {
    effectType: 'damage',
    target: 'enemy',
    energySteal: true,
  },
  'plant-mouth-04': {
    effectType: 'damage',
    target: 'enemy',
    lifeSteal: true,
  },
  'aquatic-mouth-04': {
    effectType: 'damage',
    target: 'enemy',
    lifeSteal: true,
  },
  'bug-mouth-02': {
    effectType: 'damage',
    target: 'enemy',
    lifeSteal: true,
  },
  'beast-mouth-04': {
    effectType: 'damage',
    target: 'enemy',
    energyDrain: true,
  },
  'bug-horn-04': {
    effectType: 'damage',
    target: 'back_enemy',
    energySteal: true,
  },
  'bird-horn-04': {
    effectType: 'buff',
    target: 'self',
    buffType: 'attackUp',
    duration: 1,
  },
  'plant-horn-06': {
    effectType: 'buff',
    target: 'self',
    buffType: 'defenseUp',
    duration: 1,
  },
  'plant-back-06': {
    effectType: 'debuff',
    target: 'self',
    debuffType: 'poisoned',
    duration: 1,
  },
  'bird-tail-04': {
    effectType: 'damage',
    target: 'enemy',
  },
};

export function resolveCardId(traitId: string): string | null {
  const explicit: Record<string, string> = {
    beast_horn: 'beast-horn-04',
    beast_back: 'beast-back-04',
    beast_tail: 'beast-tail-04',
    beast_mouth: 'beast-mouth-04',
    plant_horn: 'plant-horn-04',
    plant_back: 'plant-back-04',
    plant_tail: 'plant-tail-04',
    plant_mouth: 'plant-mouth-04',
    plant_mouth_vegetal_bite: 'plant-mouth-02',
    plant_mouth_02: 'plant-mouth-02',
    aquatic_horn: 'aquatic-horn-04',
    aquatic_back: 'aquatic-back-04',
    aquatic_tail: 'aquatic-tail-04',
    aquatic_mouth: 'aquatic-mouth-04',
    bird_horn: 'bird-horn-04',
    bird_back: 'bird-back-04',
    bird_tail: 'bird-tail-04',
    bird_mouth: 'bird-mouth-04',
    bug_horn: 'bug-horn-04',
    bug_back: 'bug-back-04',
    bug_tail: 'bug-tail-04',
    bug_mouth: 'bug-mouth-04',
    bug_mouth_blood_taste: 'bug-mouth-02',
    bug_mouth_02: 'bug-mouth-02',
    reptile_horn: 'reptile-horn-04',
    reptile_back: 'reptile-back-04',
    reptile_tail: 'reptile-tail-04',
    reptile_mouth: 'reptile-mouth-04',
    beast_horn_2: 'beast-horn-06',
    beast_back_2: 'beast-back-06',
    plant_horn_2: 'plant-horn-06',
    plant_back_2: 'plant-back-06',
    aquatic_horn_2: 'aquatic-horn-06',
    aquatic_back_2: 'aquatic-back-06',
    bird_horn_2: 'bird-horn-06',
    bird_back_2: 'bird-back-06',
    bug_horn_2: 'bug-horn-06',
    bug_back_2: 'bug-back-06',
    reptile_horn_2: 'reptile-horn-06',
    reptile_back_2: 'reptile-back-06',
  };

  const mapped = explicit[traitId];
  if (mapped) return mapped;

  const variant = traitId.match(/^(beast|bug|bird|plant|aquatic|reptile)_(horn|back|tail|mouth)(?:_(\d+))?$/);
  if (!variant) return null;
  const [, cls, part, suffix] = variant;
  const variantId = suffix === '2' ? '06' : '04';
  return `${cls}-${part}-${variantId}`;
}

export function resolveCardEffect(
  traitId: string,
  fallback?: Partial<ResolvedCardEffect>,
): ResolvedCardEffect {
  const cardId = resolveCardId(traitId);
  const special = cardId ? SPECIAL_CARD_EFFECTS[cardId] : undefined;

  const resolved: ResolvedCardEffect = {
    traitId,
    cardId: cardId ?? undefined,
    effectType: fallback?.effectType ?? special?.effectType ?? 'damage',
    effectValue: fallback?.effectValue ?? 0,
    target: fallback?.target ?? special?.target ?? 'enemy',
    buffType: fallback?.buffType ?? special?.buffType,
    debuffType: fallback?.debuffType ?? special?.debuffType,
    duration: fallback?.duration ?? special?.duration ?? 0,
    selfShield: fallback?.selfShield ?? special?.selfShield ?? 0,
    lifeSteal: fallback?.lifeSteal ?? special?.lifeSteal ?? false,
    energySteal: fallback?.energySteal ?? special?.energySteal ?? false,
    energyDrain: fallback?.energyDrain ?? special?.energyDrain ?? false,
  };

  return resolved;
}
