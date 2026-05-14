import Phaser from 'phaser';

export class BootScene extends Phaser.Scene {
  constructor() { super('BootScene'); }

  create(): void {
    // Placeholder for asset loading in future sprints
    this.scene.start('HatcheryScene');
  }
}
