# Table Edge Brawl

Original **XR pass-through platform fighter** — plant two brawlers on your real table, rack up percent, hang off the lip, and blast rivals into the room. Not affiliated with Nintendo; characters **Rivet** and **Bolt** are originals.

## Play

### Desktop simulator

```bash
cd xr-table-brawl
npm install
npm run dev
```

Open the URL Vite prints, then click **Play desktop sim**.

| | Move | Attack | Special | Jump | Ledge climb |
|---|---|---|---|---|---|
| **P1 Rivet** | A / D | J | K | L / W / Space | I |
| **P2 Bolt** | ← / → | 1 | 2 | 3 / ↑ | 5 |

### Meta Quest pass-through AR

1. `npm run build` then host `dist/` over **HTTPS** (Quest Browser requires a secure context).
2. Open the page in **Meta Quest Browser**.
3. Tap **Enter AR pass-through**.
4. Point at your table until the reticle sticks, then **trigger** to place the stage.
5. Right controller = Rivet, left = Bolt (or a light AI fills in if the left stick is idle).

## Features

- Percent damage + knockback scaling
- Table ledge grab, hang, climb, or drop
- Stocks (3) and blast-zone KOs past the table edge
- Desktop room + table sim for development without a headset
- WebXR `immersive-ar` path for Quest-style pass-through

## Project layout

```
xr-table-brawl/
  index.html
  src/main.js      # boot, HUD, XR session, game loop
  src/fighter.js   # meshes, physics, combat, ledge state
  src/stage.js     # desktop room + table mesh
  src/input.js     # keyboard + Quest gamepad
  src/constants.js
  src/styles.css
```
