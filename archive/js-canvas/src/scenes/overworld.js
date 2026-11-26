import { text, rect } from '../ui.js';
import {
  TILE, MAP_W, MAP_H, makeMap, colorOf, SOLID, T_WATER, T_GRASS, T_DIRT, T_ROAD, T_CITY, T_MTN, T_FOREST, T_SNOW, regionName,
} from '../worldmap.js';
import { writeSave } from '../save.js';

const WALK = 3.4;                 // tiles per second
const CHECKPOINT_START = { x: 6 * TILE, y: 38 * TILE };

export class Overworld {
  constructor(game) {
    this.game = game;
    this.map = makeMap();
    this.kid = {
      x: CHECKPOINT_START.x, y: CHECKPOINT_START.y, w: 11, h: 13,
      vx: 0, face: 1,
    };
    this.time = 0;
    this.fade = 1;
    this.dead = false;
    this.deadTimer = 0;
    this.drown = 0;
    this.deaths = this.game.carry.deaths || 0;
    this.age = this.game.carry.age || 13;
    this.region = regionName(6, 38);
    this.checkpoint = this.game.checkpoint
      ? { x: this.game.checkpoint.x * TILE, y: this.game.checkpoint.y * TILE }
      : { ...CHECKPOINT_START };
    this.kid.x = this.checkpoint.x;
    this.kid.y = this.checkpoint.y;
    this.savedTime = 0;
  }

  update(dt) {
    this.time += dt;
    if (this.fade < 1) this.fade = Math.max(0, this.fade - dt * 1.8);

    if (this.game.consume('Escape')) { this.game.goTitle(); return; }

    if (this.dead) {
      this.deadTimer += dt;
      if (this.deadTimer >= 1.3) this.resetKid();
      return;
    }

    // tap assist
    if (this.game.consume('ArrowLeft') || this.game.consume('KeyA')) this.kid.x -= 3.2;
    if (this.game.consume('ArrowRight') || this.game.consume('KeyD')) this.kid.x += 3.2;
    if (this.game.consume('ArrowUp') || this.game.consume('KeyW')) this.kid.y -= 3.2;
    if (this.game.consume('ArrowDown') || this.game.consume('KeyS')) this.kid.y += 3.2;

    const left = this.game.keys['ArrowLeft'] || this.game.keys['KeyA'];
    const right = this.game.keys['ArrowRight'] || this.game.keys['KeyD'];
    const up = this.game.keys['ArrowUp'] || this.game.keys['KeyW'];
    const down = this.game.keys['ArrowDown'] || this.game.keys['KeyS'];

    let vx = 0, vy = 0;
    if (left) { vx = -WALK; this.kid.face = -1; }
    if (right) { vx = WALK; this.kid.face = 1; }
    if (up) vy = -WALK;
    if (down) vy = WALK;
    this.kid.vx = vx * TILE;

    this.kid.x += this.kid.vx * dt;
    this.kid.y += vy * TILE * dt;
    this.resolveCollisions();

    // clamp to the map
    this.kid.x = Math.max(0, Math.min(this.kid.x, MAP_W * TILE - this.kid.w));
    this.kid.y = Math.max(0, Math.min(this.kid.y, MAP_H * TILE - this.kid.h));

    // track the checkpoint
    const tile = this.tileAtKid();
    const inWater = tile === T_WATER;
    if (!this.isInSolid() && !inWater && !this.dead) {
      this.checkpoint = { x: this.kid.x, y: this.kid.y };
      this.savedTime += dt;
      if (this.savedTime >= 1.5) {
        this.savedTime = 0;
        this.game.checkpoint = { x: Math.floor(this.kid.x / TILE), y: Math.floor(this.kid.y / TILE) };
        this.game.saveGame({ flag: 'overworld' });
      }
    }

    // drown timer
    if (tile === T_WATER) {
      this.drown += dt;
      if (this.drown >= 1.6) return this.die();
    } else {
      this.drown = Math.max(0, this.drown - dt * 2);
    }

    this.region = regionName(Math.floor(this.kid.x / TILE), Math.floor(this.kid.y / TILE));
  }

  tileAt(tx, ty) {
    if (ty < 0 || ty >= MAP_H || tx < 0 || tx >= MAP_W) return T_CITY; // treat walls as solid
    return this.map[ty][tx];
  }

  isSolid(tx, ty) {
    return SOLID.has(this.tileAt(tx, ty));
  }

  isInSolid() {
    const k = this.kid;
    const x0 = Math.floor(k.x / TILE), x1 = Math.floor((k.x + k.w) / TILE);
    const y0 = Math.floor(k.y / TILE), y1 = Math.floor((k.y + k.h) / TILE);
    for (let ty = y0; ty <= y1; ty++) for (let tx = x0; tx <= x1; tx++) if (this.isSolid(tx, ty)) return true;
    return false;
  }

  tileAtKid() {
    const k = this.kid;
    return this.tileAt(Math.floor((k.x + k.w / 2) / TILE), Math.floor((k.y + k.h / 2) / TILE));
  }

  resolveCollisions() {
    const k = this.kid;
    // resolve on X axis
    const r = this.resolveX();
    if (r) this.resolveY();
  }

  resolveX() {
    const k = this.kid;
    const x0 = Math.floor(k.x / TILE), x1 = Math.floor((k.x + k.w) / TILE);
    const y0 = Math.floor(k.y / TILE), y1 = Math.floor((k.y + k.h) / TILE);
    let hit = false;
    for (let ty = y0; ty <= y1; ty++) {
      for (let tx = x0; tx <= x1; tx++) {
        if (!this.isSolid(tx, ty)) continue;
        // push out horizontally
        const leftEdge = tx * TILE, rightEdge = (tx + 1) * TILE;
        const midX = k.x + k.w / 2;
        if (midX < (leftEdge + rightEdge) / 2) k.x = leftEdge - k.w;
        else k.x = rightEdge;
        hit = true;
      }
    }
    return hit;
  }

