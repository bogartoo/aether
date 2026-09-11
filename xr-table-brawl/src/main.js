import * as THREE from "three";
import { FIGHTER_DEFS, STOCKS } from "./constants.js";
import {
  createFighterState,
  resetFighter,
  updateFighter,
  isBlasted,
  syncMesh,
} from "./fighter.js";
import { createDesktopStage, buildTable, tableFromPlacement } from "./stage.js";
import { bindKeyboard, createInputTracker, sampleXrInput } from "./input.js";

const canvas = document.getElementById("game");
const boot = document.getElementById("boot");
const hud = document.getElementById("hud");
const toastEl = document.getElementById("toast");
const modeLabel = document.getElementById("mode-label");
const btnDesktop = document.getElementById("btn-desktop");
const btnVsAi = document.getElementById("btn-vs-ai");
const btnXr = document.getElementById("btn-xr");
const btnReset = document.getElementById("btn-reset");
const btnExit = document.getElementById("btn-exit");
const xrHint = document.getElementById("xr-hint");
let vsAi = false;

const renderer = new THREE.WebGLRenderer({
  canvas,
  antialias: true,
  alpha: true,
  powerPreference: "high-performance",
});
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.shadowMap.enabled = true;
renderer.xr.enabled = true;
renderer.setClearColor(0x000000, 0);

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(
  60,
  window.innerWidth / window.innerHeight,
  0.05,
  100
);
camera.position.set(0, 1.6, 3.2);

const hemi = new THREE.HemisphereLight(0xddeeff, 0x332211, 0.85);
scene.add(hemi);
const keyLight = new THREE.DirectionalLight(0xfff2dd, 1.15);
keyLight.position.set(2.5, 5, 3);
keyLight.castShadow = true;
keyLight.shadow.mapSize.set(1024, 1024);
scene.add(keyLight);
const fill = new THREE.DirectionalLight(0x88ffaa, 0.35);
fill.position.set(-3, 2, -1);
scene.add(fill);

let mode = null; // 'desktop' | 'xr'
let stage = null;
let table = null;
let fighters = [];
let inputTracker = createInputTracker();
let xrRefs = {};
let clock = new THREE.Clock();
let running = false;
let toastTimer = 0;
let hitSource = null;
let placePending = false;
let xrTableMesh = null;
let reticle = null;
let hitTestSource = null;
let localSpace = null;

bindKeyboard();

function showToast(msg, ms = 1200) {
  toastEl.textContent = msg;
  toastEl.classList.remove("hidden");
  toastTimer = ms / 1000;
}

function updateHud() {
  for (let i = 0; i < 2; i++) {
    const f = fighters[i];
    document.getElementById(`p${i + 1}-name`).textContent = f.def.name;
    document.getElementById(`p${i + 1}-pct`).textContent = `${Math.floor(f.percent)}%`;
    const stocks = document.getElementById(`p${i + 1}-stocks`);
    stocks.innerHTML = "";
    stocks.style.color = i === 0 ? "#b8ff3c" : "#ff5a36";
    for (let s = 0; s < STOCKS; s++) {
      const pip = document.createElement("span");
      pip.className = "stock-pip" + (s < f.stocks ? "" : " empty");
      stocks.appendChild(pip);
    }
  }
}

function spawnsForTable(t) {
  return [
    { x: t.center.x - t.halfW * 0.45, y: t.topY, z: t.center.z },
    { x: t.center.x + t.halfW * 0.45, y: t.topY, z: t.center.z },
  ];
}

function spawnFighters() {
  // clear old
  for (const f of fighters) {
    scene.remove(f.mesh.root);
  }
  const spawns = spawnsForTable(table);
  fighters = FIGHTER_DEFS.map((def, i) => {
    const f = createFighterState(def, i, spawns[i]);
    scene.add(f.mesh.root);
    syncMesh(f);
    return f;
  });
  updateHud();
}

function resetMatch() {
  if (!table) return;
  const spawns = spawnsForTable(table);
  fighters.forEach((f, i) => {
    f.stocks = STOCKS;
    resetFighter(f, spawns[i]);
    syncMesh(f);
  });
  updateHud();
  showToast("FIGHT!");
}

function handleKO(f) {
  f.stocks -= 1;
  if (f.stocks <= 0) {
    f.alive = false;
    f.mesh.root.visible = false;
    const winner = fighters.find((o) => o !== f && o.stocks > 0);
    showToast(winner ? `${winner.def.name} WINS` : "DRAW", 2200);
    updateHud();
    return;
  }
  const spawns = spawnsForTable(table);
  resetFighter(f, spawns[f.side]);
  showToast("KO!");
  updateHud();
}

function onCombatEvent(type) {
  if (type === "hit") {
    // quick camera punch on desktop
    if (mode === "desktop") {
      camera.position.x += (Math.random() - 0.5) * 0.04;
    }
  }
  if (type === "ledge") {
    // subtle feedback only
  }
}

