export function embedded(id) {
  const node = document.getElementById(id);
  return node === null ? "" : node.textContent;
}
