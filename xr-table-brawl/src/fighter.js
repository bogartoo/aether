import * as THREE from "three";
import {
  GRAVITY,
  BLAST_MARGIN,
  LEDGE_GRAB_RANGE,
  LEDGE_HANG_OFFSET,
  HITSTUN_BASE,
  DODGE_TIME,
  DODGE_COOLDOWN,
  MOVE_SPEED,
  AIR_SPEED,
  JUMP_V,
  DOUBLE_JUMP_V,
  FRICTION,
  ATTACK_RANGE,
  ATTACK_DAMAGE,
  SPECIAL_DAMAGE,
  SMASH_DAMAGE,
  ATTACK_KNOCK,
  SPECIAL_KNOCK,
  SMASH_KNOCK,
  ATTACK_COOLDOWN,
  SPECIAL_COOLDOWN,
  SMASH_COOLDOWN,
  BLOOD_KB_THRESHOLD,
} from "./constants.js";
import { STOCKS } from "./roster.js";
import { createHeroineMesh } from "./heroineMesh.js";

export function createFighterState(def, side, spawn, textureLoader) {
  const mesh = createHeroineMesh(def, textureLoader);
  return {
    def,
    side,
    mesh,
    x: spawn.x,
    y: spawn.y,
    z: spawn.z,
    vx: 0,
    vy: 0,
    facing: side === 0 ? 1 : -1,
    onGround: true,
    hanging: false,
    hangSide: 0,
    jumpsLeft: 2,
    percent: 0,
    stocks: STOCKS,
    hitstun: 0,
    attackCd: 0,
    specialCd: 0,
    smashCd: 0,
    attackActive: 0,
    specialActive: 0,
    smashActive: 0,
    smashCharge: 0,
    dodgeT: 0,
    dodgeCd: 0,
    invuln: 0,
    alive: true,
    animT: 0,
    bloodStain: 0,
  };
}

export function resetFighter(f, spawn) {
  f.x = spawn.x;
  f.y = spawn.y;
  f.z = spawn.z;
  f.vx = 0;
  f.vy = 0;
  f.onGround = true;
  f.hanging = false;
  f.jumpsLeft = 2;
  f.percent = 0;
  f.hitstun = 0;
  f.attackCd = 0;
  f.specialCd = 0;
  f.smashCd = 0;
  f.attackActive = 0;
  f.specialActive = 0;
  f.smashActive = 0;
  f.smashCharge = 0;
  f.dodgeT = 0;
  f.dodgeCd = 0;
  f.invuln = 1.25;
  f.alive = true;
  f.facing = f.side === 0 ? 1 : -1;
  f.bloodStain = 0;
  syncMesh(f);
}