function tick(dt) {
  if (!running || !table) return;

  if (toastTimer > 0) {
    toastTimer -= dt;
    if (toastTimer <= 0) toastEl.classList.add("hidden");
  }

  let inputs;
  if (mode === "xr" && renderer.xr.isPresenting) {
    const session = renderer.xr.getSession();
    const frame = renderer.xr.getFrame?.() || null;
    // three r170: use last frame via animation loop arg — handled in animate
    inputs = sampleXrInput(xrRefs.lastFrame, session, xrRefs);
  } else {
    inputs = inputTracker.sample();
  }

  const p2Idle =
    Math.abs(inputs.p2.move) < 0.05 &&
    !inputs.p2.attack &&
    !inputs.p2.special &&
    !inputs.p2.jump &&
    !inputs.p2.climb;
  if (vsAi || (mode === "xr" && p2Idle)) {
    inputs.p2 = simpleAi(fighters[1], fighters[0], inputs.p2);
  }

  updateFighter(fighters[0], inputs.p1, table, dt, fighters[1], onCombatEvent);
  updateFighter(fighters[1], inputs.p2, table, dt, fighters[0], onCombatEvent);

  for (const f of fighters) {
    if (f.alive && isBlasted(f, table)) {
      handleKO(f);
    }
  }

  // Check win all dead
  updateHud();
}

function simpleAi(me, foe, base) {
  if (!me?.alive || !foe?.alive) return base;
  const dx = foe.x - me.x;
  const dist = Math.abs(dx);
  const out = {
    move: 0,
    jump: false,
    attack: false,
    special: false,
    climb: false,
  };
  if (me.hanging) {
    out.climb = Math.random() < 0.04;
    return out;
  }
  // Approach or maintain spacing
  if (dist > 0.5) out.move = Math.sign(dx);
  else if (dist < 0.28) out.move = -Math.sign(dx);
  else out.move = Math.sign(dx) * (Math.random() < 0.5 ? 1 : 0);

  if (dist < 0.6 && Math.random() < 0.045) out.attack = true;
  if (dist < 0.9 && dist > 0.35 && Math.random() < 0.012) out.special = true;
  if (me.onGround && Math.random() < 0.006) out.jump = true;
  if (!me.onGround && me.vy < 0 && me.y < table.topY + 0.3 && Math.random() < 0.03) {
    out.jump = true;
  }
  return out;
}

function clearStage() {
  if (stage?.group) scene.remove(stage.group);
  if (xrTableMesh) scene.remove(xrTableMesh);
  if (reticle) scene.remove(reticle);
  for (const f of fighters) scene.remove(f.mesh.root);
  fighters = [];
  stage = null;
  table = null;
  xrTableMesh = null;
  reticle = null;
  hitTestSource = null;
  placePending = false;
}

function startDesktop(ai = false) {
  clearStage();
  vsAi = ai;
  mode = "desktop";
  modeLabel.textContent = ai ? "DESKTOP · VS AI" : "DESKTOP SIM";
  renderer.setClearColor(0x0c1210, 1);
  stage = createDesktopStage(scene);
  table = {
    ...stage.table,
    center: { x: 0, y: 0, z: 0 },
    topY: stage.table.topY,
    halfW: stage.table.halfW,
    halfD: stage.table.halfD,
  };
  camera.position.set(0, 1.55, 3.1);
  camera.lookAt(0, 0.9, 0);
  spawnFighters();
  boot.classList.add("hidden");
  hud.classList.remove("hidden");
  running = true;
  clock.start();
  showToast("FIGHT!");
  canvas.focus?.();
}

async function startXr() {
  if (!navigator.xr) {
    showBootError("WebXR not available in this browser.");
    return;
  }
  const ok = await navigator.xr.isSessionSupported("immersive-ar");
  if (!ok) {
    showBootError("Immersive AR not supported. Use Quest Browser or play desktop sim.");
    return;
  }

  clearStage();
  mode = "xr";
  modeLabel.textContent = "AR PASS-THROUGH";
  renderer.setClearColor(0x000000, 0);

  const session = await navigator.xr.requestSession("immersive-ar", {
    requiredFeatures: ["local-floor"],
    optionalFeatures: ["hit-test", "dom-overlay", "layers"],
    domOverlay: { root: document.body },
  });

  session.addEventListener("end", () => {
    running = false;
    clearStage();
    hud.classList.add("hidden");
    boot.classList.remove("hidden");
    mode = null;
    renderer.setClearColor(0x000000, 0);
  });

  await renderer.xr.setSession(session);

  // Reticle for placement
  reticle = new THREE.Mesh(
    new THREE.RingGeometry(0.08, 0.1, 32).rotateX(-Math.PI / 2),
    new THREE.MeshBasicMaterial({ color: 0xb8ff3c })
  );
  reticle.matrixAutoUpdate = false;
  reticle.visible = false;
  scene.add(reticle);
  placePending = true;

  const refSpace = await session.requestReferenceSpace("local-floor");
  localSpace = refSpace;
  try {
    const viewerSpace = await session.requestReferenceSpace("viewer");
    hitTestSource = await session.requestHitTestSource({ space: viewerSpace });
  } catch {
    // Fallback: place table in front of user
    placeXrTable(new THREE.Vector3(0, 0.75, -1.2));
    placePending = false;
  }

  boot.classList.add("hidden");
  hud.classList.remove("hidden");
  running = true;
  clock.start();
  showToast(placePending ? "POINT AT TABLE · TAP TRIGGER" : "FIGHT!");

  session.addEventListener("select", () => {
    if (placePending && reticle.visible) {
      const pos = new THREE.Vector3();
      pos.setFromMatrixPosition(reticle.matrix);
      placeXrTable(pos);
      placePending = false;
      reticle.visible = false;
      showToast("FIGHT!");
    }
  });
}

