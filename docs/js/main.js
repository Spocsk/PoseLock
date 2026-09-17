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
    var panel = document.getElementById("catalog-panel");
    var name = document.querySelector("[data-pack-title]");
    var detail = document.querySelector("[data-pack-detail]");
    var pro = document.querySelector("[data-pack-pro]");
    var renderedPose = PoseDraw.poseOf(figure.getAttribute("data-pose") || "frontDoubleBiceps");
    var activeTween = null;
    var textTimer = 0;

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

    function apply(id, tab) {
      var pack = PoseDraw.PACKS[id];
      window.clearTimeout(textTimer);
      name.classList.add("is-leaving");
      detail.classList.add("is-leaving");
      textTimer = window.setTimeout(function () {
        name.textContent = pack.title;
        detail.textContent = pack.detail;
        pro.textContent = pack.pro ? "Catalogue Pro" : "";
        name.classList.remove("is-leaving");
        detail.classList.remove("is-leaving");
      }, reduce ? 0 : 140);
      figure.setAttribute("data-pose", pack.pose);
      var ctx = PoseDraw.fitCanvas(figure);
      var from = renderedPose;
      var to = PoseDraw.poseOf(pack.pose);
      if (activeTween) activeTween.kill();
      if (typeof gsap !== "undefined" && !reduce) {
        var mix = { t: 0 };
        activeTween = gsap.to(mix, {
          t: 1,
          ease: "expo.out",
          duration: 0.62,
          onUpdate: function () {
            renderedPose = PoseDraw.lerpPose(from, to, mix.t);
            PoseDraw.drawFigure(ctx, renderedPose, "#c4b08b");
          },
          onComplete: function () {
            renderedPose = to;
            activeTween = null;
          }
        });
      } else {
        renderedPose = to;
        PoseDraw.drawFigure(ctx, to, "#c4b08b");
      }
      if (panel && tab) {
        panel.setAttribute("aria-labelledby", tab.id);
      }
    }

    function activate(tab, focus) {
      tabs.forEach(function (item) {
        var selected = item === tab;
        item.setAttribute("aria-selected", selected ? "true" : "false");
        item.setAttribute("tabindex", selected ? "0" : "-1");
      });
      moveTo(tab, true);
      apply(tab.getAttribute("data-pack"), tab);
      tab.scrollIntoView({ behavior: reduce ? "auto" : "smooth", block: "nearest", inline: "center" });
      if (focus) tab.focus();
    }

    tabs.forEach(function (tab, index) {
      tab.addEventListener("click", function () { activate(tab, false); });
      tab.addEventListener("keydown", function (event) {
        var next = index;
        if (event.key === "ArrowRight") next = (index + 1) % tabs.length;
        else if (event.key === "ArrowLeft") next = (index - 1 + tabs.length) % tabs.length;
        else if (event.key === "Home") next = 0;
        else if (event.key === "End") next = tabs.length - 1;
        else return;
        event.preventDefault();
        activate(tabs[next], true);
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
      document.querySelector(".hero").classList.add("is-locked");
      if (check) PoseScore.showCheck(check);
      if (toast) {
        toast.setAttribute("data-state", "in");
        window.setTimeout(function () {
          toast.classList.add("is-leaving");
          toast.setAttribute("data-state", "out");
        }, 2400);
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

  sizeCanvases();
  initTabs();
  heroLock();
  journalDigits();
  PoseScroll.init();
  window.addEventListener("resize", sizeCanvases);
})();
