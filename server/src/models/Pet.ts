import { BasePet, PetState, DNAAttributes } from './BasePet';

export class Pet extends BasePet {
  name: string;
  hatchedAt?: number;

  constructor(
    id: string,
    dna: string,
    hatchTime: number,
    owner: string,
    attributes: DNAAttributes,
  ) {
    super(id, dna, hatchTime, owner, attributes);
    this.name = `Likha #${id.slice(0, 6).toUpperCase()}`;
  }

  hatch(): void {
    if (!this.isReadyToHatch()) {
      const secs = Math.ceil(this.msUntilHatch() / 1000);
      throw new Error(`Not ready to hatch. ${secs}s remaining.`);
    }
    if (this.state === PetState.HATCHED) {
      throw new Error('Already hatched.');
    }
    this.state = PetState.HATCHED;
    this.hatchedAt = Date.now();
  }
}
