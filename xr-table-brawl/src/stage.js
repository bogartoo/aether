import * as THREE from "three";

/**
 * Build a wooden table stage + optional room for desktop sim.
 */
export function createDesktopStage(scene) {
  const stage = new THREE.Group();
  stage.name = "desktopStage";

  // Floor / room
  const floor = new THREE.Mesh(
    new THREE.PlaneGeometry(14, 14),
    new THREE.MeshStandardMaterial({ color: 0x1a2220, roughness: 0.95 })
  );
  floor.rotation.x = -Math.PI / 2;
  floor.position.y = 0;
  floor.receiveShadow = true;
  stage.add(floor);

  // Wall with soft window light suggestion
  const wall = new THREE.Mesh(
    new THREE.PlaneGeometry(14, 6),
    new THREE.MeshStandardMaterial({ color: 0x24302c, roughness: 0.9 })
  );
  wall.position.set(0, 3, -5);
  stage.add(wall);

  const windowGlow = new THREE.Mesh(
    new THREE.PlaneGeometry(3.2, 2.2),
    new THREE.MeshBasicMaterial({ color: 0x7ec8ff, transparent: true, opacity: 0.15 })
  );
  windowGlow.position.set(-2.2, 2.6, -4.98);
  stage.add(windowGlow);

  const table = buildTable({ width: 2.4, depth: 1.1, height: 0.78, thickness: 0.06 });
  table.group.position.set(0, 0, 0);
  stage.add(table.group);

  // Edge highlight strips so ledge reads clearly
  const edgeMat = new THREE.MeshBasicMaterial({
    color: 0xb8ff3c,
    transparent: true,
    opacity: 0.35,
  });
  for (const side of [-1, 1]) {
    const strip = new THREE.Mesh(new THREE.BoxGeometry(0.04, 0.02, table.depth), edgeMat);
    strip.position.set(side * table.halfW, table.topY + 0.01, 0);
    stage.add(strip);
  }

  scene.add(stage);

  return {
    group: stage,
    table,
    mode: "desktop",
  };
}

export function buildTable({ width, depth, height, thickness }) {
  const group = new THREE.Group();
  const halfW = width / 2;
  const halfD = depth / 2;
  const topY = height;

  const wood = new THREE.MeshStandardMaterial({
    color: 0x6b3f2a,
    roughness: 0.75,
    metalness: 0.05,
  });
  const woodDark = new THREE.MeshStandardMaterial({
    color: 0x3d2418,
    roughness: 0.85,
  });

  const top = new THREE.Mesh(new THREE.BoxGeometry(width, thickness, depth), wood);
  top.position.y = topY - thickness / 2;
  top.castShadow = true;
  top.receiveShadow = true;
  group.add(top);

  // Subtle grain lines
  const grain = new THREE.Mesh(
    new THREE.PlaneGeometry(width * 0.92, depth * 0.85),
    new THREE.MeshBasicMaterial({
      color: 0x8a5538,
      transparent: true,
      opacity: 0.25,
    })
  );
  grain.rotation.x = -Math.PI / 2;
  grain.position.y = topY + 0.001;
  group.add(grain);

  const legGeom = new THREE.BoxGeometry(0.08, height - thickness, 0.08);
  const legPositions = [
    [-halfW + 0.12, (height - thickness) / 2, -halfD + 0.12],
    [halfW - 0.12, (height - thickness) / 2, -halfD + 0.12],
    [-halfW + 0.12, (height - thickness) / 2, halfD - 0.12],
    [halfW - 0.12, (height - thickness) / 2, halfD - 0.12],
  ];
  for (const [x, y, z] of legPositions) {
    const leg = new THREE.Mesh(legGeom, woodDark);
    leg.position.set(x, y, z);
    leg.castShadow = true;
    group.add(leg);
  }

  return {
    group,
    width,
    depth,
    height,
    thickness,
    halfW,
    halfD,
    topY,
    center: new THREE.Vector3(0, 0, 0),
  };
}

/** Update table center after placing in XR */
export function tableFromPlacement(mesh, width = 2.2, depth = 1.0, height = 0.75) {
  const center = new THREE.Vector3();
  mesh.getWorldPosition(center);
  // mesh origin at table top center
  return {
    group: mesh,
    width,
    depth,
    height,
    halfW: width / 2,
    halfD: depth / 2,
    topY: center.y,
    center: { x: center.x, y: center.y, z: center.z },
  };
}

export function syncTableCenter(table) {
  if (!table.group) return;
  const world = new THREE.Vector3();
  table.group.getWorldPosition(world);
  // If group origin is at floor under table, topY = world.y + height
  // Desktop stage: table.group at 0,0,0 and topY is absolute height
  table.center.x = world.x;
  table.center.z = world.z;
}
