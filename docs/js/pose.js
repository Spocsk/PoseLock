(function (global) {
  const BONES = [
    ["lHip", "rHip"],
    ["lHip", "root"],
    ["rHip", "root"],
    ["root", "spine"],
    ["spine", "neck"],
    ["neck", "head"],
    ["lShoulder", "rShoulder"],
    ["spine", "lShoulder"],
    ["spine", "rShoulder"],
    ["lShoulder", "lElbow"],
    ["lElbow", "lWrist"],
    ["rShoulder", "rElbow"],
    ["rElbow", "rWrist"],
    ["lHip", "lKnee"],
    ["lKnee", "lAnkle"],
    ["rHip", "rKnee"],
    ["rKnee", "rAnkle"]
  ];

  const POSES = {
    frontDoubleBiceps: {
      name: "Front double biceps",
      joints: {
        head: [0.50, 0.10], neck: [0.50, 0.17],
        lShoulder: [0.33, 0.23], rShoulder: [0.67, 0.23],
        lElbow: [0.15, 0.18], rElbow: [0.85, 0.18],
        lWrist: [0.26, 0.09], rWrist: [0.74, 0.09],
        spine: [0.50, 0.36], root: [0.50, 0.48],
        lHip: [0.42, 0.50], rHip: [0.58, 0.50],
        lKnee: [0.40, 0.70], rKnee: [0.60, 0.70],
        lAnkle: [0.39, 0.90], rAnkle: [0.61, 0.90]
      }
    },
    threeQuarterLat: {
      name: "¾ lat",
      joints: {
        head: [0.56, 0.11], neck: [0.54, 0.18],
        lShoulder: [0.40, 0.24], rShoulder: [0.64, 0.26],
        lElbow: [0.22, 0.38], rElbow: [0.74, 0.36],
        lWrist: [0.12, 0.50], rWrist: [0.80, 0.24],
        spine: [0.52, 0.37], root: [0.50, 0.49],
        lHip: [0.44, 0.51], rHip: [0.58, 0.50],
        lKnee: [0.42, 0.71], rKnee: [0.61, 0.70],
        lAnkle: [0.40, 0.90], rAnkle: [0.63, 0.89]
      }
    },
    frontPosture: {
      name: "Posture face",
      joints: {
        head: [0.50, 0.10], neck: [0.50, 0.17],
        lShoulder: [0.34, 0.24], rShoulder: [0.66, 0.24],
        lElbow: [0.28, 0.40], rElbow: [0.72, 0.40],
        lWrist: [0.26, 0.55], rWrist: [0.74, 0.55],
        spine: [0.50, 0.36], root: [0.50, 0.48],
        lHip: [0.43, 0.50], rHip: [0.57, 0.50],
        lKnee: [0.42, 0.70], rKnee: [0.58, 0.70],
        lAnkle: [0.41, 0.90], rAnkle: [0.59, 0.90]
      }
    },
    zyzzClassic: {
      name: "Pose Zyzz",
      joints: {
        head: [0.53, 0.11], neck: [0.51, 0.18],
        lShoulder: [0.36, 0.25], rShoulder: [0.62, 0.22],
        lElbow: [0.22, 0.42], rElbow: [0.78, 0.16],
        lWrist: [0.18, 0.58], rWrist: [0.70, 0.08],
        spine: [0.50, 0.37], root: [0.49, 0.49],
        lHip: [0.42, 0.51], rHip: [0.56, 0.49],
        lKnee: [0.38, 0.71], rKnee: [0.60, 0.69],
        lAnkle: [0.36, 0.90], rAnkle: [0.62, 0.89]
      }
    }
  };

  const PACKS = {
    scene: { pose: "frontDoubleBiceps", title: "Scène", detail: "Mandatories Classic. Une ligne, un juge.", pro: false },
    content: { pose: "threeQuarterLat", title: "Contenu", detail: "L’angle, le cadre, la take qui claque.", pro: false },
    physique: { pose: "frontPosture", title: "Physique", detail: "Posture, ouverture, symétrie de pose.", pro: false },
    zyzz: { pose: "zyzzClassic", title: "Zyzz", detail: "Vacuum, twist, V-taper. La ligne esthétique.", pro: true }
  };

  function lerpPose(a, b, t) {
    const out = {};
    Object.keys(a).forEach(function (k) {
      out[k] = [a[k][0] + (b[k][0] - a[k][0]) * t, a[k][1] + (b[k][1] - a[k][1]) * t];
    });
    return out;
  }

  function map(pt, w, h, pad) {
    const s = Math.min(w, h) - pad * 2;
    const ox = (w - s) / 2;
    const oy = (h - s) / 2;
    return [ox + pt[0] * s, oy + pt[1] * s];
  }

  function drawStick(ctx, joints, opts) {
    const w = ctx.canvas.width;
    const h = ctx.canvas.height;
    const pad = opts.pad || w * 0.08;
    const green = !!opts.green;
    ctx.clearRect(0, 0, w, h);
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.strokeStyle = green ? "#8cc794" : "rgba(232,227,219,0.42)";
    ctx.lineWidth = green ? Math.max(6, w * 0.018) : Math.max(4, w * 0.012);
    BONES.forEach(function (pair) {
      const a = joints[pair[0]];
      const b = joints[pair[1]];
      if (!a || !b) return;
      const pa = map(a, w, h, pad);
      const pb = map(b, w, h, pad);
      ctx.beginPath();
      ctx.moveTo(pa[0], pa[1]);
      ctx.lineTo(pb[0], pb[1]);
      ctx.stroke();
    });
    ctx.fillStyle = "rgba(232,227,219,0.9)";
    Object.keys(joints).forEach(function (k) {
      const p = map(joints[k], w, h, pad);
      ctx.beginPath();
      ctx.arc(p[0], p[1], Math.max(3, w * 0.012), 0, Math.PI * 2);
      ctx.fill();
    });
  }

  function stadium(ctx, a, b, r) {
    const dx = b[0] - a[0];
    const dy = b[1] - a[1];
    const len = Math.hypot(dx, dy) || 1;
    const nx = -dy / len;
    const ny = dx / len;
    ctx.beginPath();
    ctx.moveTo(a[0] + nx * r, a[1] + ny * r);
    ctx.arcTo(a[0] + nx * r + dx, a[1] + ny * r + dy, b[0] - nx * r, b[1] - ny * r, r);
    ctx.arc(b[0], b[1], r, Math.atan2(ny, nx), Math.atan2(-ny, -nx));
    ctx.arcTo(a[0] - nx * r + dx, a[1] - ny * r + dy, a[0] - nx * r, a[1] - ny * r, r);
    ctx.arc(a[0], a[1], r, Math.atan2(-ny, -nx), Math.atan2(ny, nx));
    ctx.closePath();
  }

  function drawFigure(ctx, joints, color) {
    const w = ctx.canvas.width;
    const h = ctx.canvas.height;
    const pad = w * 0.1;
    ctx.clearRect(0, 0, w, h);
    const p = {};
    Object.keys(joints).forEach(function (k) { p[k] = map(joints[k], w, h, pad); });
    const hipW = Math.hypot(p.head[0] - p.root[0], p.head[1] - p.root[1]) * 0.24;
    ctx.fillStyle = color || "#c4b08b";
    ctx.strokeStyle = "rgba(10,10,10,0.5)";
    ctx.lineWidth = Math.max(1, w * 0.004);

    const torso = new Path2D();
    const hw = hipW * 0.95;
    torso.moveTo(p.lShoulder[0], p.lShoulder[1]);
    torso.lineTo(p.rShoulder[0], p.rShoulder[1]);
    torso.lineTo(p.rHip[0] + hw * 0.15, p.rHip[1]);
    torso.lineTo(p.lHip[0] - hw * 0.15, p.lHip[1]);
    torso.closePath();
    ctx.fill(torso);
    ctx.stroke(torso);

    function limb(a, b, r) {
      stadium(ctx, a, b, r);
      ctx.fill();
    }
    limb(p.lShoulder, p.lElbow, hipW * 0.28);
    limb(p.lElbow, p.lWrist, hipW * 0.22);
    limb(p.rShoulder, p.rElbow, hipW * 0.28);
    limb(p.rElbow, p.rWrist, hipW * 0.22);
    limb(p.lHip, p.lKnee, hipW * 0.34);
    limb(p.lKnee, p.lAnkle, hipW * 0.26);
    limb(p.rHip, p.rKnee, hipW * 0.34);
    limb(p.rKnee, p.rAnkle, hipW * 0.26);

    ctx.beginPath();
    ctx.arc(p.head[0], p.head[1], Math.max(hipW * 0.43, 6), 0, Math.PI * 2);
    ctx.fill();
  }

  function fitCanvas(canvas) {
    const rect = canvas.getBoundingClientRect();
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const w = Math.max(1, Math.round(rect.width * dpr));
    const h = Math.max(1, Math.round(rect.height * dpr));
    if (canvas.width !== w || canvas.height !== h) {
      canvas.width = w;
      canvas.height = h;
    }
    return canvas.getContext("2d");
  }

  global.PoseDraw = {
    POSES: POSES,
    PACKS: PACKS,
    lerpPose: lerpPose,
    drawStick: drawStick,
    drawFigure: drawFigure,
    fitCanvas: fitCanvas,
    poseOf: function (id) { return POSES[id].joints; }
  };
})(window);
