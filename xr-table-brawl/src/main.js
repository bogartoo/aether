import * as THREE from "three";
import { ROSTER, STOCKS, getFighter } from "./roster.js";
import {
  createFighterState,
  resetFighter,
  updateFighter,
  isBlasted,
} from "./fighter.js";
import { createDesktopStage, buildTable } from "./stage.js";
import { bindKeyboard, createInputSystem } from "./input.js";
import { createBloodSystem } from "./blood.js";

const canvas = document.getElementById("game");
const boot = document.getElementById("boot");
const selectScreen = document.getElementById("select");
const hud = document.getElementById("hud");
const toastEl = document.getElementById("toast");
const modeLabel = document.getElementById("mode-label");
const inputLabel = document.getElementById("input-label");
const loreEl = document.getElementById("lore-panel");
const xrHint = document.getElementById("xr-hint");
const rosterGrid = document.getElementById("roster-grid");

const btnContinue = document.getElementById("btn-continue");
const btnDesktop = document.getElementById("btn-desktop");
const btnVsAi = document.getElementById("btn-vs-ai");
const btnXr = document.getElementById("btn-xr");
const btnReset = document.getElementById("btn-reset");
const btnExit = document.getElementById("btn-exit");

const renderer = new THREE.WebGLRenderer({
  canvas,
  antialias: true,
  alpha: true,
  powerPreference: "high-performance",
});
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.setSize(innerWidth, innerHeight);
renderer.shadowMap.enabled = true;
renderer.xr.enabled = true;
renderer.setClearColor(0x000000, 0);
renderer.outputColorSpace = THREE.SRGBColorSpace;

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(60, innerWidth / innerHeight, 0.05, 80);
camera.position.set(0, 1.55, 3.2);

scene.add(new THREE.HemisphereLight(0xddeeff, 0x2a1810, 0.9));
const keyLight = new THREE.DirectionalLight(0xfff1dd, 1.2);
keyLight.position.set(2.4, 5, 3);
keyLight.castShadow = true;
keyLight.shadow.mapSize.set(1024, 1024);
scene.add(keyLight);
const fillLight = new THREE.DirectionalLight(0x88ffcc, 0.35);
fillLight.position.set(-3, 2, -1);
scene.add(fillLight);

const textureLoader = new THREE.TextureLoader();
const inputSystem = createInputSystem();
const blood = createBloodSystem(scene);
bindKeyboard();

let mode = null;
let vsAi = false;
let stagePack = null;
let table = null;
let fighters = [];
let running = false;
let toastTimer = 0;
const clock = new THREE.Clock(false);
const xrRefs = {};
let placePending = false;
let reticle = null;
let hitTestSource = null;
const picks = { p1: ROSTER[0].id, p2: ROSTER[1].id };
let pickSlot = "p1";

function adaptTable(src) {
  return {
    topY: src.topY,
    halfW: src.halfW,
    halfD: src.halfD,
    center: {
      x: src.center?.x ?? 0,
      y: src.center?.y ?? 0,
      z: src.center?.z ?? 0,
    },
  };
}

function spawnPoints(t) {
  return [
    { x: t.center.x - t.halfW * 0.45, y: t.topY, z: t.center.z },
    { x: t.center.x + t.halfW * 0.45, y: t.topY, z: t.center.z },
  ];
}

function showToast(msg, ms = 1200) {
  toastEl.textContent = msg;
  toastEl.classList.remove("hidden");
  toastTimer = ms / 1000;
}

function clearMatch() {
  for (const f of fighters) scene.remove(f.mesh.root);
  fighters = [];
  if (stagePack?.group) scene.remove(stagePack.group);
  if (reticle) {
    scene.remove(reticle);
    reticle = null;
  }
  stagePack = null;
  table = null;
  placePending = false;
  hitTestSource = null;
}

