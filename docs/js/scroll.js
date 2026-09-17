(function (global) {
  function initScroll() {
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
    var mix = { t: 0 };
    var activeChapter = -1;
    var swapTimer = 0;

    var chapters = [
      { title: "Pose", detail: "Le stickman suit tes angles. Vert : l’articulation est dans la tolérance.", cue: "Ouvre les coudes." },
      { title: "Score", detail: "Sur 100, en direct. Le chiffre juge la ligne, jamais la personne.", cue: "Score ≥ 85." },
      { title: "Lock", detail: "1,5 s au vert. La photo reste dans l’app. La vidéo n’en sort jamais.", cue: "Tiens 1,5 s." }
    ];

    function applyChapter(index, immediate) {
      if (index === activeChapter) return;
      activeChapter = index;
      var chapter = chapters[index];
      window.clearTimeout(swapTimer);
      cue.textContent = chapter.cue;
      beats.forEach(function (el, beatIndex) {
        el.setAttribute("aria-current", beatIndex === index ? "step" : "false");
      });
      if (immediate || PoseScore.prefersReduce()) {
        title.textContent = chapter.title;
        detail.textContent = chapter.detail;
        title.classList.remove("is-leaving");
        detail.classList.remove("is-leaving");
        return;
      }
      title.classList.add("is-leaving");
      detail.classList.add("is-leaving");
      swapTimer = window.setTimeout(function () {
        title.textContent = chapter.title;
        detail.textContent = chapter.detail;
        title.classList.remove("is-leaving");
        detail.classList.remove("is-leaving");
      }, 140);
    }

    function paint() {
      var ctx = PoseDraw.fitCanvas(canvas);
      var joints = PoseDraw.lerpPose(poseA, poseB, mix.t);
      var chapter = mix.t < 0.33 ? 0 : mix.t < 0.66 ? 1 : 2;
      PoseDraw.drawStick(ctx, joints, { green: chapter === 2 });
      hud.textContent = String(Math.round(41 + mix.t * 46));
      phone.classList.toggle("is-green", chapter === 2);
      applyChapter(chapter, false);
    }

    function setFinal() {
      mix.t = 1;
      activeChapter = -1;
      applyChapter(2, true);
      paint();
    }

    if (PoseScore.prefersReduce() || typeof gsap === "undefined" || typeof ScrollTrigger === "undefined") {
      setFinal();
      return;
    }

    gsap.registerPlugin(ScrollTrigger);
    var media = gsap.matchMedia();

    media.add("(min-width: 861px)", function () {
      mix.t = 0;
      activeChapter = -1;
      applyChapter(0, true);
      paint();
      var tween = gsap.to(mix, {
        t: 1,
        ease: "none",
        onUpdate: paint,
        scrollTrigger: {
          trigger: ".mechanism",
          start: "top top",
          end: "bottom bottom",
          scrub: 0.65
        }
      });
      return function () { tween.kill(); };
    });

    media.add("(max-width: 860px)", function () {
      mix.t = 0;
      activeChapter = -1;
      applyChapter(0, true);
      paint();
      var tween = gsap.to(mix, {
        t: 1,
        duration: 1.35,
        ease: "power2.inOut",
        paused: true,
        onUpdate: paint
      });
      var trigger = ScrollTrigger.create({
        trigger: ".mechanism",
        start: "top 72%",
        once: true,
        onEnter: function () { tween.play(); }
      });
      return function () {
        trigger.kill();
        tween.kill();
      };
    });

    window.addEventListener("resize", paint);
  }

  global.PoseScroll = { init: initScroll };
})(window);
