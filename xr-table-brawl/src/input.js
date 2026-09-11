/** Keyboard + XR controller input */

const keys = new Set();

export function bindKeyboard() {
  window.addEventListener("keydown", (e) => {
    keys.add(e.code);
    // prevent page scroll for game keys
    if (
      ["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Space"].includes(e.code)
    ) {
      e.preventDefault();
    }
  });
  window.addEventListener("keyup", (e) => {
    keys.delete(e.code);
  });
  window.addEventListener("blur", () => keys.clear());
}

function pressed(code) {
  return keys.has(code);
}

/**
 * Edge-triggered actions: jump/attack/special/climb fire once per press.
 */
export function createInputTracker() {
  const prev = {
    p1: { jump: false, attack: false, special: false, climb: false },
    p2: { jump: false, attack: false, special: false, climb: false },
  };

  return {
    sample() {
      const p1Raw = {
        move:
          (pressed("KeyD") || pressed("KeyE") ? 1 : 0) -
          (pressed("KeyA") || pressed("KeyQ") ? 1 : 0),
        jump: pressed("KeyL") || pressed("KeyW") || pressed("Space"),
        attack: pressed("KeyJ"),
        special: pressed("KeyK"),
        climb: pressed("KeyI"),
      };
      // WASD: W also jump is ok for platformers; prefer L for jump listed in UI
      // Fix move: WASD standard
      p1Raw.move = (pressed("KeyD") ? 1 : 0) - (pressed("KeyA") ? 1 : 0);
      p1Raw.jump = pressed("KeyL") || pressed("Space");
      if (pressed("KeyW")) p1Raw.jump = true;

      const p2Raw = {
        move: (pressed("ArrowRight") ? 1 : 0) - (pressed("ArrowLeft") ? 1 : 0),
        jump: pressed("Digit3") || pressed("ArrowUp"),
        attack: pressed("Digit1") || pressed("Numpad1"),
        special: pressed("Digit2") || pressed("Numpad2"),
        climb: pressed("Digit5") || pressed("Numpad5"),
      };

      const edge = (raw, p) => {
        const out = {
          move: raw.move,
          jump: raw.jump && !prev[p].jump,
          attack: raw.attack && !prev[p].attack,
          special: raw.special && !prev[p].special,
          climb: raw.climb && !prev[p].climb,
        };
        prev[p].jump = raw.jump;
        prev[p].attack = raw.attack;
        prev[p].special = raw.special;
        prev[p].climb = raw.climb;
        return out;
      };

      return { p1: edge(p1Raw, "p1"), p2: edge(p2Raw, "p2") };
    },
  };
}

/** Simple XR gamepad mapping for Quest controllers */
export function sampleXrInput(xrFrame, session, refs) {
  const empty = { move: 0, jump: false, attack: false, special: false, climb: false };
  if (!session || !xrFrame) return { p1: empty, p2: empty };

  const sources = [...session.inputSources];
  const left = sources.find((s) => s.handedness === "left");
  const right = sources.find((s) => s.handedness === "right");

  const read = (src, side) => {
    if (!src?.gamepad) return { ...empty };
    const axes = src.gamepad.axes || [];
    // Quest: axes[2], axes[3] often thumbstick
    const ax = axes.length >= 4 ? axes[2] : axes[0] || 0;
    const buttons = src.gamepad.buttons || [];
    const trigger = buttons[0]?.pressed;
    const grip = buttons[1]?.pressed;
    const aBtn = buttons[4]?.pressed || buttons[3]?.pressed;
    const stickBtn = buttons[3]?.pressed;
    return {
      move: THREE_CLAMP(ax),
      jump: !!aBtn,
      attack: !!trigger,
      special: !!grip,
      climb: !!stickBtn || !!aBtn,
      _side: side,
    };
  };

  // Map: right controller = P1 (local), left can drive P2 or also assist
  const r = read(right, "right");
  const l = read(left, "left");

  // Edge detection stored on refs
  if (!refs.xrPrev) {
    refs.xrPrev = {
      p1: { jump: false, attack: false, special: false, climb: false },
      p2: { jump: false, attack: false, special: false, climb: false },
    };
  }

  const edgeify = (raw, key) => {
    const p = refs.xrPrev[key];
    const out = {
      move: raw.move,
      jump: raw.jump && !p.jump,
      attack: raw.attack && !p.attack,
      special: raw.special && !p.special,
      climb: raw.climb && !p.climb,
    };
    p.jump = raw.jump;
    p.attack = raw.attack;
    p.special = raw.special;
    p.climb = raw.climb;
    return out;
  };

  return {
    p1: edgeify(r, "p1"),
    p2: edgeify(
      {
        move: l.move,
        jump: l.jump,
        attack: l.attack,
        special: l.special,
        climb: l.climb,
      },
      "p2"
    ),
  };
}

function THREE_CLAMP(v) {
  if (Math.abs(v) < 0.15) return 0;
  return Math.max(-1, Math.min(1, v));
}