function placeXrTable(position) {
  if (xrTableMesh) scene.remove(xrTableMesh);
  const built = buildTable({ width: 2.0, depth: 0.95, height: 0.02, thickness: 0.05 });
  // In XR, place thin platform at detected surface height (pass-through shows real table)
  xrTableMesh = built.group;
  xrTableMesh.position.copy(position);
  // Shift so top sits on hit point: buildTable topY = height, origin at floor of table group
  // Use flat slab centered on hit
  xrTableMesh.position.y = position.y;
  // Rebuild as surface slab: move top to y=0 relative
  xrTableMesh.children.forEach((c) => {
    c.position.y -= built.topY - built.thickness / 2;
  });
  scene.add(xrTableMesh);

  table = {
    group: xrTableMesh,
    halfW: built.halfW,
    halfD: built.halfD,
    topY: position.y + built.thickness / 2,
    center: { x: position.x, y: position.y, z: position.z },
    width: built.width,
    depth: built.depth,
  };
  spawnFighters();
}

function showBootError(msg) {
  xrHint.textContent = msg;
}

function exitGame() {
  if (renderer.xr.isPresenting) {
    renderer.xr.getSession()?.end();
    return;
  }
  running = false;
  clearStage();
  hud.classList.add("hidden");
  boot.classList.remove("hidden");
  mode = null;
  renderer.setClearColor(0x000000, 0);
}

btnDesktop.addEventListener("click", () => startDesktop(false));
btnVsAi.addEventListener("click", () => startDesktop(true));
btnXr.addEventListener("click", () => {
  startXr().catch((err) => {
    console.error(err);
    showBootError(err?.message || "Failed to start AR session.");
  });
});
btnReset.addEventListener("click", () => resetMatch());
btnExit.addEventListener("click", () => exitGame());

async function probeXr() {
  if (!navigator.xr) {
    xrHint.textContent =
      "WebXR unavailable here — use the desktop sim, or open on Meta Quest Browser for pass-through AR.";
    return;
  }
  try {
    const ar = await navigator.xr.isSessionSupported("immersive-ar");
    if (ar) {
      btnXr.disabled = false;
      xrHint.textContent =
        "AR ready. Enter pass-through, point at your table, tap trigger to plant the stage.";
    } else {
      xrHint.textContent =
        "This browser has WebXR but not immersive AR. Desktop sim works now; Quest Browser for pass-through.";
    }
  } catch {
    xrHint.textContent = "Could not query WebXR. Desktop sim is available.";
  }
}

probeXr();

window.addEventListener("resize", () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
});

// Desktop camera drift follow
function updateDesktopCamera(dt) {
  if (mode !== "desktop" || !fighters.length) return;
  const midX = (fighters[0].x + fighters[1].x) / 2;
  const midY = (fighters[0].y + fighters[1].y) / 2;
  const target = new THREE.Vector3(midX * 0.35, Math.max(1.2, midY + 0.6), 3.1);
  camera.position.lerp(target, 1 - Math.exp(-3 * dt));
  camera.lookAt(midX * 0.2, 0.85, 0);
}

function animate(_time, frame) {
  const dt = Math.min(clock.getDelta(), 0.05);
  xrRefs.lastFrame = frame;

  if (mode === "xr" && placePending && frame && hitTestSource && reticle) {
    const hits = frame.getHitTestResults(hitTestSource);
    if (hits.length && localSpace) {
      const pose = hits[0].getPose(renderer.xr.getReferenceSpace());
      if (pose) {
        reticle.visible = true;
        reticle.matrix.fromArray(pose.transform.matrix);
      }
    } else {
      reticle.visible = false;
    }
  }

  if (running) {
    tick(dt);
    updateDesktopCamera(dt);
  }

  renderer.render(scene, camera);
}

renderer.setAnimationLoop(animate);

// Unused import guard
void tableFromPlacement;
