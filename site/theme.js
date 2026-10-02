// Light / dark toggle. Follows the system until the visitor picks one; the choice is remembered.
(function () {
  var root = document.documentElement;
  var buttons = document.querySelectorAll(".theme-toggle");
  if (!buttons.length) return;
  var media = window.matchMedia("(prefers-color-scheme: dark)");

  function current() {
    return root.dataset.theme || (media.matches ? "dark" : "light");
  }
  function label() {
    var text = current() === "dark" ? "Switch to light mode" : "Switch to dark mode";
    buttons.forEach(function (button) { button.setAttribute("aria-label", text); });
  }

  buttons.forEach(function (button) {
    button.addEventListener("click", function () {
      var next = current() === "dark" ? "light" : "dark";
      root.dataset.theme = next;
      try { localStorage.setItem("theme", next); } catch (e) {}
      label();
    });
  });
  media.addEventListener("change", label);
  label();
})();
