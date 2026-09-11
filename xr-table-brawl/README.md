# Brinkbound

Free **WebXR** platform fighter for **Meta Quest 3** (pass-through AR) plus desktop sim.

No Unity. No paid engine license. No Nintendo IP — original roster and mechanics inspired by smash-style platform fighters.

## Stack (all free)

- Vite
- Three.js
- WebXR `immersive-ar` (Quest Browser)
- Gamepad API (Xbox / PlayStation)
- Keyboard (desktop)

## Run

```bash
cd xr-table-brawl
npm install
npm run dev
```

Open the printed URL. On Quest: use the headset browser (HTTPS if remote). Desktop works immediately.

## Controls

| | Move | Attack | Special | Smash | Jump | Climb | Dodge |
|---|---|---|---|---|---|---|---|
| **Keyboard P1** | A/D | J | K | U | L/W/Space | I | O |
| **Keyboard P2** | ←/→ | 1 | 2 | 4 | 3/↑ | 5 | 6 |
| **Quest / Xbox / PS** | Stick | Trigger / X□ | Grip / Y△ | B / RT | A | A | Stick click / LT |

## Features

- 10 original heroines with lore + portrait art
- Table stage with ledge grab / hang / climb
- Percent damage, smash charge, stocks, blast zones
- Blood VFX on heavy knockback hits
- Quest 3 controller-first mapping + Xbox/DualSense
- Desktop room simulator when XR is unavailable

## Quest notes

1. `npm run build`
2. Host `dist/` over HTTPS (Quest Browser needs a secure context)
3. **Quest AR** → point at your table → trigger to place
4. Right controller = P1, left = P2 (or AI fills in)
