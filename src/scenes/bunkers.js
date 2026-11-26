import { text, rect } from '../ui.js';
import { writeSave } from '../save.js';

const TILE = 16;
const W = 40, H = 11;
const WALK = 3.1;        // tiles per second
const JUMP = 7.2;        // tiles per second (initial velocity)
const GRAVITY = 11;      // tiles per second^2
const CHECKPOINT = { x: 2.5 * TILE, y: (H - 1) * TILE - 15 };

function makeMap() {
  const map = Array.from({ length: H }, () => Array(W).fill(' '));
  for (let x = 0; x < W; x++) { map[0][x] = '#'; map[H - 1][x] = '#'; }
  for (let y = 0; y < H; y++) { map[y][0] = '#'; map[y][W - 1] = '#'; }
  // pillars (obstacles + texture)
  map[5][8] = '#'; map[6][8] = '#';
  map[4][13] = '#'; map[5][13] = '#';
  // pit: a 3-tile gap in the floor (x = 28..30), columns mostly empty below
  for (let x = 28; x <= 30; x++) map[H - 1][x] = ' ';
  return map;
}

function isSolid(map, tx, ty) {
  if (tx < 0 || ty < 0 || tx >= W) return true; // walls + ceiling
  if (ty >= H) return false;                  // below the map = void
  return map[ty][tx] === '#';
}

export class Bunkers {
  constructor(game) {
    this.game = game;
    this.map = makeMap();
    this.kid = {
      x: CHECKPOINT.x, y: CHECKPOINT.y, w: 11, h: 15,
      vx: 0, vy: 0, onGround: true, face: 1,
    };
    this.time = 0;
    this.dead = false;
    this.deathTimer = 0;
    this.fade = 0;
    this.heard = false;
    this.checkpoint = { ...CHECKPOINT };
    this.deaths = this.game.carry.deaths || 0;
  }

  update(dt) {
    this.time += dt;
    if (this.game.consume('Escape')) { this.game.goTitle(); return; }

    if (this.dead) {
      this.deathTimer += dt;
      if (this.deathTimer >= 1.4) this.resetKid();
      return;
    }

    // "something rustles nearby" one-shot hint as the kid crosses mid-map
    if (!this.heard && this.kid.x > 16 * TILE) { this.heard = true; this.hintTimer = 2.5; }
    if (this.hintTimer) this.hintTimer -= dt;

    // single-tap assist: a quick press moves the kid a little even if you release immediately
    if (this.game.consume('ArrowLeft') || this.game.consume('KeyA')) this.kid.x -= 3.2;
    if (this.game.consume('ArrowRight') || this.game.consume('KeyD')) this.kid.x += 3.2;

    const left = this.game.keys['ArrowLeft'] || this.game.keys['KeyA'];
    const right = this.game.keys['ArrowRight'] || this.game.keys['KeyD'];
    const wantJump = this.game.consume('Space') || this.game.consume('ArrowUp') || this.game.consume('KeyW');

    let vx = 0;
    if (left) { vx = -WALK; this.kid.face = -1; }
    if (right) { vx = WALK; this.kid.face = 1; }
    this.kid.vx = vx * TILE;

    if (wantJump && this.kid.onGround) {
      this.kid.vy = -JUMP * TILE;
      this.kid.onGround = false;
    }

    this.kid.vy += GRAVITY * TILE * dt;
    this.kid.x += this.kid.vx * dt;
    this.resolveX();
    this.kid.y += this.kid.vy * dt;
    this.resolveY();

    // fall into the void
    if (this.kid.y > (H - 1) * TILE + 24) return this.die();

    // reached the surface (walked to the far end)
    if (this.kid.x > (W - 3) * TILE) this.fade = Math.min(1, this.fade + dt * 0.9);
    if (this.fade >= 1) this.finish();
  }

  resolveX() {
    const k = this.kid, map = this.map;
    const x0 = Math.floor(k.x / TILE), x1 = Math.floor((k.x + k.w) / TILE);
    const y0 = Math.floor(k.y / TILE), y1 = Math.floor((k.y + k.h) / TILE);
    for (let ty = y0; ty <= y1; ty++) {
      for (let tx = x0; tx <= x1; tx++) {
        if (!isSolid(map, tx, ty)) continue;
        if (k.vx > 0 && k.x + k.w > tx * TILE && k.x < tx * TILE) k.x = tx * TILE - k.w;
        else if (k.vx < 0 && k.x < (tx + 1) * TILE && k.x + k.w > (tx + 1) * TILE) k.x = (tx + 1) * TILE;
      }
    }
  }

