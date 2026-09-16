(function (global) {
  function prefersReduce() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }

  function setDigits(group, str) {
    group.classList.remove("is-animating");
    group.replaceChildren();
    var chars = String(str).split("");
    chars.forEach(function (ch, i) {
      var span = document.createElement("span");
      span.className = "t-digit";
      span.textContent = ch;
      if (i === chars.length - 2) span.dataset.stagger = "1";
      else if (i === chars.length - 1) span.dataset.stagger = "2";
      group.appendChild(span);
    });
    void group.offsetHeight;
    group.classList.add("is-animating");
  }

  function cellPx(el) {
    var fs = parseFloat(getComputedStyle(el).fontSize);
    return fs > 0 ? fs : 96;
  }

  function freezeReel(root, value) {
    var str = String(value).padStart(2, "0");
    root.replaceChildren();
    var hold = document.createElement("span");
    hold.className = "t-reel-static";
    hold.textContent = str;
    root.appendChild(hold);
  }

  function buildReel(root, value, options) {
    options = options || {};
    var spins = options.spins == null ? 2 : options.spins;
    var str = String(value).padStart(2, "0");
    var reduce = prefersReduce();
    if (reduce) {
      freezeReel(root, value);
      return;
    }
    root.replaceChildren();
    var cell = cellPx(root);
    root.style.setProperty("--reel-cell", cell + "px");

    str.split("").forEach(function (ch, col) {
      var digit = Number(ch);
      var colEl = document.createElement("span");
      colEl.className = "t-reel-col";
      var strip = document.createElement("span");
      strip.className = "t-reel-strip";
      var copies = reduce ? 1 : spins + 1;
      for (var s = 0; s < copies; s += 1) {
        for (var n = 0; n < 10; n += 1) {
          var d = document.createElement("span");
          d.className = "t-reel-digit";
          d.textContent = String(n);
          strip.appendChild(d);
        }
      }
      colEl.appendChild(strip);
      root.appendChild(colEl);
      var target = reduce ? digit : spins * 10 + digit;
      requestAnimationFrame(function () {
        strip.style.transition = reduce
          ? "none"
          : "transform var(--reel-dur) var(--reel-ease) " + col * 90 + "ms";
        strip.style.transform = "translateY(" + -(target * cell) + "px)";
      });
    });
  }

  function countHud(el, from, to, duration, onUpdate) {
    if (prefersReduce() || typeof anime !== "function") {
      el.textContent = String(to);
      if (onUpdate) onUpdate(to);
      return;
    }
    var obj = { n: from };
    anime({
      targets: obj,
      n: to,
      round: 1,
      easing: "easeOutExpo",
      duration: duration,
      update: function () {
        el.textContent = String(obj.n);
        if (onUpdate) onUpdate(obj.n);
      }
    });
  }

  function showCheck(el) {
    el.setAttribute("data-state", "out");
    void el.offsetWidth;
    el.setAttribute("data-state", "in");
    var path = el.querySelector("svg path");
    if (path && path.getTotalLength) {
      var len = Math.ceil(path.getTotalLength()) + 1;
      path.style.strokeDasharray = String(len);
      path.style.strokeDashoffset = String(len);
    }
  }

  global.PoseScore = {
    setDigits: setDigits,
    buildReel: buildReel,
    freezeReel: freezeReel,
    countHud: countHud,
    showCheck: showCheck,
    prefersReduce: prefersReduce
  };
})(window);
