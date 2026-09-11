/** Shared constants for Table Edge Brawl */

export const STOCKS = 3;
export const BLAST_MARGIN = 2.4;
export const GRAVITY = -18;
export const MOVE_SPEED = 3.2;
export const AIR_SPEED = 2.6;
export const JUMP_V = 7.2;
export const DOUBLE_JUMP_V = 6.4;
export const FRICTION = 14;
export const LEDGE_GRAB_RANGE = 0.28;
export const LEDGE_HANG_OFFSET = { x: 0.12, y: -0.35 };
export const ATTACK_RANGE = 0.72;
export const ATTACK_DAMAGE = 9;
export const SPECIAL_DAMAGE = 16;
export const ATTACK_KNOCK = 5.0;
export const SPECIAL_KNOCK = 8.8;
export const HITSTUN = 0.28;
export const ATTACK_COOLDOWN = 0.35;
export const SPECIAL_COOLDOWN = 0.85;

export const FIGHTER_DEFS = [
  {
    id: "rivet",
    name: "Rivet",
    color: 0xb8ff3c,
    accent: 0x1a3d12,
    bodyScale: { x: 0.42, y: 0.78, z: 0.32 },
  },
  {
    id: "bolt",
    name: "Bolt",
    color: 0xff5a36,
    accent: 0x4a160c,
    bodyScale: { x: 0.4, y: 0.82, z: 0.3 },
  },
];
