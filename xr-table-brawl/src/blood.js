import * as THREE from "three";

/**
 * Screen-space-ish blood bursts parented in world space.
 * Quest 3 friendly: pooled sprites, capped count.
 */
export function createBloodSystem(scene) {
  const max = 120;
  const geo = new THREE.SphereGeometry(0.025, 6, 6);
  const mat = new THREE.MeshBasicMaterial({
    color: 0x8b0000,
    transparent: true,
    opacity: 0.95,
  });

  const pool = [];
  for (let i = 0; i < max; i++) {
    const m = new THREE.Mesh(geo, mat.clone());
    m.visible = false;
    m.userData = { life: 0, vx: 0, vy: 0, vz: 0 };
    scene.add(m);
    pool.push(m);
  }

  let cursor = 0;

  function spawn(origin, dir, intensity = 1) {
    const count = Math.min(28, 10 + Math.floor(intensity * 14));
    for (let i = 0; i < count; i++) {
      const p = pool[cursor % max];
      cursor++;
      p.visible = true;
      p.position.copy(origin);
      p.position.x += (Math.random() - 0.5) * 0.08;
      p.position.y += (Math.random() - 0.5) * 0.08;
      p.material.opacity = 0.85 + Math.random() * 0.15;
      p.material.color.setHex(Math.random() > 0.3 ? 0x8b0000 : 0x5c0000);
      const spread = 1.2 * intensity;
      p.userData.vx = dir.x * (2 + Math.random() * 4) * intensity + (Math.random() - 0.5) * spread;
      p.userData.vy = 2.5 * intensity + Math.random() * 3 * intensity;
      p.userData.vz = dir.z * (1 + Math.random() * 2) + (Math.random() - 0.5) * spread;
      p.userData.life = 0.45 + Math.random() * 0.55;
      const s = 0.6 + Math.random() * 1.4 * intensity;
      p.scale.setScalar(s);
    }
  }

  function update(dt, floorY = 0) {
    for (const p of pool) {
      if (!p.visible) continue;
      p.userData.life -= dt;
      if (p.userData.life <= 0) {
        p.visible = false;
        continue;
      }
      p.userData.vy -= 18 * dt;
      p.position.x += p.userData.vx * dt;
      p.position.y += p.userData.vy * dt;
      p.position.z += p.userData.vz * dt;
      if (p.position.y < floorY) {
        p.position.y = floorY;
        p.userData.vy *= -0.15;
        p.userData.vx *= 0.7;
        p.material.opacity *= 0.85;
      }
      p.material.opacity = Math.min(p.material.opacity, p.userData.life);
    }
  }

  return { spawn, update };
}
