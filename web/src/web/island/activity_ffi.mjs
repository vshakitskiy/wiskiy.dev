const placements = new WeakMap();

export function position_tooltip(id) {
  const tooltip = document.getElementById(id);
  if (!tooltip) return undefined;

  let place = placements.get(tooltip);
  if (!place) {
    const container = tooltip.offsetParent;
    if (!container) return undefined;

    place = () => {
      const anchor = document.getElementById(tooltip.dataset.anchor);
      if (!anchor) return;

      const bounds = container.getBoundingClientRect();
      const cell = anchor.getBoundingClientRect();

      tooltip.style.setProperty(
        "--tooltip-anchor-x",
        `${cell.left + cell.width / 2 - bounds.left}px`,
      );
      tooltip.style.setProperty(
        "--tooltip-anchor-y",
        `${cell.top - bounds.top}px`,
      );
    };

    const observer = new ResizeObserver(place);
    observer.observe(container);
    container.querySelector(".activity-grid")?.addEventListener(
      "scroll",
      place,
      { passive: true },
    );
    placements.set(tooltip, place);
  }

  place();
  return undefined;
}