function spawnFighters() {
  for (const f of fighters) scene.remove(f.mesh.root);
  const pts = spawnPoints(table);
  const defs = [getFighter(picks.p1), getFighter(picks.p2)];
  fighters = defs.map((def, side) => {
    const f = createFighterState(def, side, pts[side], textureLoader);
    scene.add(f.mesh.root);
    return f;
  });
  updateHud();
}

function updateHud() {
  for (let i = 0; i < 2; i++) {
    const f = fighters[i];
    if (!f) continue;
    document.getElementById(`p${i + 1}-name`).textContent = f.def.name;
    document.getElementById(`p${i + 1}-pct`).textContent = `${Math.floor(f.percent)}%`;
    const stockEl = document.getElementById(`p${i + 1}-stocks`);
    stockEl.innerHTML = "";
    stockEl.style.color = i === 0 ? "#b8ff3c" : "#ff5a36";
    for (let s = 0; s < STOCKS; s++) {
      const pip = document.createElement("span");
      pip.className = "stock-pip" + (s < f.stocks ? "" : " empty");
      stockEl.appendChild(pip);
    }
    const img = document.getElementById(`p${i + 1}-portrait`);
    if (img) img.src = f.def.portrait;
  }
}

function onCombatEvent(type, payload) {
  if (type === "hit" && payload?.blood) {
    blood.spawn(payload.origin, payload.dir, Math.min(2.2, payload.knock / 8));
  }
}

function handleKO(f) {
  f.stocks -= 1;
  if (f.stocks <= 0) {
    f.alive = false;
    f.mesh.root.visible = false;
    const winner = fighters.find((o) => o !== f && o.stocks > 0);
    showToast(winner ? `${winner.def.name} WINS` : "DRAW", 2400);
    updateHud();
    return;
  }
  resetFighter(f, spawnPoints(table)[f.side]);
  showToast("KO!");
  updateHud();
}

function simpleAi(me, foe) {
  const out = {
    move: 0,
    moveY: 0,
    jump: false,
    attack: false,
    special: false,
    smash: false,
    smashHold: false,
    climb: false,
    dodge: false,
  };
  if (!me?.alive || !foe?.alive) return out;
  if (me.hanging) {
    out.climb = Math.random() < 0.05;
    return out;
  }
  const dx = foe.x - me.x;
  const dist = Math.abs(dx);
  if (dist > 0.55) out.move = Math.sign(dx);
  else if (dist < 0.28) out.move = -Math.sign(dx);
  if (dist < 0.65 && Math.random() < 0.05) out.attack = true;
  if (dist > 0.4 && dist < 1.0 && Math.random() < 0.012) out.special = true;
  if (dist < 0.9 && Math.random() < 0.01) {
    out.smash = true;
    out.smashHold = true;
  }
  if (me.onGround && Math.random() < 0.008) out.jump = true;
  if (!me.onGround && me.vy < 0 && Math.random() < 0.03) out.jump = true;
  return out;
}

function tick(dt) {
  if (!running || !table) return;
  if (toastTimer > 0) {
    toastTimer -= dt;
    if (toastTimer <= 0) toastEl.classList.add("hidden");
  }

  const sample = inputSystem.sample({
    mode: mode === "xr" ? "xr" : "flat",
    frame: xrRefs.lastFrame,
    session: renderer.xr.getSession?.() || null,
    xrRefs,
  });
  inputLabel.textContent = sample.source || "Keyboard";

  let p2 = sample.p2;
  if (
    vsAi ||
    (mode === "xr" && Math.abs(p2.move) < 0.05 && !p2.attack && !p2.jump)
  ) {
    p2 = simpleAi(fighters[1], fighters[0]);
  }

  updateFighter(fighters[0], sample.p1, table, dt, fighters[1], onCombatEvent);
  updateFighter(fighters[1], p2, table, dt, fighters[0], onCombatEvent);

  for (const f of fighters) {
    if (f.alive && isBlasted(f, table)) handleKO(f);
  }
  blood.update(dt, 0);
  updateHud();
}

