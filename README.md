# Fallout Rockies

An original, Colorado-specific, *Fallout*-inspired roguelike. Pixel art, low-res canvas,
no dependencies, runs in a browser.

**Planning:** see [CONCEPT.md](CONCEPT.md) (the world) and [BUILD.md](BUILD.md) (the plan).

## How to run

No build step. Serve the folder and open it in a browser:

```sh
cd fallout-rockies
python3 -m http.server 8000
# then open http://localhost:8000
```

Any static file server works — the game only needs `index.html` + `src/`.

## Controls

Arrows / WASD — move (a quick tap also moves the kid)
Space / W / up — jump
Escape — back to menu

On the title screen choose **New Game** or **Load**. New Game clears past saves;
Load resumes from the last save.

You fall into the pit, die, and return to the last checkpoint. Carry-forwards
(locket, flags, age, deaths) persist in `localStorage` under
`fallout-rockies.save.v1`.
