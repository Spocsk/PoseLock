(function () {
  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function sizeCanvases() {
    document.querySelectorAll("canvas[data-pose]").forEach(function (c) {
      var ctx = PoseDraw.fitCanvas(c);
      var id = c.getAttribute("data-pose");
      var mode = c.getAttribute("data-mode") || "figure";
      if (mode === "stick") PoseDraw.drawStick(ctx, PoseDraw.poseOf(id), { green: c.hasAttribute("data-green") });
      else PoseDraw.drawFigure(ctx, PoseDraw.poseOf(id), c.getAttribute("data-color") || "#c4b08b");
    });
  }

  function initTabs() {
    var bar = document.querySelector(".t-tabs");
    if (!bar) return;
    var pill = bar.querySelector(".t-tabs-pill");
    var tabs = [].slice.call(bar.querySelectorAll(".t-tab"));
    var figure = document.getElementById("pack-figure");
    var name = document.querySelector("[data-pack-title]");
    var detail = document.querySelector("[data-pack-detail]");
    var pro = document.querySelector("[data-pack-pro]");
    var currentPose = figure.getAttribute("data-pose") || "frontDoubleBiceps";

    function moveTo(tab, animate) {
      var x = tab.getBoundingClientRect().left - bar.getBoundingClientRect().left;
      var w = tab.offsetWidth;
      if (!animate) {
        var prev = pill.style.transition;
        pill.style.transition = "none";
        pill.style.transform = "translateX(" + x + "px)";
        pill.style.width = w + "px";
        void pill.offsetWidth;
        pill.style.transition = prev;
      } else {
        pill.style.transform = "translateX(" + x + "px)";
        pill.style.width = w + "px";
      }
    }

    function apply(id) {
      var pack = PoseDraw.PACKS[id];
      name.textContent = pack.title;
      detail.textContent = pack.detail;
      pro.textContent = pack.pro ? "Catalogue Pro" : "";
      name.classList.remove("is-leaving");
      detail.classList.remove("is-leaving");
      figure.setAttribute("data-pose", pack.pose);
      var ctx = PoseDraw.fitCanvas(figure);
      var from = PoseDraw.poseOf(currentPose);
      var to = PoseDraw.poseOf(pack.pose);
      currentPose = pack.pose;
      if (typeof anime === "function" && !reduce) {
        var mix = { t: 0 };
        anime({
          targets: mix,
          t: 1,
          easing: "easeOutExpo",
          duration: 620,
          update: function () {
            PoseDraw.drawFigure(ctx, PoseDraw.lerpPose(from, to, mix.t), "#c4b08b");
          }
        });
      } else {
        PoseDraw.drawFigure(ctx, to, "#c4b08b");
      }
      if (window.PoseScroll && typeof PoseScroll.flipPack === "function") {
        PoseScroll.flipPack(figure, pack.pose);
      }
    }

    tabs.forEach(function (tab) {
      tab.addEventListener("click", function () {
        tabs.forEach(function (t) {
          t.setAttribute("aria-selected", t === tab ? "true" : "false");
        });
        moveTo(tab, true);
        apply(tab.getAttribute("data-pack"));
      });
    });
    requestAnimationFrame(function () {
      var active = tabs.find(function (t) { return t.getAttribute("aria-selected") === "true"; }) || tabs[0];
      moveTo(active, false);
    });
    window.addEventListener("resize", function () {
      var active = tabs.find(function (t) { return t.getAttribute("aria-selected") === "true"; }) || tabs[0];
      moveTo(active, false);
    });
  }

  function heroLock() {
    var score = document.querySelector(".hero-score");
    var reel = document.getElementById("hero-reel");
    var check = document.querySelector(".t-success-check");
    var toast = document.querySelector(".t-toast");
    if (!reel) return;

    function lock() {
      PoseScore.freezeReel(reel, 87);
      score.classList.add("is-locked");
      if (check) PoseScore.showCheck(check);
      if (toast) {
        toast.setAttribute("data-state", "in");
        window.setTimeout(function () {
          toast.classList.add("is-leaving");
          toast.setAttribute("data-state", "out");
        }, 2400);
      }
      if (typeof anime === "function" && !reduce) {
        anime({
          targets: ".hero-score .t-reel",
          color: "#8cc794",
          duration: 500,
          easing: "easeOutQuad"
        });
      }
    }

    function spinThenHold() {
      PoseScore.buildReel(reel, 87, { spins: 2 });
      var hold = reduce ? 80 : 1500;
      var spin = reduce ? 0 : 1600;
      window.setTimeout(lock, spin + hold);
    }

    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(spinThenHold);
    } else {
      spinThenHold();
    }
  }

  function journalDigits() {
    document.querySelectorAll(".t-digit-group[data-value]").forEach(function (el) {
      PoseScore.setDigits(el, el.getAttribute("data-value"));
    });
  }

  document.querySelectorAll(".t-stagger").forEach(function (block) {
    block.classList.add("is-shown");
  });

  sizeCanvases();
  initTabs();
  heroLock();
  journalDigits();
  PoseScroll.init({});
  window.addEventListener("resize", sizeCanvases);
})();
