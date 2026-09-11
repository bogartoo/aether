import * as THREE from "three";

const skinMatCache = new Map();

function skinMaterial(color) {
  const key = color.toString(16);
  if (skinMatCache.has(key)) return skinMatCache.get(key);
  const mat = new THREE.MeshStandardMaterial({
    color,
    roughness: 0.45,
    metalness: 0.05,
  });
  skinMatCache.set(key, mat);
  return mat;
}

function clothMaterial(color, opts = {}) {
  return new THREE.MeshStandardMaterial({
    color,
    roughness: opts.roughness ?? 0.65,
    metalness: opts.metalness ?? 0.08,
    emissive: opts.emissive ?? 0x000000,
    emissiveIntensity: opts.emissiveIntensity ?? 0,
  });
}

/**
 * Original mid-poly heroine rig tuned for Quest 3 (draw-call conscious).
 * Portrait texture mapped to the face plate for lifelike identity.
 */
export function createHeroineMesh(def, textureLoader) {
  const root = new THREE.Group();
  root.name = def.name;
  const h = def.height;

  const skin = skinMaterial(def.skin);
  const outfit = clothMaterial(def.outfit);
  const secondary = clothMaterial(def.secondary);
  const accent = clothMaterial(def.accent, {
    emissive: def.accent,
    emissiveIntensity: 0.18,
    metalness: 0.35,
    roughness: 0.35,
  });
  const hairMat = clothMaterial(def.hair, { roughness: 0.55 });

  // --- Legs ---
  const legGeo = new THREE.CapsuleGeometry(0.055 * h, 0.28 * h, 6, 10);
  const legL = new THREE.Mesh(legGeo, skin);
  legL.position.set(-0.07 * h, 0.22 * h, 0);
  legL.castShadow = true;
  const legR = legL.clone();
  legR.position.x = 0.07 * h;
  root.add(legL, legR);

  const bootL = new THREE.Mesh(
    new THREE.BoxGeometry(0.1 * h, 0.08 * h, 0.16 * h),
    secondary
  );
  bootL.position.set(-0.07 * h, 0.04 * h, 0.02 * h);
  const bootR = bootL.clone();
  bootR.position.x = 0.07 * h;
  root.add(bootL, bootR);

  // --- Hips / torso ---
  const hips = new THREE.Mesh(
    new THREE.SphereGeometry(0.12 * h, 16, 12),
    outfit
  );
  hips.scale.set(1.15, 0.75, 0.85);
  hips.position.y = 0.42 * h;
  hips.castShadow = true;
  root.add(hips);

  const torso = new THREE.Mesh(
    new THREE.CapsuleGeometry(0.11 * h, 0.22 * h, 8, 12),
    outfit
  );
  torso.position.y = 0.62 * h;
  torso.castShadow = true;
  root.add(torso);

  const chest = new THREE.Mesh(
    new THREE.SphereGeometry(0.1 * h, 14, 12),
    outfit
  );
  chest.scale.set(1.35, 0.7, 0.85);
  chest.position.y = 0.72 * h;
  root.add(chest);

  // Accent belt / plating
  const belt = new THREE.Mesh(
    new THREE.TorusGeometry(0.12 * h, 0.018 * h, 8, 20),
    accent
  );
  belt.rotation.x = Math.PI / 2;
  belt.position.y = 0.5 * h;
  root.add(belt);

  // --- Arms ---
  const armGeo = new THREE.CapsuleGeometry(0.04 * h, 0.22 * h, 6, 10);
  const armL = new THREE.Mesh(armGeo, skin);
  armL.position.set(-0.18 * h, 0.68 * h, 0);
  armL.castShadow = true;
  const armR = armL.clone();
  armR.position.x = 0.18 * h;
  root.add(armL, armR);

  const gloveL = new THREE.Mesh(
    new THREE.SphereGeometry(0.045 * h, 10, 8),
    accent
  );
  gloveL.position.set(-0.18 * h, 0.5 * h, 0);
  const gloveR = gloveL.clone();
  gloveR.position.x = 0.18 * h;
  root.add(gloveL, gloveR);

  // --- Neck / head ---
  const neck = new THREE.Mesh(
    new THREE.CylinderGeometry(0.035 * h, 0.04 * h, 0.06 * h, 10),
    skin
  );
  neck.position.y = 0.88 * h;
  root.add(neck);

  const head = new THREE.Mesh(
    new THREE.SphereGeometry(0.11 * h, 20, 16),
    skin
  );
  head.position.y = 0.98 * h;
  head.castShadow = true;
  root.add(head);

  // Face plate with portrait
  const faceGeo = new THREE.PlaneGeometry(0.14 * h, 0.16 * h);
  let faceMat;
  if (textureLoader && def.portrait) {
    const tex = textureLoader.load(def.portrait);
    tex.colorSpace = THREE.SRGBColorSpace;
    faceMat = new THREE.MeshBasicMaterial({
      map: tex,
      transparent: true,
    });
  } else {
    faceMat = new THREE.MeshStandardMaterial({ color: def.skin });
  }
  const face = new THREE.Mesh(faceGeo, faceMat);
  face.position.set(0, 0.99 * h, 0.095 * h);
  root.add(face);

  // Eyes glow accents
  const eyeGeo = new THREE.SphereGeometry(0.012 * h, 8, 8);
  const eyeMat = new THREE.MeshStandardMaterial({
    color: def.eye,
    emissive: def.eye,
    emissiveIntensity: 0.8,
  });
  const eyeL = new THREE.Mesh(eyeGeo, eyeMat);
  eyeL.position.set(-0.035 * h, 1.0 * h, 0.1 * h);
  const eyeR = eyeL.clone();
  eyeR.position.x = 0.035 * h;
  root.add(eyeL, eyeR);

  // Hair
  addHair(root, def, hairMat, h);

  // Hit flash
  const hitFlash = new THREE.Mesh(
    new THREE.SphereGeometry(0.28 * h, 12, 12),
    new THREE.MeshBasicMaterial({
      color: 0xffffff,
      transparent: true,
      opacity: 0,
      depthWrite: false,
    })
  );
  hitFlash.position.y = 0.65 * h;
  root.add(hitFlash);

  // Blood drip decals (opacity driven in combat)
  const bloodDecal = new THREE.Mesh(
    new THREE.PlaneGeometry(0.12 * h, 0.18 * h),
    new THREE.MeshBasicMaterial({
      color: 0x8b0000,
      transparent: true,
      opacity: 0,
      depthWrite: false,
    })
  );
  bloodDecal.position.set(0.04 * h, 0.7 * h, 0.12 * h);
  root.add(bloodDecal);

  return {
    root,
    armL,
    armR,
    legL,
    legR,
    hitFlash,
    bloodDecal,
    head,
    torso,
  };
}