function updateDesktopCamera(dt) {
  if (mode !== "desktop" || fighters.length < 2) return;
  const midX = (fighters[0].x + fighters[1].x) / 2;
  const midY = (fighters[0].y + fighters[1].y) / 2;
  const target = new THREE.Vector3(
    midX * 0.35,
    Math.max(1.15, midY + 0.55),
    3.15
  );
  camera.position.lerp(target, 1 - Math.exp(-3 * dt));
  camera.lookAt(midX * 0.2, 0.85, 0);
}

function startDesktop(ai = false) {
  clearMatch();
  vsAi = ai;
  mode = "desktop";
  modeLabel.textContent = ai ? "DESKTOP · VS AI" : "DESKTOP SIM";
  renderer.setClearColor(0x0c1210, 1);
  stagePack = createDesktopStage(scene);
  table = adaptTable(stagePack.table);
  camera.position.set(0, 1.55, 3.1);
  camera.lookAt(0, 0.9, 0);
  spawnFighters();
  boot.classList.add("hidden");
  selectScreen.classList.add("hidden");
  hud.classList.remove("hidden");
  running = true;
  clock.start();
  showToast("FIGHT!");
}

async function startXr() {
  if (!navigator.xr) {
    xrHint.textContent =
      "WebXR missing — use desktop sim, or open in Meta Quest Browser.";
    return;
  }
  const ok = await navigator.xr.isSessionSupported("immersive-ar");
  if (!ok) {
    xrHint.textContent =
      "Immersive AR unsupported here. Desktop sim works; Quest Browser for pass-through.";
    return;
  }

  clearMatch();
  vsAi = true;
  mode = "xr";
  modeLabel.textContent = "QUEST · PASS-THROUGH";
  renderer.setClearColor(0x000000, 0);

  const session = await navigator.xr.requestSession("immersive-ar", {
    requiredFeatures: ["local-floor"],
    optionalFeatures: ["hit-test", "dom-overlay"],
    domOverlay: { root: document.body },
  });
  session.addEventListener("end", () => {
    running = false;
    clearMatch();
    hud.classList.add("hidden");
    boot.classList.remove("hidden");
    mode = null;
  });
  await renderer.xr.setSession(session);

  reticle = new THREE.Mesh(
    new THREE.RingGeometry(0.08, 0.1, 32).rotateX(-Math.PI / 2),
    new THREE.MeshBasicMaterial({ color: 0xb8ff3c })
  );
  reticle.matrixAutoUpdate = false;
  reticle.visible = false;
  scene.add(reticle);
  placePending = true;

  try {
    const viewerSpace = await session.requestReferenceSpace("viewer");
    hitTestSource = await session.requestHitTestSource({ space: viewerSpace });
  } catch {
    placeXrTable(new THREE.Vector3(0, 0.75, -1.2));
    placePending = false;
  }

  boot.classList.add("hidden");
  selectScreen.classList.add("hidden");
  hud.classList.remove("hidden");
  running = true;
  clock.start();
  showToast(placePending ? "POINT AT TABLE · TRIGGER" : "FIGHT!");

  session.addEventListener("select", () => {
    if (placePending && reticle?.visible) {
      const pos = new THREE.Vector3().setFromMatrixPosition(reticle.matrix);
      placeXrTable(pos);
      placePending = false;
      reticle.visible = false;
      showToast("FIGHT!");
    }
  });
}

function placeXrTable(position) {
  const built = buildTable({
    width: 2.0,
    depth: 0.95,
    height: 0.02,
    thickness: 0.05,
  });
  built.group.position.copy(position);
  for (const child of built.group.children) {
    child.position.y -= built.topY - built.thickness / 2;
  }
  scene.add(built.group);
  stagePack = { group: built.group, table: built };
  table = {
    topY: position.y + built.thickness / 2,
    halfW: built.halfW,
    halfD: built.halfD,
    center: { x: position.x, y: position.y, z: position.z },
  };
  spawnFighters();
}

