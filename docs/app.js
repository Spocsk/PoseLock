(function () {
  "use strict";

  var root = document.documentElement;
  var header = document.querySelector("[data-header]");
  var story = document.querySelector("[data-story]");
  var prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  var storyLabels = ["PRÉPARE TA POSE", "93 · TIENS LA LIGNE", "LOCK · PHOTO GARDÉE"];
  var ticking = false;
  var lastStoryIndex = -1;

  function clamp(value, min, max) {
    return Math.min(Math.max(value, min), max);
  }

  function setReady() {
    window.requestAnimationFrame(function () {
      root.classList.add("is-ready");
    });
  }

  function updateHeader() {
    if (!header) return;
    header.classList.toggle("is-scrolled", window.scrollY > 24);
  }

  function updateHeroParallax() {
    if (prefersReducedMotion.matches) return;
    var art = document.querySelector("[data-hero-art]");
    if (!art || window.scrollY > window.innerHeight * 1.15) return;
    var drift = clamp(window.scrollY * 0.075, 0, 50);
    art.style.transform = "translate3d(0, " + drift + "px, 0) scale(1)";
  }

  function setStoryIndex(index) {
    if (!story || index === lastStoryIndex) return;
    lastStoryIndex = index;
    story.setAttribute("data-active", String(index));

    story.querySelectorAll("[data-story-step]").forEach(function (step) {
      step.classList.toggle("is-active", Number(step.getAttribute("data-story-step")) === index);
    });

    story.querySelectorAll("[data-story-screen]").forEach(function (screen) {
      screen.classList.toggle("is-active", Number(screen.getAttribute("data-story-screen")) === index);
    });

    var state = story.querySelector("[data-story-state]");
    if (state) state.textContent = storyLabels[index];
  }

  function updateStory() {
    if (!story) return;
    var rect = story.getBoundingClientRect();
    var distance = Math.max(story.offsetHeight - window.innerHeight, 1);
    var progress = clamp(-rect.top / distance, 0, 1);
    var index = Math.min(2, Math.floor(progress * 3));
    var progressBar = story.querySelector("[data-story-progress]");

    setStoryIndex(index);
    if (progressBar) progressBar.style.transform = "scaleX(" + progress.toFixed(4) + ")";
  }

  function updateScrollEffects() {
    updateHeader();
    updateHeroParallax();
    updateStory();
    ticking = false;
  }

  function requestScrollUpdate() {
    if (ticking) return;
    ticking = true;
    window.requestAnimationFrame(updateScrollEffects);
  }

  function setupReveal() {
    var items = document.querySelectorAll("[data-reveal]");
    if (prefersReducedMotion.matches || !("IntersectionObserver" in window)) {
      items.forEach(function (item) { item.classList.add("is-visible"); });
      return;
    }

    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.12 });

    items.forEach(function (item) { observer.observe(item); });
  }

  function setupTilt() {
    if (prefersReducedMotion.matches || !window.matchMedia("(hover: hover)").matches) return;

    document.querySelectorAll("[data-tilt]").forEach(function (item) {
      item.addEventListener("pointermove", function (event) {
        var bounds = item.getBoundingClientRect();
        var x = (event.clientX - bounds.left) / bounds.width - 0.5;
        var y = (event.clientY - bounds.top) / bounds.height - 0.5;
        item.style.setProperty("--ry", (x * 3.2).toFixed(2) + "deg");
        item.style.setProperty("--rx", (-y * 3.2).toFixed(2) + "deg");
      });
      item.addEventListener("pointerleave", function () {
        item.style.setProperty("--ry", "0deg");
        item.style.setProperty("--rx", "0deg");
      });
    });
  }

  function setYear() {
    var year = document.querySelector("[data-year]");
    if (year) year.textContent = String(new Date().getFullYear());
  }

  setYear();
  setupReveal();
  setupTilt();
  setStoryIndex(0);
  setReady();
  updateScrollEffects();

  window.addEventListener("scroll", requestScrollUpdate, { passive: true });
  window.addEventListener("resize", requestScrollUpdate, { passive: true });
  prefersReducedMotion.addEventListener("change", function () {
    root.classList.add("is-ready");
    requestScrollUpdate();
  });
})();