function addHair(root, def, hairMat, h) {
  const y = 1.05 * h;
  const style = def.hairStyle;

  const scalp = new THREE.Mesh(
    new THREE.SphereGeometry(0.115 * h, 16, 12),
    hairMat
  );
  scalp.scale.set(1.05, 0.85, 1.05);
  scalp.position.y = y - 0.02 * h;
  root.add(scalp);

  if (style === "ponytail") {
    const tail = new THREE.Mesh(
      new THREE.CapsuleGeometry(0.04 * h, 0.28 * h, 6, 8),
      hairMat
    );
    tail.position.set(0, 0.85 * h, -0.12 * h);
    tail.rotation.x = 0.5;
    root.add(tail);
    const streak = new THREE.Mesh(
      new THREE.CapsuleGeometry(0.015 * h, 0.2 * h, 4, 6),
      clothMaterial(def.accent)
    );
    streak.position.copy(tail.position);
    streak.position.x = 0.03 * h;
    streak.rotation.copy(tail.rotation);
    root.add(streak);
  } else if (style === "undercut") {
    const fringe = new THREE.Mesh(
      new THREE.BoxGeometry(0.18 * h, 0.06 * h, 0.08 * h),
      hairMat
    );
    fringe.position.set(0, 1.04 * h, 0.08 * h);
    root.add(fringe);
  } else if (style === "braids" || style === "locs" || style === "coils") {
    for (let i = 0; i < 5; i++) {
      const braid = new THREE.Mesh(
        new THREE.CapsuleGeometry(0.025 * h, 0.22 * h, 4, 6),
        hairMat
      );
      const a = (i / 5) * Math.PI * 1.2 - 0.6;
      braid.position.set(Math.sin(a) * 0.1 * h, 0.82 * h, -0.08 * h + Math.cos(a) * 0.05);
      braid.rotation.x = 0.35;
      root.add(braid);
    }
  } else if (style === "pixie") {
    const top = new THREE.Mesh(
      new THREE.SphereGeometry(0.08 * h, 12, 10),
      hairMat
    );
    top.scale.set(1.2, 0.6, 1.1);
    top.position.set(0, 1.06 * h, 0);
    root.add(top);
    const tip = new THREE.Mesh(
      new THREE.BoxGeometry(0.06 * h, 0.04 * h, 0.04 * h),
      clothMaterial(def.accent)
    );
    tip.position.set(0.05 * h, 1.08 * h, 0.02 * h);
    root.add(tip);
  } else if (style === "bob") {
    const bob = new THREE.Mesh(
      new THREE.SphereGeometry(0.13 * h, 14, 12),
      hairMat
    );
    bob.scale.set(1.1, 0.7, 1.0);
    bob.position.set(0, 0.95 * h, -0.02 * h);
    root.add(bob);
  } else if (style === "curls" || style === "wave" || style === "long") {
    for (let i = 0; i < 6; i++) {
      const lock = new THREE.Mesh(
        new THREE.CapsuleGeometry(0.035 * h, 0.32 * h, 5, 8),
        hairMat
      );
      const a = (i / 6) * Math.PI * 2;
      lock.position.set(Math.sin(a) * 0.1 * h, 0.78 * h, Math.cos(a) * 0.08 * h - 0.04);
      lock.rotation.z = Math.sin(a) * 0.25;
      lock.rotation.x = 0.2;
      root.add(lock);
    }
  }
}
