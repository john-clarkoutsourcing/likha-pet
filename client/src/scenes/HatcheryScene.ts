import Phaser from 'phaser';
import { ApiClient, PetData } from '../api/ApiClient';
import { EggSprite } from '../objects/EggSprite';

// Hardcoded for MVP; replace with auth session in a real build.
const OWNER = 'player1';

const COLS = 5;
const START_X = 100;
const START_Y = 160;
const CELL_W = 140;
const CELL_H = 160;

export class HatcheryScene extends Phaser.Scene {
  private eggs: EggSprite[] = [];
  private statusText!: Phaser.GameObjects.Text;
  private spawnBtn!: Phaser.GameObjects.Text;

  constructor() { super('HatcheryScene'); }

  create(): void {
    this.add.rectangle(0, 0, 800, 600, 0x0d0d1a).setOrigin(0);

    // Decorative header bar
    this.add.rectangle(0, 0, 800, 85, 0x1a1a3e).setOrigin(0);
    this.add.text(400, 26, 'LIKHA PET', {
      fontSize: '32px', color: '#ffd700', fontStyle: 'bold',
    }).setOrigin(0.5);
    this.add.text(400, 60, 'HATCHERY', {
      fontSize: '14px', color: '#8888cc', letterSpacing: 6,
    }).setOrigin(0.5);

    // Trainer label
    this.add.text(16, 96, `Trainer: ${OWNER}`, {
      fontSize: '13px', color: '#888888',
    });

    // Status bar
    this.add.rectangle(0, 570, 800, 30, 0x111130).setOrigin(0);
    this.statusText = this.add.text(400, 572, 'Loading inventory…', {
      fontSize: '13px', color: '#88ccff',
    }).setOrigin(0.5, 0);

    // Spawn button
    this.spawnBtn = this.add.text(400, 530, '[ + Spawn Egg ]', {
      fontSize: '18px', color: '#ffffff',
      backgroundColor: '#2a2a6e',
      padding: { x: 18, y: 10 },
    }).setOrigin(0.5).setInteractive({ useHandCursor: true });

    this.spawnBtn.on('pointerover', () => this.spawnBtn.setStyle({ color: '#ffd700' }));
    this.spawnBtn.on('pointerout',  () => this.spawnBtn.setStyle({ color: '#ffffff' }));
    this.spawnBtn.on('pointerdown', this.spawnEgg, this);

    this.loadInventory();
    this.time.addEvent({ delay: 500, loop: true, callback: this.tick, callbackScope: this });
  }

  private async spawnEgg(): Promise<void> {
    this.spawnBtn.setAlpha(0.5).disableInteractive();
    try {
      const pet = await ApiClient.spawnEgg(OWNER);
      this.addOrRefresh(pet);
      this.setStatus(`Egg spawned — DNA: ${pet.dna.slice(0, 12)}… | Rarity: ${pet.attributes.rarity}`);
    } catch (e: unknown) {
      this.setStatus(`Error: ${(e as Error).message}`, true);
    } finally {
      this.spawnBtn.setAlpha(1).setInteractive({ useHandCursor: true });
    }
  }

  private async loadInventory(): Promise<void> {
    try {
      const inventory = await ApiClient.getInventory(OWNER);
      inventory.forEach(p => this.addOrRefresh(p));
      this.setStatus(`Inventory loaded — ${inventory.length} pet(s) found`);
    } catch {
      this.setStatus('Could not reach server. Is it running?', true);
    }
  }

  private async hatchEgg(id: string): Promise<void> {
    try {
      const pet = await ApiClient.hatchEgg(id, OWNER);
      this.addOrRefresh(pet);
      this.setStatus(`${pet.name} has hatched! Element: ${pet.attributes.element} | Power: ${pet.attributes.basePower}`);
      this.cameras.main.shake(250, 0.012);
    } catch (e: unknown) {
      this.setStatus((e as Error).message, true);
    }
  }

  private addOrRefresh(petData: PetData): void {
    const existing = this.eggs.find(e => e.petData.id === petData.id);
    if (existing) {
      existing.refresh(petData);
      return;
    }
    const idx = this.eggs.length;
    const x = START_X + (idx % COLS) * CELL_W;
    const y = START_Y + Math.floor(idx / COLS) * CELL_H;
    const sprite = new EggSprite(this, x, y, petData);
    sprite.onHatchRequest = id => this.hatchEgg(id);
    this.eggs.push(sprite);
  }

  private tick(): void {
    this.eggs.forEach(e => e.tick());
  }

  private setStatus(msg: string, isError = false): void {
    this.statusText.setText(msg).setColor(isError ? '#ff6666' : '#88ccff');
  }
}
