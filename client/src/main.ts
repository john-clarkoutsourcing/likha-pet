import Phaser from 'phaser';
import { BootScene } from './scenes/BootScene';
import { HatcheryScene } from './scenes/HatcheryScene';

const config: Phaser.Types.Core.GameConfig = {
  type: Phaser.AUTO,
  width: 800,
  height: 600,
  backgroundColor: '#0d0d1a',
  parent: document.body,
  scene: [BootScene, HatcheryScene],
};

new Phaser.Game(config);
