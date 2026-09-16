(function (global) {
  function initScroll(state) {
    if (typeof gsap === "undefined" || typeof ScrollTrigger === "undefined") return;
    gsap.registerPlugin(ScrollTrigger, Flip);

    var reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    var phone = document.querySelector(".phone");
    var hud = document.querySelector(".hud-score");
    var cue = document.querySelector(".hud-cue");
    var title = document.querySelector("[data-mech-title]");
    var detail = document.querySelector("[data-mech-detail]");
    var beats = document.querySelectorAll(".beats li");
    var canvas = document.getElementById("live-pose");
    if (!phone || !canvas) return;

    var poseA = PoseDraw.poseOf("frontPosture");
    var poseB = PoseDraw.poseOf("frontDoubleBiceps");
    var mix = { t: 0, score: 41, green: 0 };

    function paint() {
      var ctx = PoseDraw.fitCanvas(canvas);
      var joints = PoseDraw.lerpPose(poseA, poseB, mix.t);
      PoseDraw.drawStick(ctx, joints, { green: mix.green > 0.5 });
    }
    paint();
    window.addEventListener("resize", paint);

    var chapters = [
      { title: "Pose", detail: "Le stickman suit tes angles. Vert : l’articulation est dans la tolérance.", cue: "Ouvre les coudes." },
      { title: "Score", detail: "Sur 100, en direct. Le chiffre juge la ligne, jamais la personne.", cue: "Score ≥ 85." },
      { title: "Lock", detail: "1,5 s au vert. La photo reste dans l’app. La vidéo n’en sort jamais.", cue: "Tiens 1,5 s." }
    ];

    function applyChapter(i, score) {
      var ch = chapters[i];
      if (title.textContent !== ch.title) {
        title.classList.add("is-leaving");
        detail.classList.add("is-leaving");
        window.setTimeout(function () {
          title.textContent = ch.title;
          detail.textContent = ch.detail;
          title.classList.remove("is-leaving");
          detail.classList.remove("is-leaving");
        }, 140);
      }
      cue.textContent = ch.cue;
      beats.forEach(function (el, idx) {
        el.setAttribute("aria-current", idx === i ? "true" : "false");
      });
      hud.textContent = String(Math.round(score));
      phone.classList.toggle("is-green", i === 2);
    }

    if (reduce) {
      mix.t = 1;
      mix.green = 1;
      paint();
      applyChapter(2, 87);
      return;
    }

    ScrollTrigger.create({
      trigger: ".mechanism",
      start: "top top",
      end: "bottom bottom",
      scrub: 0.65,
      onUpdate: function (self) {
        var p = self.progress;
        mix.t = gsap.utils.clamp(0, 1, p * 1.15);
        var chapter = p < 0.33 ? 0 : p < 0.66 ? 1 : 2;
        var score = 41 + mix.t * 46;
        mix.green = chapter === 2 ? 1 : 0;
        paint();
        applyChapter(chapter, score);
      }
    });

    global.PoseScroll.flipPack = function (canvasEl) {
      if (typeof Flip === "undefined") return;
      var wrap = canvasEl.parentElement;
      var snap = Flip.getState(wrap);
      Flip.from(snap, { duration: 0.45, ease: "power3.out", absolute: false });
    };
  }

  global.PoseScroll = { init: initScroll, flipPack: function () {} };
})(window);