export function updateFighter(f, input, table, dt, other, onEvent) {
  if (!f.alive) return;

  const spd = f.def.speed ?? 1;
  const pow = f.def.power ?? 1;
  const wgt = f.def.weight ?? 1;

  f.attackCd = Math.max(0, f.attackCd - dt);
  f.specialCd = Math.max(0, f.specialCd - dt);
  f.smashCd = Math.max(0, f.smashCd - dt);
  f.hitstun = Math.max(0, f.hitstun - dt);
  f.invuln = Math.max(0, f.invuln - dt);
  f.attackActive = Math.max(0, f.attackActive - dt);
  f.specialActive = Math.max(0, f.specialActive - dt);
  f.smashActive = Math.max(0, f.smashActive - dt);
  f.dodgeCd = Math.max(0, f.dodgeCd - dt);
  f.dodgeT = Math.max(0, f.dodgeT - dt);
  f.bloodStain = Math.max(0, f.bloodStain - dt * 0.35);
  f.animT += dt;

  const topY = table.topY;
  const halfW = table.halfW;
  const cx = table.center.x;
  const cz = table.center.z;
  const leftEdge = cx - halfW;
  const rightEdge = cx + halfW;

  if (f.hanging) {
    const edgeX = f.hangSide < 0 ? leftEdge : rightEdge;
    f.x = edgeX + f.hangSide * LEDGE_HANG_OFFSET.x;
    f.y = topY + LEDGE_HANG_OFFSET.y;
    f.vx = 0;
    f.vy = 0;
    f.facing = -f.hangSide;
    if (input.climb || input.jump) {
      f.hanging = false;
      f.y = topY + 0.02;
      f.vy = JUMP_V * 0.88;
      f.vx = -f.hangSide * 2.4;
      f.onGround = false;
      f.jumpsLeft = 1;
    } else if (input.move * f.hangSide > 0.25) {
      f.hanging = false;
      f.vy = -1;
      f.onGround = false;
    }
    syncMesh(f);
    return;
  }

  const canControl = f.hitstun <= 0 && f.dodgeT <= 0;
  const move = canControl ? input.move : 0;

  if (canControl && input.dodge && f.dodgeCd <= 0 && f.onGround) {
    f.dodgeT = DODGE_TIME;
    f.dodgeCd = DODGE_COOLDOWN;
    f.invuln = Math.max(f.invuln, DODGE_TIME);
    f.vx = f.facing * 4.5 * spd;
  }

  if (canControl && input.jump) {
    if (f.onGround) {
      f.vy = JUMP_V;
      f.onGround = false;
      f.jumpsLeft = 1;
    } else if (f.jumpsLeft > 0) {
      f.vy = DOUBLE_JUMP_V;
      f.jumpsLeft -= 1;
    }
  }

  if (canControl && input.smashHold && f.smashCd <= 0) {
    f.smashCharge = Math.min(1, f.smashCharge + dt * 1.35);
  } else if (
    canControl &&
    (input.smash || (f.smashCharge > 0.15 && !input.smashHold))
  ) {
    if (f.smashCd <= 0) {
      const charge = Math.max(0.35, f.smashCharge);
      f.smashCd = SMASH_COOLDOWN;
      f.smashActive = 0.18;
      f.vx += f.facing * (2 + charge * 4);
      tryHit(
        f,
        other,
        SMASH_DAMAGE * charge * pow,
        SMASH_KNOCK * (0.7 + charge * 0.6),
        1.45,
        onEvent,
        true
      );
      f.smashCharge = 0;
    }
  } else if (!input.smashHold) {
    f.smashCharge = 0;
  }

  if (canControl && input.attack && f.attackCd <= 0) {
    f.attackCd = ATTACK_COOLDOWN;
    f.attackActive = 0.12;
    tryHit(f, other, ATTACK_DAMAGE * pow, ATTACK_KNOCK, 1.0, onEvent, false);
  }

  if (canControl && input.special && f.specialCd <= 0) {
    f.specialCd = SPECIAL_COOLDOWN;
    f.specialActive = 0.16;
    f.vx += f.facing * 3.8 * spd;
    tryHit(f, other, SPECIAL_DAMAGE * pow, SPECIAL_KNOCK, 1.3, onEvent, true);
  }

  const speed = (f.onGround ? MOVE_SPEED : AIR_SPEED) * spd;
  if (Math.abs(move) > 0.05) {
    f.vx = move * speed;
    f.facing = Math.sign(move) || f.facing;
  } else if (f.onGround && f.hitstun <= 0 && f.dodgeT <= 0) {
    f.vx = THREE.MathUtils.damp(f.vx, 0, FRICTION, dt);
  }

  f.vy += GRAVITY * (0.92 + wgt * 0.08) * dt;
  f.x += f.vx * dt;
  f.y += f.vy * dt;
  f.z = THREE.MathUtils.damp(f.z, cz, 8, dt);

  const overTable = f.x >= leftEdge && f.x <= rightEdge;
  if (overTable && f.y <= topY && f.vy <= 0 && f.y > topY - 0.55) {
    f.y = topY;
    f.vy = 0;
    f.onGround = true;
    f.jumpsLeft = 2;
  } else if (!overTable) {
    f.onGround = false;
  }

  if (!overTable && f.y >= topY - 0.01 && f.vy >= 0) {
    f.vy = Math.min(f.vy, -0.5);
  }

  if (
    !f.onGround &&
    !f.hanging &&
    f.y < topY + 0.25 &&
    f.y > topY - 0.95 &&
    f.vy <= 1.5
  ) {
    const nearLeft =
      f.x < leftEdge + LEDGE_GRAB_RANGE &&
      f.x > leftEdge - LEDGE_GRAB_RANGE * 2.5;
    const nearRight =
      f.x > rightEdge - LEDGE_GRAB_RANGE &&
      f.x < rightEdge + LEDGE_GRAB_RANGE * 2.5;
    if (nearLeft || nearRight) {
      f.hanging = true;
      f.hangSide = nearLeft ? -1 : 1;
      f.vx = 0;
      f.vy = 0;
      onEvent?.("ledge");
    }
  }

  const halfD = table.halfD ?? table.halfDepth ?? 0.4;
  f.z = THREE.MathUtils.clamp(f.z, cz - halfD * 0.35, cz + halfD * 0.35);
  syncMesh(f);
}

