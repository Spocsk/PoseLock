(function (global) {
  /**
   * Mini port of PoseLock/Domain/PoseTemplate.swift (PosePreviewBuilder)
   * and PoseLock/Design/PoseFigure.swift — four pack previews only.
   */
  var UPPER_ARM = 0.33;
  var FOREARM = 0.32;
  var THIGH = 0.45;
  var SHIN = 0.45;

  var BONES = [
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

  var ALL_JOINTS = [
    "root", "spine", "neck", "head",
    "lShoulder", "rShoulder", "lElbow", "rElbow", "lWrist", "rWrist",
    "lHip", "rHip", "lKnee", "rKnee", "lAnkle", "rAnkle"
  ];

  var YAW_JOINTS = [
    "spine", "neck", "head",
    "lShoulder", "rShoulder", "lElbow", "rElbow", "lWrist", "rWrist"
  ];

  var PACKS = {
    scene: { pose: "frontDoubleBiceps", title: "Scène", detail: "Mandatories Classic. Une ligne, un juge.", pro: false },
    content: { pose: "threeQuarterLat", title: "Contenu", detail: "L’angle, le cadre, la take qui claque.", pro: false },
    physique: { pose: "frontPosture", title: "Physique", detail: "Posture, ouverture, symétrie de pose.", pro: false },
    zyzz: { pose: "zyzzClassic", title: "Zyzz", detail: "Vacuum, twist, V-taper. La ligne esthétique.", pro: true }
  };

  var POSE_NAMES = {
    frontDoubleBiceps: "Front double biceps",
    threeQuarterLat: "¾ lat",
    frontPosture: "Posture face",
    zyzzClassic: "Pose Zyzz"
  };

  // TemplateLibrary.features — only the four pack defaults.
  var FEATURES = {
    frontDoubleBiceps: {
      leftElbow: 58, rightElbow: 58,
      leftShoulderAbduction: 92, rightShoulderAbduction: 92,
      leftWristHeight: 0.12, rightWristHeight: 0.12,
      bodyYaw: 0, shoulderLevel: 0,
      leftKnee: 160, rightKnee: 170, stanceWidth: 0.34
    },
    threeQuarterLat: {
      bodyYaw: 38, leftShoulderAbduction: 70,
      chestOpen: 0.46, vTaper: 1.48, spineInclination: 8
    },
    frontPosture: {
      bodyYaw: 0, shoulderLevel: 0, hipLevel: 0,
      spineInclination: 2, headAlignment: 0,
      leftElbow: 168, rightElbow: 168, stanceWidth: 0.22
    },
    zyzzClassic: {
      bodyYaw: 38,
      leftShoulderAbduction: 155, leftElbow: 165,
      rightShoulderAbduction: 125, rightElbow: 75,
      chestOpen: 0.50, vTaper: 1.58,
      spineInclination: 6, shoulderLevel: 8
    }
  };

  function v3(x, y, z) { return { x: x, y: y, z: z }; }
  function add(a, b) { return v3(a.x + b.x, a.y + b.y, a.z + b.z); }
  function sub(a, b) { return v3(a.x - b.x, a.y - b.y, a.z - b.z); }
  function mul(a, s) { return v3(a.x * s, a.y * s, a.z * s); }
  function dot(a, b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
  function len(a) { return Math.hypot(a.x, a.y, a.z); }
  function norm(a) {
    var l = len(a);
    return l < 1e-8 ? v3(0, 0, 0) : mul(a, 1 / l);
  }
  function clamp(n, a, b) { return Math.min(Math.max(n, a), b); }

  function rotateY(p, degrees) {
    var r = degrees * Math.PI / 180;
    var c = Math.cos(r);
    var s = Math.sin(r);
    return v3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c);
  }

  function targetOf(features, name, fallback) {
    return features[name] != null ? features[name] : fallback;
  }

  function optionalOf(features, name) {
    return features[name] != null ? features[name] : null;
  }

  function inferredAbduction(elbow, specified) {
    if (specified != null) return specified;
    if (elbow < 75) return 92;
    if (elbow < 125) return 48;
    return 16;
  }

  function wristPlace(elbow, abduction, exclusiveNape) {
    if (exclusiveNape) return "nape";
    if (elbow >= 85 && elbow <= 120 && abduction < 70) return "hip";
    return "automatic";
  }

  function arm(shoulder, hip, neck, isLeft, abduction, elbowAngle, wristHeight, place) {
    var side = isLeft ? -1 : 1;
    if (place === "nape") {
      return {
        elbow: add(shoulder, v3(side * 0.16, 0.24, 0.10)),
        wrist: add(neck, v3(side * 0.03, -0.02, 0.12))
      };
    }
    if (place === "hip") {
      return {
        elbow: add(shoulder, v3(side * 0.22, -0.10, 0.08)),
        wrist: add(hip, v3(side * 0.06, 0.08, 0.06))
      };
    }
    var a = abduction * Math.PI / 180;
    var fistsInFront = abduction < 55 && elbowAngle < 85;
    var upperDir = norm(v3(
      side * Math.sin(a),
      -Math.cos(a),
      fistsInFront ? 0.45 * Math.sin(Math.max(a, 0.2)) : 0
    ));
    var elbow = add(shoulder, mul(upperDir, UPPER_ARM));
    var u = norm(sub(elbow, shoulder));
    var bend = (180 - elbowAngle) * Math.PI / 180;
    var toward;
    if (elbowAngle < 80) toward = v3(-side * 0.15, 1, fistsInFront ? 0.4 : 0);
    else if (elbowAngle < 125) toward = sub(hip, elbow);
    else toward = u;
    var plane = sub(toward, mul(u, dot(toward, u)));
    if (len(plane) < 0.08) {
      var up = v3(0, 1, 0);
      plane = sub(up, mul(u, dot(up, u)));
    }
    if (len(plane) < 0.04) plane = v3(side, 0, 0);
    plane = norm(plane);
    var forearmDir = norm(add(mul(u, Math.cos(bend)), mul(plane, Math.sin(bend))));
    var wrist = add(elbow, mul(forearmDir, FOREARM));
    if (wristHeight != null) {
      var desiredY = shoulder.y + wristHeight;
      var dy = (desiredY - elbow.y) / FOREARM;
      var clamped = clamp(dy, -0.98, 0.98);
      var rest = Math.sqrt(Math.max(0, 1 - clamped * clamped));
      var hzx = forearmDir.x;
      var hzz = forearmDir.z;
      var hl = Math.hypot(hzx, hzz);
      if (hl > 0.01) {
        hzx = (hzx / hl) * rest;
        hzz = (hzz / hl) * rest;
      } else {
        hzx = side * rest * 0.25;
        hzz = 0;
      }
      forearmDir = norm(v3(hzx, clamped, hzz));
      wrist = add(elbow, mul(forearmDir, FOREARM));
    }
    return { elbow: elbow, wrist: wrist };
  }

  function leg(hip, isLeft, kneeAngle, ankleX) {
    var ankle = v3(ankleX, hip.y - (THIGH + SHIN) * 0.98, 0);
    var hipToAnkle = sub(ankle, hip);
    var dist = len(hipToAnkle);
    var maxReach = THIGH + SHIN - 0.01;
    if (dist > maxReach) dist = maxReach;
    dist = Math.max(dist, 0.08);
    var dir = norm(hipToAnkle);
    var x = (dist * dist + THIGH * THIGH - SHIN * SHIN) / (2 * dist);
    var heightSq = Math.max(0, THIGH * THIGH - x * x);
    var height = Math.sqrt(heightSq);
    var side = isLeft ? -1 : 1;
    var perp = v3(-dir.y * side, dir.x * side, 0.12);
    if (len(perp) < 0.01) perp = v3(side, 0, 0);
    perp = norm(perp);
    var visibleBend = Math.max(0, (180 - kneeAngle) / 25);
    var knee = add(add(hip, mul(dir, x)), mul(perp, height * Math.min(visibleBend, 1)));
    return { knee: knee, ankle: ankle };
  }

  function normalize(joints) {
    var origin = joints.root || v3(
      (joints.lHip.x + joints.rHip.x) / 2,
      (joints.lHip.y + joints.rHip.y) / 2,
      (joints.lHip.z + joints.rHip.z) / 2
    );
    var out = {};
    ALL_JOINTS.forEach(function (k) {
      if (joints[k]) out[k] = sub(joints[k], origin);
    });
    var hips = out.root || v3(
      (out.lHip.x + out.rHip.x) / 2,
      (out.lHip.y + out.rHip.y) / 2,
      (out.lHip.z + out.rHip.z) / 2
    );
    var head = out.head || out.neck;
    var scale = head ? len(sub(head, hips)) : 1;
    if (scale < 0.001 && out.lShoulder && out.rShoulder) {
      scale = len(sub(out.lShoulder, out.rShoulder));
    }
    if (scale < 0.001) return out;
    ALL_JOINTS.forEach(function (k) {
      if (out[k]) out[k] = mul(out[k], 1 / scale);
    });
    return out;
  }

  function projectFitted(joints3D) {
    var projected = {};
    ALL_JOINTS.forEach(function (k) {
      var p = joints3D[k];
      if (!p) return;
      projected[k] = { x: p.x + p.z * 0.38, y: p.y, z: p.z };
    });
    var xs = [];
    var ys = [];
    ALL_JOINTS.forEach(function (k) {
      if (!projected[k]) return;
      xs.push(projected[k].x);
      ys.push(projected[k].y);
    });
    if (!xs.length) return {};
    var minX = Math.min.apply(null, xs);
    var maxX = Math.max.apply(null, xs);
    var minY = Math.min.apply(null, ys);
    var maxY = Math.max.apply(null, ys);
    var width = Math.max(maxX - minX, 0.18);
    var height = Math.max(maxY - minY, 0.18);
    var cx = (minX + maxX) / 2;
    var scale = Math.max(width / 0.76, height / 0.84);
    var out = {};
    ALL_JOINTS.forEach(function (k) {
      var p = projected[k];
      if (!p) return;
      out[k] = {
        x: clamp(0.5 + (p.x - cx) / scale, 0.04, 0.96),
        y: clamp(0.10 + (maxY - p.y) / scale, 0.04, 0.96),
        z: p.z
      };
    });
    return out;
  }

  function frame(poseID) {
    var features = FEATURES[poseID];
    if (!features) return {};
    function target(name, fallback) { return targetOf(features, name, fallback); }
    function optional(name) { return optionalOf(features, name); }

    var bodyYaw = target("bodyYaw", 0);
    var torsoTwist = target("torsoTwist", 0);
    var hipHalf = 0.12;
    var stance = target("stanceWidth", 0.26);
    var vTaper = target("vTaper", 1.7);
    var chest = optional("chestOpen");
    var shoulderHalf = chest != null ? chest / 2 : vTaper * hipHalf;
    shoulderHalf = clamp(shoulderHalf, 0.18, 0.34);

    var joints = {};
    joints.root = v3(0, 0, 0);
    joints.lHip = v3(-hipHalf, 0, 0);
    joints.rHip = v3(hipHalf, 0, 0);

    var hipLevel = target("hipLevel", 0);
    if (hipLevel > 0.4) {
      var hipDy = (hipLevel / 90) * (hipHalf * 2);
      joints.rHip.y += hipDy / 2;
      joints.lHip.y -= hipDy / 2;
    }

    var inc = target("spineInclination", 3) * Math.PI / 180;
    var spineDir = v3(0, Math.cos(inc), -Math.sin(inc));
    joints.spine = mul(spineDir, 0.40);
    joints.neck = mul(spineDir, 0.75);
    var headInc = target("headAlignment", 0) * Math.PI / 180;
    joints.head = add(joints.neck, mul(v3(Math.sin(headInc), Math.cos(headInc), -Math.sin(inc) * 0.15), 0.26));

    var shoulderY = 0.72;
    joints.lShoulder = v3(-shoulderHalf, shoulderY, 0);
    joints.rShoulder = v3(shoulderHalf, shoulderY, 0);
    var shoulderLevel = target("shoulderLevel", 0);
    if (shoulderLevel > 0.4) {
      var shDy = (shoulderLevel / 90) * (shoulderHalf * 2);
      joints.rShoulder.y += shDy / 2;
      joints.lShoulder.y -= shDy / 2;
    }

    var leftElbowAngle = target("leftElbow", 168);
    var rightElbowAngle = target("rightElbow", 168);
    var leftAbd = inferredAbduction(leftElbowAngle, optional("leftShoulderAbduction"));
    var rightAbd = inferredAbduction(rightElbowAngle, optional("rightShoulderAbduction"));
    var leftNape = leftAbd >= 70 && leftElbowAngle < 70;
    var rightNape = rightAbd >= 70 && rightElbowAngle < 70;

    var leftArm = arm(
      joints.lShoulder, joints.lHip, joints.neck, true,
      leftAbd, leftElbowAngle,
      poseID === "frontDoubleBiceps" ? null : optional("leftWristHeight"),
      poseID === "zyzzClassic" ? "automatic" : wristPlace(leftElbowAngle, leftAbd, leftNape && !rightNape)
    );
    joints.lElbow = leftArm.elbow;
    joints.lWrist = leftArm.wrist;

    var rightArm = arm(
      joints.rShoulder, joints.rHip, joints.neck, false,
      rightAbd, rightElbowAngle,
      poseID === "frontDoubleBiceps" ? null : optional("rightWristHeight"),
      poseID === "zyzzClassic" ? "automatic" : wristPlace(rightElbowAngle, rightAbd, rightNape && !leftNape)
    );
    joints.rElbow = rightArm.elbow;
    joints.rWrist = rightArm.wrist;

    var leftLeg = leg(joints.lHip, true, target("leftKnee", 172), -stance / 2);
    joints.lKnee = leftLeg.knee;
    joints.lAnkle = leftLeg.ankle;
    var rightLeg = leg(joints.rHip, false, target("rightKnee", 172), stance / 2);
    joints.rKnee = rightLeg.knee;
    joints.rAnkle = rightLeg.ankle;

    if (poseID === "frontDoubleBiceps") {
      joints.lAnkle.z += 0.18;
    }

    ALL_JOINTS.forEach(function (k) {
      if (joints[k]) joints[k] = rotateY(joints[k], bodyYaw);
    });
    YAW_JOINTS.forEach(function (k) {
      if (joints[k]) joints[k] = rotateY(joints[k], torsoTwist);
    });

    return projectFitted(normalize(joints));
  }

  var POSES = {};
  Object.keys(POSE_NAMES).forEach(function (id) {
    POSES[id] = { name: POSE_NAMES[id], joints: frame(id) };
  });

  function asPt(p) {
    if (!p) return null;
    if (Array.isArray(p)) return { x: p[0], y: p[1], z: 0 };
    return p;
  }

  function lerpPose(a, b, t) {
    var out = {};
    Object.keys(a).forEach(function (k) {
      var pa = asPt(a[k]);
      var pb = asPt(b[k]) || pa;
      out[k] = {
        x: pa.x + (pb.x - pa.x) * t,
        y: pa.y + (pb.y - pa.y) * t,
        z: (pa.z || 0) + ((pb.z || 0) - (pa.z || 0)) * t
      };
    });
    return out;
  }

  function map(pt, w, h, pad) {
    var p = asPt(pt);
    var s = Math.min(w, h) - pad * 2;
    var ox = (w - s) / 2;
    var oy = (h - s) / 2;
    return [ox + p.x * s, oy + p.y * s];
  }

  function drawStick(ctx, joints, opts) {
    opts = opts || {};
    var w = ctx.canvas.width;
    var h = ctx.canvas.height;
    var pad = opts.pad != null ? opts.pad : w * 0.08;
    var green = !!opts.green;
    ctx.clearRect(0, 0, w, h);
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.strokeStyle = green ? "#8cc794" : "rgba(232,227,219,0.42)";
    ctx.lineWidth = green ? Math.max(6, w * 0.018) : Math.max(4, w * 0.012);
    BONES.forEach(function (pair) {
      var a = joints[pair[0]];
      var b = joints[pair[1]];
      if (!a || !b) return;
      var pa = map(a, w, h, pad);
      var pb = map(b, w, h, pad);
      ctx.beginPath();
      ctx.moveTo(pa[0], pa[1]);
      ctx.lineTo(pb[0], pb[1]);
      ctx.stroke();
    });
    ctx.fillStyle = "rgba(232,227,219,0.9)";
    Object.keys(joints).forEach(function (k) {
      var p = map(joints[k], w, h, pad);
      ctx.beginPath();
      ctx.arc(p[0], p[1], Math.max(3, w * 0.012), 0, Math.PI * 2);
      ctx.fill();
    });
  }

  function insetToward(pt, mid, pinch) {
    var dx = pt[0] - mid[0];
    var dy = pt[1] - mid[1];
    var d = Math.hypot(dx, dy);
    if (d < 0.5) return pt;
    var t = pinch / d;
    return [pt[0] - dx * t, pt[1] - dy * t];
  }

  function drawFigure(ctx, joints, color) {
    var w = ctx.canvas.width;
    var h = ctx.canvas.height;
    ctx.clearRect(0, 0, w, h);
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = "high";
    var pad = 0;
    var p = {};
    var depth = {};
    Object.keys(joints).forEach(function (k) {
      p[k] = map(joints[k], w, h, pad);
      depth[k] = asPt(joints[k]).z || 0;
    });
    if (!p.head || !p.root) return;
    var hipW = Math.hypot(p.head[0] - p.root[0], p.head[1] - p.root[1]) * 0.24;
    var fill = color || "#c4b08b";
    var layers = [];

    function zOf(keys) {
      var sum = 0;
      var n = 0;
      keys.forEach(function (k) {
        if (depth[k] != null) {
          sum += depth[k];
          n += 1;
        }
      });
      return n ? sum / n : 0;
    }

    if (p.lShoulder && p.rShoulder && p.lHip && p.rHip) {
      var waistLeft = [
        p.lShoulder[0] * 0.45 + p.lHip[0] * 0.55,
        p.lShoulder[1] * 0.45 + p.lHip[1] * 0.55
      ];
      var waistRight = [
        p.rShoulder[0] * 0.45 + p.rHip[0] * 0.55,
        p.rShoulder[1] * 0.45 + p.rHip[1] * 0.55
      ];
      var mid = [(waistLeft[0] + waistRight[0]) / 2, (waistLeft[1] + waistRight[1]) / 2];
      var pinch = hipW * 0.22;
      var wL = insetToward(waistLeft, mid, pinch);
      var wR = insetToward(waistRight, mid, pinch);
      var side = Math.min(w, h);
      layers.push({
        z: zOf(["lShoulder", "rShoulder", "lHip", "rHip"]),
        draw: function () {
          ctx.fillStyle = fill;
          ctx.beginPath();
          ctx.moveTo(p.lShoulder[0], p.lShoulder[1]);
          ctx.lineTo(p.rShoulder[0], p.rShoulder[1]);
          ctx.lineTo(wR[0], wR[1]);
          ctx.lineTo(p.rHip[0], p.rHip[1]);
          ctx.lineTo(p.lHip[0], p.lHip[1]);
          ctx.lineTo(wL[0], wL[1]);
          ctx.closePath();
          ctx.fill();
          ctx.strokeStyle = "rgba(10, 10, 10, 0.5)";
          ctx.lineWidth = side * 0.004;
          ctx.stroke();
        }
      });
    }

    if (p.head && p.neck) {
      var head = [
        p.neck[0] + (p.head[0] - p.neck[0]) * 0.65,
        p.neck[1] + (p.head[1] - p.neck[1]) * 0.65
      ];
      var radius = Math.max(hipW * 0.43, 4);
      layers.push({
        z: zOf(["head"]),
        draw: function () {
          ctx.strokeStyle = fill;
          ctx.fillStyle = fill;
          ctx.lineCap = "round";
          ctx.lineWidth = radius * 0.7;
          ctx.beginPath();
          ctx.moveTo(p.neck[0], p.neck[1]);
          ctx.lineTo(head[0], head[1]);
          ctx.stroke();
          ctx.beginPath();
          ctx.arc(head[0], head[1], radius, 0, Math.PI * 2);
          ctx.fill();
        }
      });
    }

    var limbs = [
      ["lShoulder", "lElbow", 0.48],
      ["lElbow", "lWrist", 0.36],
      ["rShoulder", "rElbow", 0.48],
      ["rElbow", "rWrist", 0.36],
      ["lHip", "lKnee", 0.67],
      ["lKnee", "lAnkle", 0.46],
      ["rHip", "rKnee", 0.67],
      ["rKnee", "rAnkle", 0.46]
    ];
    limbs.forEach(function (limb) {
      var a = p[limb[0]];
      var b = p[limb[1]];
      if (!a || !b) return;
      var width = hipW * limb[2];
      layers.push({
        z: zOf([limb[0], limb[1]]),
        draw: function () {
          ctx.strokeStyle = fill;
          ctx.lineCap = "round";
          ctx.lineJoin = "round";
          ctx.lineWidth = width;
          ctx.beginPath();
          ctx.moveTo(a[0], a[1]);
          ctx.lineTo(b[0], b[1]);
          ctx.stroke();
        }
      });
    });

    layers.sort(function (a, b) { return a.z - b.z; });
    layers.forEach(function (layer) { layer.draw(); });
  }

  function fitCanvas(canvas) {
    var rect = canvas.getBoundingClientRect();
    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    var w = Math.max(1, Math.round(rect.width * dpr));
    var h = Math.max(1, Math.round(rect.height * dpr));
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
    rotateY: rotateY,
    frame: frame,
    projectFitted: projectFitted,
    poseOf: function (id) { return POSES[id].joints; }
  };
})(window);