function exitGame() {
  if (renderer.xr.isPresenting) {
    renderer.xr.getSession()?.end();
    return;
  }
  running = false;
  clearMatch();
  hud.classList.add("hidden");
  selectScreen.classList.add("hidden");
  boot.classList.remove("hidden");
  mode = null;
  renderer.setClearColor(0x000000, 0);
}

function buildRosterUI() {
  rosterGrid.innerHTML = "";
  for (const hero of ROSTER) {
    const card = document.createElement("button");
    card.type = "button";
    card.className = "roster-card";
    card.dataset.id = hero.id;
    card.innerHTML = `
      <img src="${hero.portrait}" alt="${hero.name}" />
      <span class="card-name">${hero.name}</span>
      <span class="card-title">${hero.title}</span>
    `;
    card.addEventListener("click", () => {
      picks[pickSlot] = hero.id;
      refreshPickState();
      loreEl.innerHTML = `<strong>${hero.name}</strong> — ${hero.title}<p>${hero.lore}</p><em>${hero.style}</em>`;
    });
    rosterGrid.appendChild(card);
  }
  refreshPickState();
  const first = ROSTER[0];
  loreEl.innerHTML = `<strong>${first.name}</strong> — ${first.title}<p>${first.lore}</p><em>${first.style}</em>`;
}

function refreshPickState() {
  document.getElementById("pick-p1").textContent = getFighter(picks.p1).name;
  document.getElementById("pick-p2").textContent = getFighter(picks.p2).name;
  document.getElementById("slot-p1").classList.toggle("active", pickSlot === "p1");
  document.getElementById("slot-p2").classList.toggle("active", pickSlot === "p2");
  for (const card of rosterGrid.querySelectorAll(".roster-card")) {
    card.classList.toggle("selected-p1", card.dataset.id === picks.p1);
    card.classList.toggle("selected-p2", card.dataset.id === picks.p2);
  }
}

document.getElementById("slot-p1").addEventListener("click", () => {
  pickSlot = "p1";
  refreshPickState();
});
document.getElementById("slot-p2").addEventListener("click", () => {
  pickSlot = "p2";
  refreshPickState();
});

btnContinue.addEventListener("click", () => {
  boot.classList.add("hidden");
  selectScreen.classList.remove("hidden");
});
btnDesktop.addEventListener("click", () => startDesktop(false));
btnVsAi.addEventListener("click", () => startDesktop(true));
btnXr.addEventListener("click", () => {
  startXr().catch((err) => {
    console.error(err);
    xrHint.textContent = err?.message || "Failed to start AR session.";
  });
});
btnReset.addEventListener("click", () => {
  if (!table) return;
  const pts = spawnPoints(table);
  fighters.forEach((f, i) => {
    f.stocks = STOCKS;
    resetFighter(f, pts[i]);
  });
  updateHud();
  showToast("FIGHT!");
});
btnExit.addEventListener("click", exitGame);

async function probeXr() {
  if (!navigator.xr) {
    xrHint.textContent =
      "No WebXR here — keyboard / Xbox / DualSense work on desktop. Open in Meta Quest Browser for pass-through AR.";
    return;
  }
  try {
    const ar = await navigator.xr.isSessionSupported("immersive-ar");
    if (ar) {
      btnXr.disabled = false;
      xrHint.textContent =
        "Quest AR ready. Stick move · trigger attack · grip special · A jump · B smash.";
    } else {
      xrHint.textContent =
        "WebXR found, but not immersive AR. Use desktop sim; Quest Browser for pass-through.";
    }
  } catch {
    xrHint.textContent = "Could not query WebXR. Desktop sim is available.";
  }
}

buildRosterUI();
probeXr();

addEventListener("resize", () => {
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
});

renderer.setAnimationLoop((_t, frame) => {
  const dt = Math.min(clock.getDelta(), 0.05);
  xrRefs.lastFrame = frame;
  if (mode === "xr" && placePending && frame && hitTestSource && reticle) {
    const hits = frame.getHitTestResults(hitTestSource);
    if (hits.length) {
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
});
