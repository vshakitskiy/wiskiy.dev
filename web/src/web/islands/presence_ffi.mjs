export function connect(url, on_open, on_message, on_close) {
  let socket;

  try {
    socket = new WebSocket(url);
  } catch (_error) {
    on_close();
    return undefined;
  }

  socket.addEventListener("open", () => on_open(socket));
  socket.addEventListener("message", (event) => {
    if (typeof event.data === "string") on_message(event.data);
  });

  socket.addEventListener("close", () => on_close());

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
