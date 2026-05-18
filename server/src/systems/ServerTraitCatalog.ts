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
  tags: string[];
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
  'aquatic-back-04': {
    tags: ['draw_if_attack_idle_target'],
  },
  'aquatic-back-08': {
    tags: ['on_shield_break_attack_up'],
  },
  'aquatic-horn-10': {
    tags: ['end_last_stand'],
  },
  'aquatic-horn-12': {
    tags: ['prevent_last_stand'],
  },
  'aquatic-tail-06': {
    effectType: 'debuff',
    target: 'enemy',
    debuffType: 'jinx',
    duration: 4,
  },
  'aquatic-tail-08': {
    effectType: 'debuff',
    target: 'enemy',
    debuffType: 'chill',
    duration: 4,
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
    target: 'all_allies',
    buffType: 'attackUp',
    duration: 1,
  },
  'beast-back-02': {
    tags: ['crit_if_first'],
  },
  'beast-back-04': {
    tags: ['draw_if_attack_aqua_bird_dawn'],
  },
  'beast-back-06': {
    tags: ['attack_first_if_last_stand'],
  },
  'beast-back-08': {
    tags: ['double_damage_last_stand'],
  },
  'beast-back-10': {
    tags: ['counter_stun_plant_reptile'],
  },
  'beast-back-12': {
    tags: ['multi_hit_3'],
  },
  'beast-horn-02': {
    tags: ['crit_if_first'],
  },
  'beast-horn-04': {
    tags: ['energy_on_crit'],
  },
  'beast-horn-08': {
    tags: ['self_aroma'],
  },
  'beast-horn-12': {
    tags: ['self_speed_up'],
  },
  'beast-tail-06': {
    tags: ['force_last_stand_if_killed'],
  },
  'beast-tail-08': {
    tags: ['draw_if_attack_first'],
  },
  'beast-tail-10': {
    tags: ['force_last_stand_if_killed'],
  },
  'bird-horn-02': {
    tags: ['self_aroma'],
  },
  'bird-horn-08': {
    tags: ['disable_horn_next'],
  },
  'bird-mouth-10': {
    target: 'fastest_enemy',
  },
  'bird-tail-08': {
    tags: ['skip_targets_in_last_stand'],
  },
  'plant-horn-06': {
    effectType: 'heal',
    target: 'self',
    effectValue: 120,
  },
  'plant-back-06': {
    effectType: 'shield',
    target: 'self',
    tags: ['cleanse'],
  },
  'bird-tail-04': {
    effectType: 'damage',
    target: 'enemy',
  },
  'bird-back-02': {
    effectType: 'debuff',
    target: 'enemy',
    debuffType: 'fear',
    duration: 1,
  },
  'bird-back-04': {
    effectType: 'debuff',
    target: 'enemy',
    debuffType: 'chill',
    duration: 4,
  },
  'bird-back-06': {
    effectType: 'debuff',
    target: 'enemy',
    debuffType: 'jinx',
    duration: 4,
  },
  'bird-mouth-02': {
    effectType: 'debuff',
    target: 'enemy',
    debuffType: 'sleep',
    duration: 1,
  },
  'bird-mouth-04': {
    effectType: 'debuff',
    target: 'enemy',
    debuffType: 'attackDown',
    duration: 1,
    effectValue: 20,
  },
  'bug-back-02': {
    effectType: 'debuff',
    target: 'enemy',
    debuffType: 'stunned',
    duration: 1,
  },
  'bug-back-08': {
    tags: ['reflect_ranged'],
  },
  'bug-back-04': {
    effectType: 'debuff',
    target: 'enemy',
    debuffType: 'poisoned',
    duration: 2,
    effectValue: 1,
  },
  'bug-back-10': {
    effectType: 'debuff',
    target: 'enemy',
    debuffType: 'healBlocked',
    duration: 2,
  },
  'bug-tail-02': {
    effectType: 'debuff',
    target: 'enemy',
    debuffType: 'stench',
    duration: 3,
  },
  'bug-tail-06': {
    tags: ['counter_stun_aqua_bird'],
  },
  'bug-tail-08': {
    tags: ['disable_melee_next'],
  },
  'bug-tail-10': {
    tags: ['force_last_stand_if_killed'],
  },
  'bug-tail-12': {
    tags: ['bonus_damage_if_debuffed'],
  },
  'plant-back-08': {
    tags: ['on_hit_energy_vs_aquatic'],
  },
  'plant-back-12': {
    tags: ['draw_if_shield_not_break'],
  },
  'plant-tail-06': {
    tags: ['disable_ability'],
  },
  'plant-tail-02': {
    tags: ['on_shield_break_energy'],
  },
  'plant-tail-04': {
    tags: ['draw_if_hit_by_beast_bug_mech'],
  },
  'reptile-back-08': {
    effectType: 'debuff',
    target: 'self',
    debuffType: 'reflect',
    duration: 2,
  },
  'reptile-back-02': {
    tags: ['draw_if_shield_break'],
  },
  'reptile-back-10': {
    tags: ['shield_when_hit'],
  },
  'reptile-horn-08': {
    tags: ['reflect_ranged'],
  },
  'reptile-tail-08': {
    tags: ['draw_if_shield_not_break'],
  },
  'reptile-tail-12': {
    effectType: 'debuff',
    target: 'enemy',
    debuffType: 'speedDown',
    duration: 1,
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
  const variantId = suffix === '2' ? '06' : suffix ? suffix.padStart(2, '0') : '04';
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
    effectValue: fallback?.effectValue ?? special?.effectValue ?? 0,
    target: fallback?.target ?? special?.target ?? 'enemy',
    buffType: fallback?.buffType ?? special?.buffType,
    debuffType: fallback?.debuffType ?? special?.debuffType,
    duration: fallback?.duration ?? special?.duration ?? 0,
    selfShield: fallback?.selfShield ?? special?.selfShield ?? 0,
    lifeSteal: fallback?.lifeSteal ?? special?.lifeSteal ?? false,
    energySteal: fallback?.energySteal ?? special?.energySteal ?? false,
    energyDrain: fallback?.energyDrain ?? special?.energyDrain ?? false,
    tags: fallback?.tags ?? special?.tags ?? [],
  };

  return resolved;
}
