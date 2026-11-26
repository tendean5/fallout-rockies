// Bunker stage textures — Fallout 1 muddy palette, seamless 2D tiles for the
// side-view corridor (ceiling/wall, floor, pillar). The game is 2D, so only
// the albedo channel is used; normals/heights are built for completeness.
// Build: node <loom>/bin/loom.js build <this file> --out ../textures --no-preview

// ---- wall: dark brown brick, slightly weathered ----
pal({
	brick: "#5a4226", brickL: "#7d5a33", brickD: "#362614",
	mortar: "#2a1c10", grime: "#33241a",
})
const b = bricks({ rows: 12, cols: 4, gap: 0.035, bevel: 0.02, wobble: 0.6, seed: 3 }).as("brick")
const grain = noise({ scale: 32, octaves: 4, seed: 2 }).as("grain")
const chips = ridged({ scale: 18, octaves: 3, seed: 5 }).threshold(0.88, 0.06).mul(b.mask).as("chips")
const grime = b.mask.invert().max(noise({ scale: 6, seed: 7 }).threshold(0.55, 0.25).mul(0.6)).as("grime")
const wallHeight = b.mul(0.8).add(grain.mul(0.12)).sub(chips.mul(0.25)).as("height")
material("bunker_wall", { size: 128, depth: 0.035 }, {
	height: wallHeight,
	color: ramp(b.id.mix(grain, 0.4).mix(chips, 0.3), ["brickD", "brick", "brickL"])
		.mix("mortar", b.mask.invert())
		.mix("grime", grime.mul(0.3)),
	rough: grain.levels(0, 1, 0.75, 0.9).mix(0.6, grime),
})

// ---- floor: smooth poured concrete with stains and cracks ----
pal({
	concrete: "#463420", concreteL: "#6b5230", concreteD: "#2a1f12",
	stain: "#281c10", crack: "#1a1108", grime: "#1a1108",
})
const n = noise({ scale: 26, octaves: 5, seed: 4 }).as("concrete")
const cracks = ridged({ scale: 10, octaves: 3, seed: 8 }).threshold(0.9, 0.04).as("cracks")
const stain = noise({ scale: 5, octaves: 3, seed: 3 }).threshold(0.55, 0.2).as("stain")
const floorHeight = n.add(cracks.mul(-0.35)).sub(stain.mul(0.12)).as("height")
material("bunker_floor", { size: 128, depth: 0.02 }, {
	height: floorHeight,
	color: ramp(n, ["concreteD", "concrete", "concreteL"])
		.mix("stain", stain.mul(0.42))
		.mix("crack", cracks.mul(0.75)),
	rough: n.levels(0, 1, 0.7, 0.85).mix(0.55, stain),
})

// ---- pillar: darker version of the wall brick ----
pal({
	brick: "#45311e", brickL: "#624826", brickD: "#2b1d0f",
	mortar: "#2a1c10", grime: "#33241a",
})
const p = bricks({ rows: 6, cols: 2, gap: 0.028, bevel: 0.025, wobble: 0.5, seed: 11 }).as("pillar_brick")
const pgrain = noise({ scale: 20, octaves: 4, seed: 6 }).as("grain")
const pillarHeight = p.mul(0.8).add(pgrain.mul(0.14)).as("height")
material("bunker_pillar", { size: 128, depth: 0.04 }, {
	height: pillarHeight,
	color: ramp(p.id.mix(pgrain, 0.4), ["brickD", "brick", "brickL"]).mix("mortar", p.mask.invert()),
	rough: pgrain.levels(0, 1, 0.7, 0.92),
})
