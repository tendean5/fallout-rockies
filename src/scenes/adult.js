import { text, rect } from '../ui.js';

export class Adult {
  constructor(game) {
    this.game = game;
    this.t = 0;
  }

  update(dt) {
    this.t += dt;
    if (this.game.consume('Escape')) this.game.setScene('title');
  }

  render(ctx) {
    rect(ctx, 0, 0, 320, 176, '#0b0806');
    const save = this.game.carry;
    text(ctx, 'YOU GREW UP', 160, 40, { size: 14, color: '#e8c55a' });
    text(ctx, 'the surface is hostile', 160, 64, { size: 8, color: '#7d7058' });

    text(ctx, `AGE 13   LOCKETED: locket   DEATHS: ${save.deaths || 0}`, 160, 100, { size: 7, color: '#8a7d63' });

    text(ctx, 'M1 skeleton', 160, 134, { size: 8, color: '#c8d4a0' });
    text(ctx, 'the main story begins here — M2', 160, 150, { size: 7, color: '#7d7058' });
    text(ctx, 'Escape — back to title', 160, 168, { size: 6, color: '#5a5040' });
  }
}
