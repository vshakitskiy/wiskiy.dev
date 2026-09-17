export function after(milliseconds, run) {
  setTimeout(run, milliseconds);
  return undefined;
}
