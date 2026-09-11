/**
 * Quest 3 controllers first, then Xbox / PlayStation via Gamepad API.
 * Keyboard remains for desktop sim.
 */

const keys = new Set();

export function bindKeyboard() {
  window.addEventListener("keydown", (e) => {
    keys.add(e.code);
    if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Space"].includes(e.code)) {
      e.preventDefault();
    }
  });
  window.addEventListener("keyup", (e) => keys.delete(e.code));
  window.addEventListener("blur", () => keys.clear());
}

function down(code) {
  return keys.has(code);
}

function edgeStore() {
  return {
    p1: { jump: false, attack: false, special: false, smash: false, climb: false, dodge: false },
    p2: { jump: false, attack: false, special: false, smash: false, climb: false, dodge: false },
  };
}

export function createInputSystem() {
  const prevKey = edgeStore();
  const prevPad = edgeStore();
  const prevXr = edgeStore();

  function edgeify(raw, prev) {
    const out = {
      move: raw.move,
      moveY: raw.moveY || 0,
      jump: raw.jump && !prev.jump,
      attack: raw.attack && !prev.attack,
      special: raw.special && !prev.special,
      smash: raw.smash && !prev.smash,
      climb: raw.climb && !prev.climb,
      dodge: raw.dodge && !prev.dodge,
      smashHold: !!raw.smashHold,
    };
    prev.jump = !!raw.jump;
    prev.attack = !!raw.attack;
    prev.special = !!raw.special;
    prev.smash = !!raw.smash;
    prev.climb = !!raw.climb;
    prev.dodge = !!raw.dodge;
    return out;
  }

  function sampleKeyboard() {
    const p1Raw = {
      move: (down("KeyD") ? 1 : 0) - (down("KeyA") ? 1 : 0),
      moveY: (down("KeyW") ? 1 : 0) - (down("KeyS") ? 1 : 0),
      jump: down("KeyL") || down("Space") || down("KeyW"),
      attack: down("KeyJ"),
      special: down("KeyK"),
      smash: down("KeyU"),
      smashHold: down("KeyU"),
      climb: down("KeyI"),
      dodge: down("KeyO"),
    };
    const p2Raw = {
      move: (down("ArrowRight") ? 1 : 0) - (down("ArrowLeft") ? 1 : 0),
      moveY: (down("ArrowUp") ? 1 : 0) - (down("ArrowDown") ? 1 : 0),
      jump: down("Digit3") || down("ArrowUp"),
      attack: down("Digit1"),
      special: down("Digit2"),
      smash: down("Digit4"),
      smashHold: down("Digit4"),
      climb: down("Digit5"),
      dodge: down("Digit6"),
    };
    return {
      p1: edgeify(p1Raw, prevKey.p1),
      p2: edgeify(p2Raw, prevKey.p2),
      source: "keyboard",
    };
  }

  /**
   * Standard Gamepad mapping (Xbox + most DualSense / DualShock via browser):
   * axes 0/1 left stick, buttons: 0 A/X, 1 B/O, 2 X/□, 3 Y/△,
   * 4 LB, 5 RB, 6 LT, 7 RT, 9 menu...
   */
  function readPad(pad) {
    if (!pad) return null;
    const a = pad.axes || [];
    const b = pad.buttons || [];
    const dead = (v) => (Math.abs(v) < 0.18 ? 0 : Math.max(-1, Math.min(1, v)));
    const pressed = (i) => !!(b[i] && (b[i].pressed || b[i].value > 0.4));
    const value = (i) => (b[i] ? b[i].value || (b[i].pressed ? 1 : 0) : 0);

    // Face: A/Cross jump, B/Circle dodge, X/Square attack, Y/Triangle special
    // RT smash / heavy, LT shield-ish dodge, RB smash alternate
    return {
      move: dead(a[0] || 0),
      moveY: dead(-(a[1] || 0)),
      jump: pressed(0),
      attack: pressed(2) || value(7) > 0.5,
      special: pressed(3),
      smash: pressed(5) || pressed(1) === false && value(7) > 0.85,
      smashHold: value(7) > 0.55 || pressed(5),
      climb: pressed(0) || pressed(3),
      dodge: pressed(1) || value(6) > 0.45,
      id: pad.id || "gamepad",
    };
  }

  function sampleGamepads() {
    const pads = (navigator.getGamepads?.() || []).filter(Boolean);
    if (!pads.length) return null;

    // Prefer pairing: first pad P1, second P2
    // Detect Xbox / PlayStation from id string for HUD label
    const classify = (id = "") => {
      const s = id.toLowerCase();
      if (s.includes("xbox") || s.includes("xinput") || s.includes("045e")) return "Xbox";
      if (
        s.includes("dualsense") ||
        s.includes("dualshock") ||
        s.includes("playstation") ||
        s.includes("054c") ||
        s.includes("sony")
      ) {
        return "PlayStation";
      }
      return "Gamepad";
    };

    const p1Pad = readPad(pads[0]);
    const p2Pad = readPad(pads[1]);
    if (!p1Pad) return null;

    return {
      p1: edgeify(p1Pad, prevPad.p1),
      p2: p2Pad
        ? edgeify(p2Pad, prevPad.p2)
        : {
            move: 0,
            moveY: 0,
            jump: false,
            attack: false,
            special: false,
            smash: false,
            climb: false,
            dodge: false,
            smashHold: false,
          },
      source: classify(pads[0].id) + (pads[1] ? ` + ${classify(pads[1].id)}` : ""),
      padsConnected: pads.length,
    };
  }

  function sampleXr(frame, session, refs) {
    const empty = {
      move: 0,
      moveY: 0,
      jump: false,
      attack: false,
      special: false,
      smash: false,
      climb: false,
      dodge: false,
      smashHold: false,
    };
    if (!session) return { p1: empty, p2: empty, source: "Quest" };

    const sources = [...session.inputSources];
    const left = sources.find((s) => s.handedness === "left");
    const right = sources.find((s) => s.handedness === "right");

    const readXr = (src) => {
      if (!src?.gamepad) return { ...empty };
      const axes = src.gamepad.axes || [];
      const buttons = src.gamepad.buttons || [];
      // Quest 3: thumbstick often axes[2], axes[3]
      const ax = axes.length >= 4 ? axes[2] : axes[0] || 0;
      const ay = axes.length >= 4 ? axes[3] : axes[1] || 0;
      const dead = (v) => (Math.abs(v) < 0.15 ? 0 : v);
      const trigger = buttons[0]?.pressed || buttons[0]?.value > 0.5;
      const grip = buttons[1]?.pressed || buttons[1]?.value > 0.5;
      const stickBtn = buttons[3]?.pressed;
      // Quest: buttons[4] = A/X, buttons[5] = B/Y depending on hand
      const aBtn = buttons[4]?.pressed;
      const bBtn = buttons[5]?.pressed;
      return {
        move: dead(ax),
        moveY: dead(-ay),
        jump: !!aBtn,
        attack: !!trigger,
        special: !!grip,
        smash: !!bBtn,
        smashHold: !!bBtn,
        climb: !!aBtn || !!stickBtn,
        dodge: !!stickBtn,
      };
    };

    if (!refs.xrPrev) refs.xrPrev = edgeStore();
    const r = readXr(right);
    const l = readXr(left);
    return {
      p1: edgeify(r, refs.xrPrev.p1),
      p2: edgeify(l, refs.xrPrev.p2),
      source: "Quest 3",
      frame,
    };
  }

  return {
    /**
     * Priority: XR > Gamepads > Keyboard
     */
    sample({ mode, frame, session, xrRefs }) {
      if (mode === "xr") {
        return sampleXr(frame, session, xrRefs);
      }
      const pads = sampleGamepads();
      if (pads && pads.padsConnected > 0) {
        // Merge: if pad has no move, allow keyboard overlay for that player
        const kb = sampleKeyboard();
        if (Math.abs(pads.p1.move) < 0.05 && !pads.p1.attack && !pads.p1.jump) {
          pads.p1 = kb.p1;
        }
        if (Math.abs(pads.p2.move) < 0.05 && !pads.p2.attack && !pads.p2.jump) {
          pads.p2 = kb.p2;
        }
        return pads;
      }
      return sampleKeyboard();
    },
  };
}
