import { text, rect } from '../ui.js';
import { writeSave } from '../save.js';

const TILE = 16;
const W = 40, H = 11;
const WALK = 3.1;

function makeMap() {
  const map = Array.from({ length: H }, () => Array(W).fill(' '));
  for (let x = 0; x < W; x++) { map[0][x] = '#'; map[H - 1][x] = '#'; }
  for (let y = 0; y < H; y++) { map[y][0] = '#'; map[y][W - 1] = '#'; }
  // decorative pillars
  map[5][8] = '#'; map[6][8] = '#';
  map[4][13] = '#'; map[5][13] = '#';
  return map;
}

function isSolid(map, tx, ty) {
  if (tx < 0 || ty < 0 || tx >= W || ty >= H) return true;
  return map[ty][tx] === '#';
}

export class Bunkers {
  constructor(game) {
    this.game = game;
    this.map = makeMap();
    this.kid = { x: 3 * TILE, y: (H - 1) * TILE - 13, w: 11, h: 13, face: 1 };
    this.time = 0;
    this.fade = 1;
    this.surface = false;
    this.surfaceFade = 0;
    this.hintTimer = 3;
    this.checkpoint = { x: 3 * TILE, y: (H - 1) * TILE - 13 };
    this.deaths = 0;
  }

  update(dt) {
    this.time += dt;
    if (this.fade < 1) this.fade = Math.max(0, this.fade - dt * 2);

    if (this.game.consume('Escape')) { this.game.goTitle(); return; }
    if (this.hintTimer > 0) this.hintTimer -= dt;

    // tap assist
    if (this.game.consume('ArrowRight') || this.game.consume('KeyD')) this.kid.x += 3.2;
    if (this.game.consume('ArrowLeft') || this.game.consume('KeyA')) this.kid.x -= 3.2;

    const left = this.game.keys['ArrowLeft'] || this.game.keys['KeyA'];
    const right = this.game.keys['ArrowRight'] || this.game.keys['KeyD'];
    let vx = 0;
    if (left) { vx = -WALK; this.kid.face = -1; }
    if (right) { vx = WALK; this.kid.face = 1; }
    this.kid.x += vx * TILE * dt;
    this.resolveX();

    // walk off the end of the corridor -> surface
    if (this.kid.x > (W - 3) * TILE) {
      this.surface = true;
      this.surfaceFade = Math.min(1, this.surfaceFade + dt * 0.8);
      if (this.surfaceFade >= 1) this.finish();
    }
  }

  resolveX() {
    const k = this.kid, map = this.map;
    const x0 = Math.floor(k.x / TILE), x1 = Math.floor((k.x + k.w) / TILE);
    const y0 = Math.floor(k.y / TILE), y1 = Math.floor((k.y + k.h) / TILE);
    for (let ty = y0; ty <= y1; ty++) {
      for (let tx = x0; tx <= x1; tx++) {
        if (!isSolid(map, tx, ty)) continue;
        if (k.x + k.w > tx * TILE && k.x < tx * TILE) k.x = tx * TILE - k.w;
        else if (k.x < (tx + 1) * TILE && k.x + k.w > (tx + 1) * TILE) k.x = (tx + 1) * TILE;
      }
    }
  }

  finish() {
    writeSave({
      age: 13,
      carry: { ...this.game.carry, flag: 'bunkers-cleared', age: 13 },
    });
    this.game.setScene('overworld');
  }

  render(ctx) {
    const W2 = this.game.canvas.width, H2 = this.game.canvas.height;
    const camX = Math.max(0, Math.min(this.kid.x - W2 / 2, W * TILE - W2));

    rect(ctx, 0, 0, W2, H2, '#16100a');

    for (let ty = 0; ty < H; ty++) {
      for (let tx = 0; tx < W; tx++) {
        if (this.map[ty][tx] === ' ') continue;
        const px = Math.round(tx * TILE - camX), py = ty * TILE;
        if (px < -TILE || px > W2) continue;
        if (ty === 0) rect(ctx, px, py, TILE, TILE, '#241a10');
        else if (ty === H - 1) {
          rect(ctx, px, py, TILE, TILE, '#2b2013');
          rect(ctx, px, py, TILE, 2, '#4a3620');
        } else {
          rect(ctx, px, py, TILE, TILE, '#2c2117');
          rect(ctx, px, py, TILE, 2, '#3d2c1a');
        }
      }
    }

    // the kid
    const k = this.kid;
    const kx = Math.round(k.x - camX), ky = Math.round(k.y);
    rect(ctx, kx, ky + 4, k.w, k.h - 4, '#e8c55a');
    rect(ctx, kx + 2, ky, k.w - 4, 6, '#f2e3b6');
    rect(ctx, kx + (k.face > 0 ? k.w - 5 : 2), ky + 2, 3, 2, '#2a1d14');

    // hints
    if (this.hintTimer > 0) {
      text(ctx, 'the bunkers are deep and dark...', W2 / 2, 26, { size: 7, color: '#9a8c70' });
    }
    if (this.surface) {
      text(ctx, 'you fall, wake at the surface...', W2 / 2, H2 / 2, { size: 9, color: '#e8c55a' });
    }

    // HUD
    text(ctx, `AGE 6`, 6, H2 - 9, { size: 7, color: '#8a7d63', align: 'left' });

    if (this.fade > 0) { ctx.fillStyle = `rgba(6,4,2,${this.fade})`; ctx.fillRect(0, 0, W2, H2); }
    if (this.surfaceFade > 0) { ctx.fillStyle = `rgba(6,4,2,${this.surfaceFade})`; ctx.fillRect(0, 0, W2, H2); }
  }
}
