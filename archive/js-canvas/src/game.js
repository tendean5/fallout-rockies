import { Title } from './scenes/title.js';
import { Bunkers } from './scenes/bunkers.js';
import { Overworld } from './scenes/overworld.js';
import { loadSave, writeSave } from './save.js';

export class Game {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.ctx.imageSmoothingEnabled = false;
    this.keys = {};
    this.justPressed = new Set();
    this.save = loadSave();
    this.carry = this.save?.carry || { artifact: 'locket', flag: null, age: 6, deaths: 0 };
    this.checkpoint = this.save?.checkpoint || null;
    this.setScene('title');

    window.addEventListener('keydown', (e) => {
      if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space'].includes(e.code)) e.preventDefault();
      if (e.repeat) return;
      this.justPressed.add(e.code);
      this.keys[e.code] = true;
    });
    window.addEventListener('keyup', (e) => { this.keys[e.code] = false; });

    // mouse clicks (menu buttons); coordinates scaled to the canvas's
    // internal resolution, and consumed by scenes
    this.mousedown = null;
    this.mouse = { x: -1, y: -1 };
    canvas.addEventListener('pointermove', (e) => {
      const r = canvas.getBoundingClientRect();
      this.mouse.x = (e.clientX - r.left) * (canvas.width / r.width);
      this.mouse.y = (e.clientY - r.top) * (canvas.height / r.height);
    });
    canvas.addEventListener('pointerdown', (e) => {
      const r = canvas.getBoundingClientRect();
      const x = (e.clientX - r.left) * (canvas.width / r.width);
      const y = (e.clientY - r.top) * (canvas.height / r.height);
      this.mousedown = { x, y };
      this.justPressed.add('click');
    });
  }

  setScene(name) {
    this.sceneName = name;
    if (name === 'title') this.scene = new Title(this);
    else if (name === 'bunkers') this.scene = new Bunkers(this);
    else if (name === 'overworld') this.scene = new Overworld(this);
    this.justPressed.clear();
  }

  consume(code) {
    if (this.justPressed.has(code)) { this.justPressed.delete(code); return true; }
    return false;
  }

  anyFreshKey() {
    if (this.justPressed.size) { this.justPressed.clear(); return true; }
    return false;
  }

  goTitle() { this.setScene('title'); }

  saveGame(extra) {
    return writeSave({
      age: this.carry.age || 6,
      checkpoint: this.checkpoint,
      carry: { ...this.carry, age: this.carry.age || 6 },
      ...extra,
    });
  }

  start() {
    this.last = performance.now();
    requestAnimationFrame((t) => this.loop(t));
  }

  loop(t) {
    const now = performance.now();
    const dt = Math.min((t - this.last) / 1000, 0.05);
    this.last = now;
    this.scene.update(dt);
    this.scene.render(this.ctx);
    requestAnimationFrame((t) => this.loop(t));
  }
}
