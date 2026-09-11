import * as THREE from "three";
import {
  STOCKS,
  MOVE_SPEED,
  AIR_SPEED,
  JUMP_V,
  DOUBLE_JUMP_V,
  FRICTION,
  GRAVITY,
  LEDGE_GRAB_RANGE,
  LEDGE_HANG_OFFSET,
  ATTACK_RANGE,
  ATTACK_DAMAGE,
  SPECIAL_DAMAGE,
  ATTACK_KNOCK,
  SPECIAL_KNOCK,
  HITSTUN,
  ATTACK_COOLDOWN,
  SPECIAL_COOLDOWN,
} from "./constants.js";

export function createFighterMesh(def) {
  const root = new THREE.Group();
  root.name = def.name;

  const bodyMat = new THREE.MeshStandardMaterial({
    color: def.color,
    roughness: 0.45,
    metalness: 0.15,
    emissive: def.color,
    emissiveIntensity: 0.12,
  });
  const accentMat = new THREE.MeshStandardMaterial({
    color: def.accent,
    roughness: 0.7,
    metalness: 0.05,
  });

  const torso = new THREE.Mesh(
    new THREE.BoxGeometry(def.bodyScale.x, def.bodyScale.y * 0.55, def.bodyScale.z),
    bodyMat
  );
  torso.position.y = def.bodyScale.y * 0.45;
  torso.castShadow = true;
  root.add(torso);

  const head = new THREE.Mesh(new THREE.BoxGeometry(0.28, 0.28, 0.28), bodyMat);
  head.position.y = def.bodyScale.y * 0.85;
  head.castShadow = true;
  root.add(head);

  const visor = new THREE.Mesh(new THREE.BoxGeometry(0.22, 0.08, 0.06), accentMat);
  visor.position.set(0, def.bodyScale.y * 0.88, 0.14);
  root.add(visor);

  const legL = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.28, 0.14), accentMat);
  legL.position.set(-0.1, 0.14, 0);
  root.add(legL);
  const legR = legL.clone();
  legR.position.x = 0.1;
  root.add(legR);

  const armL = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.32, 0.1), bodyMat);
  armL.position.set(-def.bodyScale.x * 0.65, def.bodyScale.y * 0.5, 0);
  root.add(armL);
  const armR = armL.clone();
  armR.position.x = def.bodyScale.x * 0.65;
  root.add(armR);

  const hitFlash = new THREE.Mesh(
    new THREE.SphereGeometry(0.35, 12, 12),
    new THREE.MeshBasicMaterial({
      color: 0xffffff,
      transparent: true,
      opacity: 0,
      depthWrite: false,
    })
  );
  hitFlash.position.y = def.bodyScale.y * 0.5;
  root.add(hitFlash);

  return { root, armL, armR, hitFlash, legL, legR };
}

export function createFighterState(def, side, spawn) {
  const mesh = createFighterMesh(def);
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
    attackActive: 0,
    specialActive: 0,
    invuln: 0,
    alive: true,
    animT: 0,
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
  f.attackActive = 0;
  f.specialActive = 0;
  f.invuln = 1.2;
  f.alive = true;
  f.facing = f.side === 0 ? 1 : -1;
}

/**
 * @param {object} f fighter
 * @param {object} input { move, jump, attack, special, climb }
 * @param {object} table { halfW, halfD, topY, center }
 * @param {number} dt
 * @param {object} other other fighter for combat
 * @param {(msg:string)=>void} onEvent
 */
