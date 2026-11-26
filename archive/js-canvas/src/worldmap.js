export const TILE = 16;
export const MAP_W = 72, MAP_H = 52;

export const T_GRASS = 0, T_DIRT = 1, T_ROAD = 2, T_CITY = 3, T_MTN = 4, T_FOREST = 5, T_WATER = 6, T_SNOW = 7;

export const SOLID = new Set([T_CITY, T_MTN, T_FOREST]);

const rand = (x, y) => {
  const h = Math.sin(x * 127.1 + y * 311.7) * 43758.5453;
  return h - Math.floor(h);
};

export function makeMap() {
  const map = Array.from({ length: MAP_H }, () => Array(MAP_W).fill(T_GRASS));

  // mountain ridge across the top-right, with a pass through
  for (let y = 0; y < 9; y++) {
    for (let x = 30; x < MAP_W; x++) {
      if (x >= 46 && x <= 49) map[y][x] = T_SNOW;   // the pass
      else map[y][x] = T_MTN;
    }
  }

  // dense forest across the top-left
  for (let y = 0; y < 9; y++) {
    for (let x = 0; x <= 29; x++) {
      if (rand(x, y) < 0.55) map[y][x] = T_FOREST;
    }
  }

  // Denver grid: blocks with dirt streets
  for (let y = 10; y <= 33; y++) {
    for (let x = 4; x <= 39; x++) {
      if (x % 5 === 0 || y % 5 === 0) map[y][x] = T_DIRT;
      else map[y][x] = T_CITY;
    }
  }

  // airport zone (southwest): walkable dirt + a few concrete blocks
  for (let y = 36; y <= 45; y++) {
    for (let x = 2; x <= 14; x++) map[y][x] = T_DIRT;
  }
  map[40][4] = T_CITY; map[40][8] = T_CITY; map[41][12] = T_CITY;

  // high country (east): dirt + scattered trees
  for (let y = 10; y < 34; y++) {
    for (let x = 42; x < MAP_W; x++) {
      if (map[y][x] === T_GRASS) map[y][x] = T_DIRT;
      if (rand(x, y) < 0.16) map[y][x] = T_FOREST;
    }
  }

  // desert (far west): open grass with a few trees
  for (let y = 10; y < 34; y++) {
    for (let x = 0; x < 4; x++) {
      if (rand(x, y) < 0.12) map[y][x] = T_FOREST;
    }
  }

  // Platte River across the bottom (wavy), with a road bridge
  for (let y = 45; y < MAP_H; y++) {
    for (let x = 0; x < MAP_W; x++) {
      const wave = Math.sin(x * 0.22) * 1.6;
      if (y >= Math.round(45 + wave)) map[y][x] = T_WATER;
    }
  }
  for (let y = 44; y < MAP_H; y++) {
    for (let x = 18; x <= 20; x++) map[y][x] = T_ROAD;
  }

  // road: airport → Denver grid → south to the bridge
  for (let x = 2; x <= 18; x++) map[38][x] = T_ROAD;
  for (let y = 34; y <= 45; y++) {
    for (let x = 19; x <= 20; x++) map[y][x] = T_ROAD;
  }

  return map;
}

export function regionName(x, y) {
  if (y <= 9 && x >= 30) return x >= 46 && x <= 49 ? 'The High Country Pass' : 'The Peaks';
  if (y <= 9) return 'The Woods';
  if (y <= 33 && x >= 40) return 'The High Country';
  if (y <= 33 && x >= 4) return 'Denver Ruins';
  if (y <= 33) return 'The Wastes';
  if (y <= 45) return 'The Airport';
  return 'The Platte';
}

export function colorOf(t, x, y) {
  const v = ((x * 7 + y * 13) % 3) / 3;
  switch (t) {
    case T_GRASS: return v < 0.4 ? '#3a3020' : v < 0.75 ? '#413627' : '#443a24';
    case T_DIRT: return '#4a3a22';
    case T_ROAD: return '#51422a';
    case T_CITY: return '#2b2118';
    case T_MTN: return v < 0.5 ? '#33313a' : '#2e2c36';
    case T_FOREST: return '#263d24';
    case T_WATER: return '#1c3550';
    case T_SNOW: return '#d8cfc0';
    default: return '#3a3020';
  }
}