  resolveY() {
    const k = this.kid, map = this.map;
    const x0 = Math.floor(k.x / TILE), x1 = Math.floor((k.x + k.w) / TILE);
    const y0 = Math.floor(k.y / TILE), y1 = Math.floor((k.y + k.h) / TILE);
    k.onGround = false;
    for (let ty = y0; ty <= y1; ty++) {
      for (let tx = x0; tx <= x1; tx++) {
        if (!isSolid(map, tx, ty)) continue;
        if (k.vy >= 0) {
          k.y = ty * TILE - k.h;
          k.vy = 0; k.onGround = true;
        } else {
          k.y = (ty + 1) * TILE;
          k.vy = 0;
        }
      }
    }
  }

  die() {
    if (this.dead) return;
    this.dead = true;
    this.deathTimer = 0;
    this.deaths++;
    this.game.carry.deaths = this.deaths;
  }

  resetKid() {
    this.dead = false;
    this.deathTimer = 0;
    this.kid.x = this.checkpoint.x;
    this.kid.y = this.checkpoint.y;
    this.kid.vx = 0; this.kid.vy = 0; this.kid.onGround = true;
  }

  finish() {
    writeSave({
      age: 13,
      carry: { ...this.game.carry, flag: 'bunkers-cleared' },
    });
    this.game.setScene('adult');
  }

  render(ctx) {
    const W2 = this.game.canvas.width, H2 = this.game.canvas.height;
    const camX = Math.max(0, Math.min(this.kid.x - W2 / 2, W * TILE - W2));

    // background
    rect(ctx, 0, 0, W2, H2, '#161009');
    for (let y = 0; y < H2; y += 4) {
      rect(ctx, 0, y, W2, 1, 'rgba(0,0,0,0.12)');
    }

    // tiles
    for (let ty = 0; ty < H; ty++) {
      for (let tx = 0; tx < W; tx++) {
        const t = this.map[ty][tx];
        if (t === ' ') continue;
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

    // the pit glow hint
    const pitX = 28 * TILE - camX;
    ctx.fillStyle = 'rgba(232, 90, 40, 0.10)';
    ctx.fillRect(pitX, H * TILE - 12, 48, 12);

    // kid (simple placeholder sprite)
    const k = this.kid;
    const kx = Math.round(k.x - camX), ky = Math.round(k.y);
    rect(ctx, kx, ky + 4, k.w, k.h - 4, '#e8c55a');          // body
    rect(ctx, kx + 2, ky, k.w - 4, 6, '#f2e3b6');            // head
    rect(ctx, kx + (k.face > 0 ? k.w - 5 : 2), ky + 2, 3, 2, '#2a1d14'); // eye
    if (this.kid.vx !== 0 && Math.floor(this.time * 8) % 2 === 0) {
      rect(ctx, kx + 1, ky + k.h - 2, 4, 2, '#c8a83e');      // leg hint
      rect(ctx, kx + k.w - 5, ky + k.h - 2, 4, 2, '#c8a83e');
    }

    // hint text
    if (this.heard && this.hintTimer > 0) {
      text(ctx, 'something rustles nearby...', (Math.max(36, Math.min(kx - 8, W2 - 70))) + 36, 26, { size: 7, color: '#a99a78' });
    }

    // dim vignette
    ctx.fillStyle = 'rgba(0,0,0,0.18)';
    ctx.fillRect(0, 0, W2, 6);

    // HUD
    text(ctx, `AGE 6   DEATHS ${this.deaths}`, 6, H2 - 9, { size: 7, color: '#8a7d63', align: 'left' });

    // death overlay
    if (this.dead) {
      ctx.fillStyle = 'rgba(40,8,4,0.72)';
      ctx.fillRect(0, 0, W2, H2);
      text(ctx, 'YOU DIED', W2 / 2, H2 / 2 - 6, { size: 12, color: '#d96a3a' });
      text(ctx, 'falling back to the last checkpoint...', W2 / 2, H2 / 2 + 10, { size: 7, color: '#c8a08a' });
    }

    // surface fade
    if (this.fade > 0) rect(ctx, 0, 0, W2, H2, `rgba(6,4,2,${this.fade})`);
  }
}