function tryHit(attacker, target, damage, knockBase, mult, onEvent, canBlood) {
  if (!target?.alive || target.invuln > 0 || target.hanging || target.dodgeT > 0) {
    return;
  }
  const dx = target.x - attacker.x;
  const dy = target.y + 0.5 - (attacker.y + 0.5);
  const dist = Math.hypot(dx, dy);
  const facingOk = Math.sign(dx) === attacker.facing || Math.abs(dx) < 0.2;
  if (dist > ATTACK_RANGE * mult || !facingOk) return;

  const kbScale =
    (1 + target.percent / 95) / Math.max(0.75, target.def.weight ?? 1);
  const dir = Math.sign(dx) || attacker.facing;
  const knock = knockBase * kbScale;
  target.percent += damage;
  target.vx = dir * knock;
  target.vy = knock * 0.55;
  target.onGround = false;
  target.hanging = false;
  target.hitstun = HITSTUN_BASE + target.percent * 0.0025;
  target.invuln = 0.12;
  target.bloodStain = Math.min(1, (target.bloodStain || 0) + 0.35);
  if (target.mesh.hitFlash?.material) {
    target.mesh.hitFlash.material.opacity = 0.75;
  }

  const heavy = canBlood && knock >= BLOOD_KB_THRESHOLD;
  onEvent?.("hit", {
    damage,
    target,
    attacker,
    knock,
    blood: heavy,
    origin: new THREE.Vector3(
      target.x,
      target.y + 0.65 * (target.def.height ?? 1),
      target.z
    ),
    dir: new THREE.Vector3(dir, 0.35, 0),
  });
}

export function syncMesh(f) {
  const { root, armL, armR, legL, legR, hitFlash, bloodDecal } = f.mesh;
  const hs = f.def.height ?? 1;
  root.position.set(f.x, f.y, f.z);
  root.scale.set((f.facing >= 0 ? 1 : -1) * hs, hs, hs);

  const punch =
    f.attackActive > 0 || f.specialActive > 0 || f.smashActive > 0;
  if (armR) {
    armR.rotation.z = punch
      ? -1.2
      : Math.sin(f.animT * 8) * (f.onGround ? 0.12 : 0.35);
  }
  if (armL) {
    armL.rotation.z = punch
      ? 0.35
      : -Math.sin(f.animT * 8) * (f.onGround ? 0.12 : 0.35);
  }

  const run = f.onGround && Math.abs(f.vx) > 0.4;
  if (legL) legL.rotation.x = run ? Math.sin(f.animT * 12) * 0.45 : 0;
  if (legR) legR.rotation.x = run ? -Math.sin(f.animT * 12) * 0.45 : 0;

  if (f.hanging) {
    if (armL) armL.rotation.z = -2.1;
    if (armR) armR.rotation.z = -2.1;
    root.rotation.z = f.hangSide * 0.32;
  } else {
    root.rotation.z =
      f.smashCharge > 0 ? f.facing * -0.08 * f.smashCharge : 0;
  }

  if (hitFlash?.material?.opacity > 0) {
    hitFlash.material.opacity = Math.max(0, hitFlash.material.opacity - 0.08);
  }
  if (bloodDecal?.material) {
    bloodDecal.material.opacity = (f.bloodStain || 0) * 0.75;
  }

  root.visible =
    f.alive && !(f.invuln > 0 && Math.floor(f.invuln * 18) % 2 === 0);
}

export function isBlasted(f, table) {
  return (
    f.y < table.topY - BLAST_MARGIN ||
    f.x < table.center.x - table.halfW - BLAST_MARGIN ||
    f.x > table.center.x + table.halfW + BLAST_MARGIN
  );
}
