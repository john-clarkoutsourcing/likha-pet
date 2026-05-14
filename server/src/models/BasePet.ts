import { PetState, DNAAttributes } from '../../../shared/types';

export { PetState, DNAAttributes };

export abstract class BasePet {
  readonly id: string;
  readonly dna: string;
  state: PetState;
  readonly hatchTime: number;
  readonly owner: string;
  readonly attributes: DNAAttributes;
  readonly createdAt: number;

  constructor(
    id: string,
    dna: string,
    hatchTime: number,
    owner: string,
    attributes: DNAAttributes,
  ) {
    this.id = id;
    this.dna = dna;
    this.state = PetState.EGG;
    this.hatchTime = hatchTime;
    this.owner = owner;
    this.attributes = attributes;
    this.createdAt = Date.now();
  }

  isReadyToHatch(): boolean {
    return Date.now() >= this.hatchTime;
  }

  msUntilHatch(): number {
    return Math.max(0, this.hatchTime - Date.now());
  }

  abstract hatch(): void;
}
