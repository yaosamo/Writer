// Light / dark toggle. Follows the system until the visitor picks one; the choice is remembered.
(function () {
  var root = document.documentElement;
  var button = document.querySelector(".theme-toggle");
  if (!button) return;
  var media = window.matchMedia("(prefers-color-scheme: dark)");

  function current() {
    return root.dataset.theme || (media.matches ? "dark" : "light");
  }
  function label() {
    button.setAttribute("aria-label", current() === "dark" ? "Switch to light mode" : "Switch to dark mode");
  }

  button.addEventListener("click", function () {
    var next = current() === "dark" ? "light" : "dark";
    root.dataset.theme = next;
    try { localStorage.setItem("theme", next); } catch (e) {}
    label();
  });
  media.addEventListener("change", label);
  label();
})();
