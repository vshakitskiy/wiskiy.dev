export function after(milliseconds, run) {
  setTimeout(run, milliseconds);
  return undefined;
}

export function after_visible(milliseconds, run) {
  return after(milliseconds, () => {
    if (!document.hidden) return run();

    function resume() {
      if (document.hidden) return;

      document.removeEventListener("visibilitychange", resume);
      run();
    }

    document.addEventListener("visibilitychange", resume);
  });
}

export function focus(id) {
  document.getElementById(id)?.focus();
  return undefined;
}
