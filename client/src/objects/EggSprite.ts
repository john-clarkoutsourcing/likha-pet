import Phaser from 'phaser';
import { PetData, Rarity } from '../api/ApiClient';

const RARITY_COLORS: Record<Rarity, number> = {
  Common:    0xaaaaaa,
  Uncommon:  0x33ff57,
  Rare:      0x3399ff,
  Epic:      0xcc44ff,
  Legendary: 0xffd700,
};

export class EggSprite extends Phaser.GameObjects.Container {
  petData: PetData;
  onHatchRequest?: (id: string) => void;

  private shell: Phaser.GameObjects.Graphics;
  private shimmer: Phaser.GameObjects.Graphics;
  private timerLabel: Phaser.GameObjects.Text;
  private nameLabel: Phaser.GameObjects.Text;
  private rarityLabel: Phaser.GameObjects.Text;
  private glowTween: Phaser.Tweens.Tween | null = null;

  constructor(scene: Phaser.Scene, x: number, y: number, petData: PetData) {
    super(scene, x, y);
    this.petData = petData;

    this.shell = scene.add.graphics();
    this.shimmer = scene.add.graphics();
    this.drawShell();

    this.nameLabel = scene.add.text(0, -68, petData.name, {
      fontSize: '12px', color: '#ffd700', align: 'center',
    }).setOrigin(0.5);

    this.timerLabel = scene.add.text(0, 58, '', {
      fontSize: '13px', color: '#ffffff', align: 'center',
    }).setOrigin(0.5);

    this.rarityLabel = scene.add.text(0, 76, petData.attributes.rarity, {
      fontSize: '11px', align: 'center',
      color: `#${RARITY_COLORS[petData.attributes.rarity].toString(16).padStart(6, '0')}`,
    }).setOrigin(0.5);

    this.add([this.shell, this.shimmer, this.nameLabel, this.timerLabel, this.rarityLabel]);

    this.setSize(80, 100);
    this.setInteractive(new Phaser.Geom.Ellipse(0, 0, 80, 100), Phaser.Geom.Ellipse.Contains);
    this.on('pointerover', () => this.setScale(1.08));
    this.on('pointerout', () => this.setScale(1.0));
    this.on('pointerdown', this.handleClick, this);

    scene.add.existing(this);
  }

  private drawShell(): void {
    const fillColor = parseInt(this.petData.attributes.color.replace('#', ''), 16);
    const rarityColor = RARITY_COLORS[this.petData.attributes.rarity];

    this.shell.clear();
    this.shell.fillStyle(fillColor, 1);
    this.shell.fillEllipse(0, 0, 80, 100);

    // Rarity outline ring
    this.shell.lineStyle(3, rarityColor, 0.85);
    this.shell.strokeEllipse(0, 0, 80, 100);

    // Shine highlight
    this.shimmer.clear();
    this.shimmer.fillStyle(0xffffff, 0.18);
    this.shimmer.fillEllipse(-14, -20, 28, 36);
  }

  private handleClick(): void {
    if (this.petData.state === 'Egg' && Date.now() >= this.petData.hatchTime) {
      this.onHatchRequest?.(this.petData.id);
    }
  }

  refresh(data: PetData): void {
    this.petData = data;
    this.drawShell();
    if (data.state === 'Hatched') this.startHatchedAnim();
  }

  private startHatchedAnim(): void {
    if (this.glowTween) return;
    this.glowTween = this.scene.tweens.add({
      targets: this,
      scaleX: 1.06,
      scaleY: 1.06,
      yoyo: true,
      repeat: -1,
      duration: 700,
      ease: 'Sine.easeInOut',
    });
  }

  tick(): void {
    if (this.petData.state === 'Hatched') {
      this.timerLabel.setText('✨ Hatched!').setColor('#ffd700');
      this.startHatchedAnim();
      return;
    }

    const ms = Math.max(0, this.petData.hatchTime - Date.now());
    if (ms === 0) {
      this.timerLabel.setText('Tap to Hatch!').setColor('#00ff88');
    } else {
      const s = Math.floor(ms / 1000) % 60;
      const m = Math.floor(ms / 60000);
      this.timerLabel.setText(`${m}:${String(s).padStart(2, '0')}`).setColor('#cccccc');
    }
  }
}