  resolveY() {
    const k = this.kid;
    const x0 = Math.floor(k.x / TILE), x1 = Math.floor((k.x + k.w) / TILE);
    const y0 = Math.floor(k.y / TILE), y1 = Math.floor((k.y + k.h) / TILE);
    for (let ty = y0; ty <= y1; ty++) {
      for (let tx = x0; tx <= x1; tx++) {
        if (!this.isSolid(tx, ty)) continue;
        const topEdge = ty * TILE, bottomEdge = (ty + 1) * TILE;
        const midY = k.y + k.h / 2;
        if (midY < (topEdge + bottomEdge) / 2) k.y = topEdge - k.h;
        else k.y = bottomEdge;
      }
    }
  }

  die() {
    if (this.dead) return;
    this.dead = true;
    this.deadTimer = 0;
    this.drown = 0;
    this.deaths++;
    this.game.carry.deaths = this.deaths;
  }

  resetKid() {
    this.dead = false;
    this.deadTimer = 0;
    this.drown = 0;
    this.kid.x = this.checkpoint.x;
    this.kid.y = this.checkpoint.y;
  }

  render(ctx) {
    const W2 = this.game.canvas.width, H2 = this.game.canvas.height;
    const camX = Math.max(0, Math.min(this.kid.x - W2 / 2, MAP_W * TILE - W2));
    const camY = Math.max(0, Math.min(this.kid.y - H2 / 2, MAP_H * TILE - H2));

    // background
    rect(ctx, 0, 0, W2, H2, '#14100b');

    // tiles
    const tx0 = Math.max(0, Math.floor(camX / TILE) - 1), ty0 = Math.max(0, Math.floor(camY / TILE) - 1);
    const tx1 = Math.min(MAP_W - 1, Math.floor((camX + W2) / TILE) + 1), ty1 = Math.min(MAP_H - 1, Math.floor((camY + H2) / TILE) + 1);
    for (let ty = ty0; ty <= ty1; ty++) {
      for (let tx = tx0; tx <= tx1; tx++) {
        const t = this.map[ty][tx];
        const px = Math.round(tx * TILE - camX), py = Math.round(ty * TILE - camY);
        if (px < -TILE || px > W2 || py < -TILE || py > H2) continue;
        rect(ctx, px, py, TILE, TILE, colorOf(t, tx, ty));
        // simple texturing
        if (t === T_FOREST) { rect(ctx, px + 2, py + 2, 3, 3, '#1c3319'); rect(ctx, px + 9, py + 6, 3, 3, '#1c3319'); }
        if (t === T_MTN) { rect(ctx, px + 3, py + 4, 4, 4, '#3c3a45'); rect(ctx, px + 9, py + 10, 3, 3, '#2a2833'); }
        if (t === T_CITY) { rect(ctx, px + 3, py + 3, 10, 10, '#1f1712'); rect(ctx, px + 4, py + 4, 8, 2, '#170f0b'); }
        if (t === T_ROAD) { rect(ctx, px + 6, py, 4, TILE, '#413422'); }
        if (t === T_WATER) {
          // shimmer
          const w = Math.floor((this.time * 3 + tx + ty) % 3);
          rect(ctx, px, py + 5 + w * 2, TILE, 2, 'rgba(120,170,210,0.35)');
        }
        if (t === T_SNOW) { rect(ctx, px + 3, py + 9, 10, 3, '#e6ddce'); }
      }
    }

    // kid (simple placeholder sprite)
    const k = this.kid;
    const kx = Math.round(k.x - camX), ky = Math.round(k.y - camY);
    rect(ctx, kx, ky + 4, k.w, k.h - 4, '#e8c55a');
    rect(ctx, kx + 2, ky, k.w - 4, 6, '#f2e3b6');
    rect(ctx, kx + (k.face > 0 ? k.w - 5 : 2), ky + 2, 3, 2, '#2a1d14');

    // HUD
    rect(ctx, 0, 0, W2, 14, 'rgba(10,8,5,0.82)');
    text(ctx, `AGE ${this.age}   ${this.region}`, 6, 7, { size: 7, color: '#c8d4a0', align: 'left' });
    text(ctx, `DEATHS ${this.deaths}`, W2 - 6, 7, { size: 7, color: '#8a7d63', align: 'right' });

    // drown warning
    if (this.drown > 0.2) {
      text(ctx, 'SPLASH — GET OUT OF THE WATER', W2 / 2, H2 / 2 - 12, { size: 8, color: '#6ab0e0' });
      text(ctx, `drowning in ${(1.6 - this.drown).toFixed(1)}s`, W2 / 2, H2 / 2 + 2, { size: 6, color: '#3a5a78' });
    }

    // death overlay
    if (this.dead) {
      ctx.fillStyle = 'rgba(50,14,8,0.74)';
      ctx.fillRect(0, 0, W2, H2);
      text(ctx, 'YOU DIED', W2 / 2, H2 / 2 - 4, { size: 12, color: '#d96a3a' });
      text(ctx, 'back to the last safe tile...', W2 / 2, H2 / 2 + 12, { size: 7, color: '#c8a08a' });
    }

    // fade in
    if (this.fade > 0) {
      ctx.fillStyle = `rgba(6,4,2,${this.fade})`;
      ctx.fillRect(0, 0, W2, H2);
    }
  }
}