export function updateFighter(f, input, table, dt, other, onEvent) {
  if (!f.alive) return;

  f.attackCd = Math.max(0, f.attackCd - dt);
  f.specialCd = Math.max(0, f.specialCd - dt);
  f.hitstun = Math.max(0, f.hitstun - dt);
  f.invuln = Math.max(0, f.invuln - dt);
  f.attackActive = Math.max(0, f.attackActive - dt);
  f.specialActive = Math.max(0, f.specialActive - dt);
  f.animT += dt;

  const topY = table.topY;
  const halfW = table.halfW;
  const cx = table.center.x;
  const cz = table.center.z;
  const leftEdge = cx - halfW;
  const rightEdge = cx + halfW;

  // Ledge hang / climb
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
      f.vy = JUMP_V * 0.85;
      f.vx = -f.hangSide * 2.2;
      f.onGround = false;
      f.jumpsLeft = 1;
    } else if (input.move * f.hangSide > 0.2) {
      // drop
      f.hanging = false;
      f.vy = -1;
      f.onGround = false;
    }
    syncMesh(f);
    return;
  }

  const canControl = f.hitstun <= 0;
  const move = canControl ? input.move : 0;

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

  if (canControl && input.attack && f.attackCd <= 0) {
    f.attackCd = ATTACK_COOLDOWN;
    f.attackActive = 0.12;
    tryHit(f, other, ATTACK_DAMAGE, ATTACK_KNOCK, 1.0, onEvent);
  }

  if (canControl && input.special && f.specialCd <= 0) {
    f.specialCd = SPECIAL_COOLDOWN;
    f.specialActive = 0.16;
    f.vx += f.facing * 3.5;
    tryHit(f, other, SPECIAL_DAMAGE, SPECIAL_KNOCK, 1.35, onEvent);
  }

  const speed = f.onGround ? MOVE_SPEED : AIR_SPEED;
  if (Math.abs(move) > 0.05) {
    f.vx = move * speed;
    f.facing = Math.sign(move) || f.facing;
  } else if (f.onGround && f.hitstun <= 0) {
    f.vx = THREE.MathUtils.damp(f.vx, 0, FRICTION, dt);
  }

  f.vy += GRAVITY * dt;
  f.x += f.vx * dt;
  f.y += f.vy * dt;
  // Keep fighters on the table depth center (2.5D plane on table length)
  f.z = THREE.MathUtils.damp(f.z, cz, 8, dt);

  // Ground / table surface (2.5D along table width)
  const overTable = f.x >= leftEdge && f.x <= rightEdge;
  if (overTable && f.y <= topY && f.vy <= 0 && f.y > topY - 0.5) {
    f.y = topY;
    f.vy = 0;
    f.onGround = true;
    f.jumpsLeft = 2;
  } else if (!overTable || f.y > topY + 0.02) {
    if (!(overTable && f.y >= topY)) f.onGround = false;
  }

  // Auto ledge-grab when slipping past the lip while falling
  if (!f.onGround && f.vy <= 0 && f.y < topY + 0.2 && f.y > topY - 0.85) {
    const nearLeft = f.x < leftEdge + LEDGE_GRAB_RANGE && f.x > leftEdge - LEDGE_GRAB_RANGE * 2;
    const nearRight = f.x > rightEdge - LEDGE_GRAB_RANGE && f.x < rightEdge + LEDGE_GRAB_RANGE * 2;
    if (nearLeft || nearRight) {
      f.hanging = true;
      f.hangSide = nearLeft ? -1 : 1;
      f.vx = 0;
      f.vy = 0;
      onEvent?.("ledge");
    }
  }

  // Soft clamp depth so they don't wander off table Z
  f.z = THREE.MathUtils.clamp(f.z, cz - table.halfD * 0.35, cz + table.halfD * 0.35);

  syncMesh(f);
}

function tryHit(attacker, target, damage, knockBase, mult, onEvent) {
  if (!target?.alive || target.invuln > 0 || target.hanging) return;
  const dx = target.x - attacker.x;
  const dy = target.y - attacker.y;
  const dist = Math.hypot(dx, dy);
  const facingOk = Math.sign(dx) === attacker.facing || Math.abs(dx) < 0.15;
  if (dist > ATTACK_RANGE * mult || !facingOk) return;

  const kbScale = 1 + target.percent / 100;
  const dir = Math.sign(dx) || attacker.facing;
  target.percent += damage;
  target.vx = dir * knockBase * kbScale;
  target.vy = knockBase * 0.55 * kbScale;
  target.onGround = false;
  target.hanging = false;
  target.hitstun = HITSTUN + target.percent * 0.002;
  target.invuln = 0.15;
  flashHit(target);
  onEvent?.("hit", { damage, target });
}

function flashHit(f) {
  f.mesh.hitFlash.material.opacity = 0.7;
}

export function syncMesh(f) {
  const { root, armL, armR, hitFlash, legL, legR } = f.mesh;
  root.position.set(f.x, f.y, f.z);
  root.scale.x = f.facing;
  root.visible = f.alive;

  const punch = f.attackActive > 0 || f.specialActive > 0;
  armR.rotation.z = punch ? -1.1 : Math.sin(f.animT * 8) * (f.onGround ? 0.15 : 0.4);
  armL.rotation.z = punch ? 0.4 : -Math.sin(f.animT * 8) * (f.onGround ? 0.15 : 0.4);

  const run = f.onGround && Math.abs(f.vx) > 0.4;
  legL.rotation.x = run ? Math.sin(f.animT * 12) * 0.5 : 0;
  legR.rotation.x = run ? -Math.sin(f.animT * 12) * 0.5 : 0;

  if (f.hanging) {
    armL.rotation.z = -2.2;
    armR.rotation.z = -2.2;
    root.rotation.z = f.hangSide * 0.35;
  } else {
    root.rotation.z = 0;
  }

  if (hitFlash.material.opacity > 0) {
    hitFlash.material.opacity = Math.max(0, hitFlash.material.opacity - 0.08);
  }

  // Subtle invuln blink
  root.visible = f.alive && !(f.invuln > 0 && Math.floor(f.invuln * 20) % 2 === 0);
}

export function isBlasted(f, table) {
  const margin = 2.4;
  return (
    f.y < table.topY - margin ||
    f.x < table.center.x - table.halfW - margin ||
    f.x > table.center.x + table.halfW + margin
  );
}
