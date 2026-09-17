// A socket that is still CONNECTING can be collected when nothing holds a
// reference to it: the object and its listener closures point only at each
// other, so the cycle has no root. Gleam is not handed the socket until `open`
// fires, which is exactly that window — the handshake never finishes and no
// message ever arrives. Engines differ on how tolerant they are here, so the
// socket is rooted for its whole lifetime rather than left to chance.
const connections = new Set();

export function connect(url, on_open, on_message, on_close) {
  let socket;

  try {
    socket = new WebSocket(url);
  } catch (_error) {
    on_close();
    return undefined;
  }

  connections.add(socket);

  socket.addEventListener("open", () => on_open(socket));
  socket.addEventListener("message", (event) => {
    if (typeof event.data === "string") on_message(event.data);
  });

  // An `error` event is always followed by `close`, so one handler covers both.
  socket.addEventListener("close", () => {
    connections.delete(socket);
    on_close();
  });

  return undefined;
}

export function send(socket, text) {
  if (socket.readyState === WebSocket.OPEN) socket.send(text);
  return undefined;
}

export function heartbeat(socket, milliseconds, payload) {
  const timer = setInterval(() => {
    if (socket.readyState === WebSocket.OPEN) socket.send(payload);
  }, milliseconds);

  socket.addEventListener("close", () => clearInterval(timer));

  return undefined;
}

export function after(milliseconds, run) {
  setTimeout(run, milliseconds);
  return undefined;
}

export function tick(milliseconds, run) {
  setTimeout(() => run(Date.now()), milliseconds);
  return undefined;
}
