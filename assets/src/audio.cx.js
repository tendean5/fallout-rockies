// Bunker / loading screen audio — Fallout 1-ish mood: low ambience, torch crackle,
// short dialogue blip, footstep thud, and a soft chime.
// Build: node <chirp>/bin/chirp.js build <this file> --out ../audio

let seed = 0x9e3779b9
const rnd = () => {
  seed = (seed + 0x6d2b79f5) | 0
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed)
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296
}

// Low cave ambience: wind swell + sub rumble + off-screen drips. Loops seamlessly.
sfx("ambience", { dur: 8, loop: true, vol: 0.8, fx: [reverb({ size: 0.8, damp: 0.5, mix: 0.35 }), limiter()] },
  noise({ color: "pink", dur: 8, env: [0, 0, 1, 0], vol: 0.16, tremolo: { rate: 0.25, depth: 0.6 }, filter: { type: "bp", cutoff: 420, q: 0.7 } }),
  noise({ color: "brown", dur: 8, env: [0, 0, 1, 0], vol: 0.34, filter: { type: "lp", cutoff: 95 } }),
  Array.from({ length: 7 }, () => at(rnd() * 7.6,
    tone({ wave: "sine", freq: 900 + rnd() * 700, to: 2200 + rnd() * 500, slide: 0.05, dur: 0.04, env: [0.001, 0.04, 0, 0.06], vol: 0.28, pan: rnd() * 1.4 - 0.7 }))))

// Torch crackle: low brown-noise rumble + random pops/snaps. Loops seamlessly.
sfx("torch_crackle", { dur: 3, loop: true, vol: 0.55, fx: [limiter()] },
  noise({ color: "brown", dur: 3, env: [0, 0, 1, 0], vol: 0.22, filter: { type: "lp", cutoff: 240 } }),
  Array.from({ length: 14 }, () => at(rnd() * 2.9,
    tone({ wave: "square", freq: 150 + rnd() * 260, to: 80 + rnd() * 60, slide: 0.02, dur: 0.02, env: [0.001, 0.008, 0, 0.03], vol: 0.05 + rnd() * 0.08, pan: rnd() * 1.2 - 0.6 }))))

// Dialogue blip — one short chirp per line.
sfx("dialogue_blip", { dur: 0.14, vol: 0.4, fx: [limiter()] },
  tone({ wave: "square", freq: 330, to: 235, slide: 0.09, dur: 0.09, env: [0.004, 0.04, 0.35, 0.08], vol: 0.5 }))

// Footstep thud.
sfx("walk_step", { dur: 0.10, vol: 0.75, fx: [limiter()] },
  noise({ color: "brown", dur: 0.09, env: [0.004, 0.05, 0, 0.05], vol: 0.9, filter: { type: "lp", cutoff: 220 }, freq: 140 }))

// A small chime — used at loading completion and scene entry.
sfx("chime", { dur: 0.9, vol: 0.5, fx: [reverb({ size: 0.5, damp: 0.6, mix: 0.3 }), limiter()] },
  tone({ wave: "fm", freq: 660, dur: 0.5, env: [0.006, 0.3, 0.12, 0.4], vol: 0.4, fm: { ratio: 3.5, index: 5, decay: 0.3 } }),
  at(0.09, tone({ wave: "fm", freq: 990, dur: 0.5, env: [0.006, 0.3, 0.1, 0.4], vol: 0.22, fm: { ratio: 3.5, index: 5, decay: 0.3 } })))
