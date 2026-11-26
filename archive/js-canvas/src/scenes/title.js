import { text, rect } from '../ui.js';
import { loadSave, clearSave } from '../save.js';

// Menu layout (canvas is 320x176)
const BTN_Y = [100, 126];
const BTN_W = 130, BTN_H = 18;

export class Title {
  constructor(game) {
    this.game = game;
    this.t = 0;
    this.selection = 0;                     // 0 = New Game, 1 = Load
    this.blink = Math.floor(this.t * 2) % 2 === 0;
  }

  buttons() {
    const save = loadSave();
    return [
      { id: 'new', label: 'NEW GAME', x: 95, w: BTN_W, y: BTN_Y[0], h: BTN_H, enabled: true },
      { id: 'load', label: 'LOAD', x: 95, w: BTN_W, y: BTN_Y[1], h: BTN_H, enabled: !!save },
    ];
  }

  update(dt) {
    this.t += dt;
    this.blink = Math.floor(this.t * 2) % 2 === 0;
    const btns = this.buttons();

    // keyboard nav
    if (this.game.consume('ArrowUp') || this.game.consume('KeyW')) {
      this.selection = (this.selection + btns.length - 1) % btns.length;
    }
    if (this.game.consume('ArrowDown') || this.game.consume('KeyS')) {
      this.selection = (this.selection + 1) % btns.length;
    }
    if (this.game.consume('Enter') || this.game.consume('Space')) this.confirm();

    // mouse click
    if (this.game.consume('click')) {
      const { x, y } = this.game.mousedown;
      for (const b of btns) {
        if (x >= b.x && x <= b.x + b.w && y >= b.y && y <= b.y + b.h) {
          this.selection = btns.indexOf(b);
          this.confirm();
          return;
        }
      }
    }
  }

  confirm() {
    const btns = this.buttons();
    const b = btns[this.selection];
    if (!b || !b.enabled) return;
    if (b.id === 'new') {
      this.game.carry = { artifact: 'locket', flag: null, age: 6, deaths: 0 };
      this.game.save = null;
      clearSave();
      this.game.setScene('bunkers');
    } else if (b.id === 'load') {
      this.game.setScene('overworld');
    }
  }

  render(ctx) {
    rect(ctx, 0, 0, 320, 176, '#0b0806');
    text(ctx, 'FALLOUT', 160, 34, { size: 26, color: '#e8c55a' });
    text(ctx, 'ROCKIES', 160, 62, { size: 26, color: '#e8c55a' });
    text(ctx, 'an original game', 160, 84, { size: 7, color: '#7d7058' });

    const btns = this.buttons();
    for (let i = 0; i < btns.length; i++) {
      const b = btns[i];
      const selected = i === this.selection;
      const hovered = this.game.mouse && this.game.mouse.x >= b.x && this.game.mouse.x <= b.x + b.w && this.game.mouse.y >= b.y && this.game.mouse.y <= b.y + b.h;
      const lit = selected || hovered;
      rect(ctx, b.x - 2, b.y - 2, b.w + 4, b.h + 4, lit ? '#e8c55a' : '#2a2015');
      rect(ctx, b.x, b.y, b.w, b.h, lit ? '#1c150c' : '#16100a');
      text(ctx, b.label, b.x + b.w / 2, b.y + b.h / 2, {
        size: 9,
        color: !b.enabled ? '#4a4032' : lit ? '#e8c55a' : '#8a7d63',
      });
      if (!b.enabled && i === 1) {
        text(ctx, 'no saves yet', b.x + b.w / 2, b.y + b.h + 9, { size: 6, color: '#5a5040' });
      }
    }

    if (this.blink) text(ctx, 'Arrows to choose · Enter to confirm · click works too', 160, 168, { size: 6, color: '#5a5040' });
  }
}
