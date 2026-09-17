---
title = "How I made my own web server in Gleam"
date = "2025-10-19"
description = "Making a web server is a fun and challenging project. And what could be better than using your favorite technology to build it?"
public = true
tags = ["gleam"]
---

This is my first article ever. I’m not really fluent in English, and I sometimes have issues expressing my thoughts clearly, so I apologize if this article feels messy. Also keep in mind that my posts won’t be AI slop. I will use AI as little as possible because I want to write down my own thoughts, the way I see them, without relying on models trained on other people's work.

---

## Introduction

I have quite a lot of free time, and for the last year I noticed I was spending much of that precious time procrastinating, like watching entertainment content or just browsing TikTok. One day I realized this is not how I want to spend my final student years. So I dedicated much more time to something I was interested in: web development. For most of my college years I built simple React + Next.js + TypeScript projects and I felt like I was wasting my time on something I didn't truly enjoy. That’s when I decided to switch my career goal from frontend to backend development. All the server-side stuff was always interesting to me, but I saw it as a more difficult area. I looked at the first things people try to build and deploy on the server side, like an API, and thought: how do web frameworks even work? That’s when I set my first small goal: build my own tool for web developers to use.

At that time, I was a bit of a fan of *TypeScript*, so my first thought was building a web framework with it. I picked *Deno* as a runtime and began developing [*sakura*](https://github.com/vshakitskiy/sakura). The whole idea of the project was built around a whimsical philosophy that the web application is like a tree, and I named everything with fancy words like `branch` as a router for different routes, or `seed` as basically context for each request. The router was intended to be used as a pipe. Each router method returned the same router instance to be piped again, and middleware was applied to the next piped routes but not to the previous ones. Here's an example of what code with `sakura` looked like:

```tsx
import { bloom, fall, pluck, sakura } from "@vsh/sakura"

// Define the time we started the server at
const uptime = Date.now()

// Seed is generated on every request. We can pass any utilities inside it.
const { branch, seed } = sakura((req, cookies) => ({
  req,
  cookies,
  runtime: Date.now() - uptime,
}))

// Create branch with /ping, /runtime and /secret endpoints
const app = branch()
  .get("/ping", () => fall(200, { message: "pong" }))
  .get("/runtime", ({ seed: { runtime } }) => fall(200, { runtime }))
  .with((seed) => {
    // get cookie for secret
    const { secret } = seed.cookies.get<"secret">()

    if (!secret) {
      // exit mutation with the response
      throw pluck(400, {
        message: "secret is not provided.",
      })
    }

    // return new seed
    return {
      ...seed,
      secret,
    }
  })
  .get("/secret", ({ seed: { secret } }) => fall(200, { secret }))

// start the server
bloom({
  // Seed generator
  seed,
  // Branch to run
  branch: app,

  // Runs on error
  error: () => fall(500, { message: "try again later" }),
  // Runs if petal is not found
  unknown: () => fall(404, { message: "unknown endpoint" }),
  // Runs if Content-Type is not application/json
  unsupported: () => fall(415, { message: "body must be json" }),

  port: 4040,
  // Log on each request
  logger: true,
})
```

This worked quite nicely for a simple HTTP web framework, but I was not satisfied, and I knew no one would pick `sakura` as their web framework among hundreds of better options. That's when I gave up on this project and fell off the radar for quite some time. After a few months, I changed my language preferences and stopped touching TypeScript for a while. But in the end, I still had no interesting projects to include on my resume… until recently!

## Developing a web server with Gleam

While attempting to build a simple infrastructure with microservices and gRPC in Go, I realized I lacked knowledge of topics that even a beginner should know for my future role. This was concerning. If I want to be a good developer, I should know a lot about how computers work internally and how devices communicate over a network. And what could be better than studying a topic by building a cool project related to it? So I came back to build a web development tool again, but this time something more low level: a web server.

Remember I said I changed my language preferences? Besides trying out *Go*, I've been actively using a statically typed functional programming language that is part of the *Erlang* ecosystem, called [*Gleam*](https://gleam.run). I instantly fell in love with it, and my first thoughts were like: “Wow, it’s so simple and yet I can build everything with it!” Sure, it’s young and not as popular as other technologies, and as an intern-level student there are no job positions I can apply to related to Gleam, but I locked in on using it for my projects, or at least actively peeking into the Discord community, where people were showing cool projects they built using this language. And I wanted to post something too.

That's where I decided to kill two birds with one stone: I would build a web server with *Gleam* while sharing the progress with the community on Discord. That is how I started working on [***ewe***](https://github.com/vshakitskiy/ewe), the fluffy *Gleam* web server. Since the 1.0 release of the language happened only a year ago, the *Gleam* ecosystem is not strong yet, so there are a lot of opportunities to develop packages for many topics, including web servers. Right now (as far as I know, reach out to me if I'm wrong) there is only one pure Gleam web server for the *Erlang* target called [*mist*](https://github.com/rawhat/mist). This creates a situation where everything depends on a single package, and no friendly competition pushes it toward faster and stronger progression with new features. This is something I also plan to address: create a friendly competitor that will lead to more active development on the web server side.

## So, what really is a web server?

To answer this, we need to understand how devices like a client and server communicate. The most popular way is via a *socket*. It's a simple communication channel through which two programs communicate over a network. A server program creates a socket at a certain *port*, which is a particular entry point on the host computer, and waits until a client requests a connection. When the connection is established, the server creates input and output streams to the socket and begins sending and receiving messages. The client also creates a socket and attempts to make a connection to the server at the provided address and port where the service exists. In the same way as the server, it creates input and output streams to the socket. After communication, the client is usually responsible for closing the connection, though the server can also close it if needed. On top of sockets, engineers created standardized sets of rules, also known as *transport protocols* like *TCP* (Transmission Control Protocol) and *UDP* (User Datagram Protocol). There is a huge difference between them, and we will look at *TCP* since it is essential for the web, email systems, and more.

*TCP* is a connection-oriented protocol. It means that devices should establish a connection before transmitting data and should close the connection after transmitting all the data. It is reliable as it guarantees the delivery of data to the destination. The connection is established with a [*three-way handshake*](https://www.geeksforgeeks.org/computer-networks/tcp-3-way-handshake-process/). During this handshake the client and server exchange initial sequence numbers and confirm the connection establishment. After that they are ready to send packets of data as they please. *TCP* is used by other popular protocols that describe the structure of requests and responses, like *HTTP*, which is the main gear of the whole web ecosystem we have nowadays.

Coming back to the question of a web server, it is a program that runs on a server device and handles requests from clients using *HTTP* or *HTTPS*. With that in mind, I will move forward on how *ewe* was built, from zero to probably production-ready software.

## Receiving packets & parsing HTTP

I began by choosing how to work with *TCP*. The best option was to use the [*glisten*](https://github.com/rawhat/glisten) package that provides a supervisor over a pool of *socket acceptors*. It also has support for *TLS* (Transport Layer Security), which is used for *HTTPS*. This way the *TCP* handshake and the whole connection were handled with ease, so I could work on all the interesting web server features.

My first challenge was parsing received packets. I implemented my own parser to handle converting raw bytes into *HTTP* request parts: request line, headers, and body (including *chunked transfer encoding*). Here's what the initial concept looked like:

```gleam
import gleam/bytes_tree
import gleam/option.{None}
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import glisten
import internal/parser

pub fn start(
  port port: Int,
) -> Result(actor.Started(supervisor.Supervisor), actor.StartError) {
  glisten.new(
    // Initialize the parser on each connection
    fn(_conn) { #(parser.new_parser(), None) },
    // Process each packet that arrives
    fn(state, msg, conn) {
      let assert glisten.Packet(msg) = msg

      // Append new data to our buffer
      let parser =
        parser.Parser(..state, buffer: <<state.buffer:bits, msg:bits>>)

      // Try to parse what we have so far
      case parser.parse_request(parser) {
        Ok(_request) -> {
          // Success! We will send a dummy response for now
          let response = <<
            "HTTP/1.1 200 OK\r\nContent-Length: 13\r\n\r\nHello, world!",
          >>

          let _ =
            response
            |> bytes_tree.from_bit_array()
            |> glisten.send(conn, _)

          // Reset parser for the next request
          glisten.continue(parser.new_parser())
        }

        Error(error) -> {
          case error {
            // Not enough data yet, so we keep accumulating
            parser.Incomplete(parser) -> glisten.continue(parser)

            // Invalid HTTP request, reject it
            parser.Invalid -> {
              let _ =
                glisten.send(
                  conn,
                  <<"HTTP/1.1 400 Bad Request\r\n\r\n">>
                    |> bytes_tree.from_bit_array,
                )
              glisten.stop()
            }

            // Request body is too large, reject it
            parser.TooLarge -> {
              echo "Too large"
              glisten.stop()
            }

            _ -> glisten.stop()
          }
        }
      }
    },
  )
  |> glisten.bind("0.0.0.0")
  |> glisten.start(port)
}
```

> One important thing to mention is that packets can arrive in fragments. You might receive `"GET / H"` in one packet and `"TTP/1.1\r\n…"` in the next. The parser needs to accumulate these fragments in a buffer until it has enough data to parse a complete *HTTP* request.

This parser worked for basic test cases, but I quickly realized it had problems. For example, the parser wasn't following best practices as I was implementing my own *HTTP* request type instead of using the official [*gleam\_http*](https://github.com/gleam-lang/http) package that is used in every Gleam project related to *HTTP*. Also, with that parser logic, the whole request body was loaded into memory. What if there is a very big body stream? Or what if the request handler doesn't need to read the body at all? That could lead to the parser wasting too much time on a single request. With quick brainstorming and suggestions from the Gleam community, I learned better approaches and refactored everything.

## Refactoring the whole codebase

Gleam is great because we can use external functions and types from the runtime. Since Gleam compiles to *Erlang*, we can use its battle-tested functions directly. Instead of writing my own *HTTP* parser (which was slow and buggy), I discovered [`erlang:decode_packet`](https://www.erlang.org/doc/apps/erts/erlang.html#decode_packet/3), which has been used for parsing *HTTP* for decades. It is incredibly efficient and handles *HTTP* edge cases I hadn't even thought about. In the end, I built a wrapper on top of it to make the function work nicely with Gleam:

```erlang
% Finalized version used in v1 of ewe
decode_packet(Type, Packet, Options) ->
  case erlang:decode_packet(Type, Packet, Options) of
      % HTTP request line
    {ok, {http_request, Method, Uri, Version}, Rest} ->
      {ok, {packet, {http_request, atom_to_binary(Method), Uri, Version}, Rest}};
      
    % HTTP header
    {ok, {http_header, Idx, _, Field, Value}, Rest} ->
      {ok, {packet, {http_header, Idx, Field, Value}, Rest}};
      
    % Potential body data or end of headers
    {ok, Bin, Rest} ->
      {ok, {packet, Bin, Rest}};
      
    % Need more data
    {more, undefined} ->
      {ok, {more, none}};
    {more, Length} ->
      {ok, {more, {some, Length}}};
      
    {error, Reason} ->
      {error, Reason}
  end.
```

Another major change was inspired by how the *mist* web server handles the request body. Instead of loading the entire body into memory, I exposed an internal *Connection* type to the user:

```gleam
pub type Connection {
  Connection(
    transport: Transport,
    socket: Socket,
    // ...
  )
}
```

Users can call a function like `ewe.read_body(req, 1024)` to read 1 KB, or ignore the body entirely for requests that don't need it. This also opens opportunities for protocol upgrades to *WebSocket*, for example.

After expanding the API with helper functions and polishing the codebase, I released version 0.3, which was the initial version I shared with the Gleam community. I received supportive comments from Gleam team members as well as the creator of the `mist` web server. I'm the kind of person who really loves attention, so this gave me huge motivation to make my package better and better. After some time, I implemented [*keep-alive*](https://en.wikipedia.org/wiki/HTTP_persistent_connection) behavior that allows the client to reuse the connection when it's appropriate, which allows my web server to support *HTTP/1.1*. I knew that a simple *HTTP/1.0* & *HTTP/1.1* server was relatively straightforward to implement, so the next thing I did was level up the difficulty and move toward implementing a protocol I had zero internal knowledge about: *WebSockets*.

## WebSockets

*WebSocket* is a protocol that provides a bidirectional communication channel over a single *TCP* connection, making it possible for a client to send messages to a server and receive responses without having to poll the server for a reply. It's built on top of *HTTP* and requires quite a lot of steps to create a fully compliant implementation.

The process starts with an *HTTP* handshake request that looks like this:

```
GET / HTTP/1.1
Host: [example.com](http://example.com)
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
```

It indicates that the connection is going to be upgraded to the *WebSocket* protocol. There is also a special *WebSocket* key, which is used later to send a response with the `Sec-WebSocket-Accept` header:

```
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
```

The goal is to make the server accept connections that were specifically intended to be *WebSocket* connections. The `Sec-WebSocket-Accept` value isn't random. It's derived by taking the client's key, appending the [*magic string*](https://en.wikipedia.org/wiki/Magic_string), hashing, and encoding the result.

After the handshake, here's where it gets tricky. *WebSocket* messages arrive as *frames*, structured packets that can be text, binary, ping/pong, or close signals. It's important to mention that a single message can be split across multiple frames. So I needed a way to continuously read from the socket and handle these frames.

The first thing is reading from *TCP*. The solution was using a simple trick that I learned by looking at internal files of the `glisten` package:

```gleam
pub type ValidGlistenMessage {
  // New data arrived
  Packet(BitArray)
  // Connection closed
  Close
}

pub type GlistenMessage {
  Valid(ValidGlistenMessage)
  Invalid
}

// In simple terms, this function "subscribes" to TCP events
fn select_valid_record(
  selector: process.Selector(GlistenMessage),
  binary_atom: String,
) -> process.Selector(GlistenMessage) {
  process.select_record(selector, atom.create(binary_atom), 2, fn(record) {
    decode.run(record, {
      use data <- decode.field(2, decode.bit_array)
      decode.success(Valid(Packet(data)))
    })
    |> result.unwrap(Invalid)
  })
}

fn glisten_selector() {
  process.new_selector()
  // Include regular connections
  |> select_valid_record("tcp")
  // Include secure connections
  |> select_valid_record("ssl")
  // Include TCP closing events
  |> process.select_record(atom.create("tcp_closed"), 1, fn(_) { Valid(Close) })
  |> process.select_record(atom.create("ssl_closed"), 1, fn(_) { Valid(Close) })
}
```

In *Erlang*, when data arrives on a *TCP* socket, the runtime sends a message to a controlling process in a format like `{tcp, Socket, Data}`. The [`process.select_record`](https://hexdocs.pm/gleam_erlang/gleam/erlang/process.html#select_record) function helps us intercept these messages.

With the selector in place, I created an *actor* to manage each connection:

```gleam
pub fn start(
  transport: transport.Transport,
  socket: socket.Socket,
  handler: fn(ws.Frame) -> Next,
) {
  actor.new_with_initialiser(1000, fn(subject) {
    let conn = WebsocketConnection(transport, socket)
    actor.initialised(State(conn, <<>>))
    // Listen for TCP events
    |> actor.selecting(glisten_selector())
    |> actor.returning(subject)
    |> Ok
  })
  |> actor.on_message(fn(state, msg) {
    case msg {
      // New data - parse and handle frames
      Valid(Packet(data)) ->
        handle_valid_packet(state, data, transport, socket, handler)
      // Connection closed
      Valid(Close) -> actor.stop()
      
      // Something wrong with the data
      Invalid -> actor.stop_abnormal(malformed_message_error)
    }
  })
  |> actor.start()
  |> result.map(after_start(_, transport, socket))
}
```

*WebSocket* frames have a complex structure. They include *opcodes*, masking information, and more. Thanks to the [*gramps*](https://github.com/rawhat/gramps) package, I didn't have to implement all the bit manipulation myself and could focus on handling parsed *WebSocket* frames:

```gleam
fn loop_by_frames(
  frames: List(ws.Frame),
  transport: transport.Transport,
  socket: socket.Socket,
  handler: fn(ws.Frame) -> Next,
  next: Next,
) {
  case frames, next {
    // Early termination, user asked to stop
    _, Stop(Normal) -> Stop(Normal)
    _, Stop(Abnormal(reason)) -> Stop(Abnormal(reason))

    // No more frames so we are done here
    [], next -> next

    // Ping must be responded with pong
    [ws.Control(ws.PingFrame(payload))], Continue -> {
      let sent =
        transport.send(transport, socket, ws.encode_pong_frame(payload, None))

      case sent {
        Ok(Nil) -> Continue
        Error(_) -> Stop(Abnormal("Failed to send PONG frame"))
      }
    }
    
    // Client wants to close, so we acknowledge and stop
    [ws.Control(ws.CloseFrame(reason))], Continue -> {
      let _ =
        transport.send(transport, socket, ws.encode_close_frame(reason, None))

      Stop(Normal)
    }

    // Data frames, pass to the user handler
    [frame, ..rest], Continue -> {
      case exception.rescue(fn() { handler(frame) }) {
        Ok(Continue) ->
          loop_by_frames(rest, transport, socket, handler, Continue)
        Ok(stop) -> stop
        Error(_) -> Stop(Abnormal("Crash in websocket handler"))
      }
    }
  }
}
```

After implementing a simple *WebSocket* server, I managed to support custom user state, custom messages, and *permessage-deflate* (also thanks to `gramps`). The public API of *WebSocket* became clearer, with support for sending frames back to the client. Then I moved forward to polish everything I had, making sure the API was not overcomplicated and the protocols followed the requirements.

## Making web server even better

Getting the protocols working was only half the battle. Making the protocols follow their specifications and polishing the API was harder. For example, each response from the user handler should contain *ResponseBody*. At first, it was an *opaque type*, and there were constructors for each case, like `ewe.text` or `ewe.string_tree`. They set the response body from different Gleam types, as well as the required headers. The flow for a user would be:

```gleam
fn handle_request(req: Request(ewe.Connection)) -> Response(ewe.ResponseBody) {
  case request.path_segments(req) {
    ["hello", name] ->
      response.new(200)
      |> ewe.text("Hello, " <> name <> "!")
    _ -> 
      response.new(404)
      |> ewe.empty()
  }
}
```

It was very convenient, but it was more of a web framework function than a web server function. The web server's role is to provide a minimal interface. With that in mind, I removed every abstraction on top of *ResponseBody*, so that the user handles everything outside the web server logic:

```gleam
fn handle_request(req: Request(ewe.Connection)) -> Response(ewe.ResponseBody) {
  case request.path_segments(req) {
    ["hello", name] ->
      response.new(200)
      |> response.set_header("content-type", "text/plain")
      |> response.set_body(ewe.TextData("Hello, " <> name <> "!"))
    _ -> 
      response.new(404)
      |> ewe.empty()
  }
}
```

I also made sure [*HTTP/1.1 RFC*](https://www.rfc-editor.org/rfc/rfc9110.html) specifications were followed, like [validation of *HTTP* fields](https://www.rfc-editor.org/rfc/rfc9110.html#name-field-values), as this can prevent *header injection* attacks from malicious clients:

```erlang
% HTTP field values can contain:
% - VCHAR: 0x21-0x7E (visible ASCII characters)
% - WSP: 0x20 (space), 0x09 (tab)
% - obs-text: 0x80-0xFF (for backward compatibility)
% Invalid: control characters 0x00-0x08, 0x0A-0x1F, 0x7F
do_validate_field_value(Value) ->
  case Value of
    <<>> ->
      true;
    <<C, Rest/bitstring>>
      when C =:= 16#09
           orelse C >= 16#20 andalso C =< 16#7E
           orelse C >= 16#80 andalso C =< 16#FF ->
      do_validate_field_value(Rest);
    _ ->
      false
  end.
```

As for *WebSockets*, [Louis Pilfold](https://lpil.uk/), creator of Gleam, advised trying *[Autobahn](https://websocket.org/guides/testing/autobahn/)* on the *WebSocket* implementation. This test suite was brutal but educational, as it helped me uncover issues in my *WebSocket* implementation, such as *fragmented control frames* (which are not allowed by the specs) or *ping frames* over 125 bytes. I even opened a [PR](https://github.com/rawhat/gramps/pull/7) to the `gramps` package to fix some important internal issues. I was so proud of myself when all 400+ tests showed a green "OK" status — such a blessing to a developer's eyes!

While I was doing this project, I was talking with my college professors about how I wanted to make the web server my final year diploma thesis. Since I’m in computer science, specifically backend development, the project idea fit perfectly.

After I was done with *WebSocket*, I decided to benchmark *ewe* against other web servers. I was not expecting high numbers, just hoping it would be good enough in comparison with popular servers. I was shocked when I realized that according to [my benchmark](https://github.com/vshakitskiy/ewe_http_benchmark) it is pretty fast! (Note that this was run on my homelab in one of the hosted virtual machines and results could be inaccurate.)

However, I had completely forgotten an important detail: a response from the server should include a `Date` header if the server has a clock. Of course, in modern realities almost every device has a clock, so the `Date` header must be implemented. *ewe* implements it the same way as *mist*: a separate *application* that manages time calculation.

```gleam
type Message {
  Tick
}

// clock module is an application, so it should have start and stop interfaces
pub fn start(_type, _args) -> Result(process.Pid, actor.StartError) {
  actor.new_with_initialiser(1000, fn(subject) {
    init_clock_storage()
    set_http_date(calculate_http_date())
    process.send_after(subject, 1000, Tick)

    actor.initialised(subject)
    |> actor.returning(subject)
    |> Ok
  })
  |> actor.on_message(fn(subject, _msg) {
    process.send_after(subject, 1000, Tick)

    set_http_date(calculate_http_date())

    actor.continue(subject)
  })
  |> actor.start()
  |> result.map(fn(started) {
    let assert Ok(pid) = process.subject_owner(started.data)
    pid
  })
}

pub fn stop(_state) {
  atom.create("ok")
}

pub fn get_http_date() -> String {
  case lookup_http_date() {
    Ok(date) -> date
    Error(Nil) -> {
      logging.log(
        logging.Warning,
        "Failed to look up HTTP date, calculating a new one",
      )
      calculate_http_date()
    }
  }
}

```

With the *clock actor*, the web server naturally became a bit slower since it required more internal steps, but it still held its own and performed at a similar speed to *mist*! That was exciting!

Finally, in the middle of September, I announced the first release candidate in a Discord channel dedicated to *ewe*. I received some feedback, as well as some internal bug reports, which I quickly fixed. Then I moved forward to the final feature before the official release: *Server-Sent Events*.

## Server-Sent Event

*Server-Sent Events* is a server push technology that enables a client to receive updates from a server via an *HTTP* connection. It's like *WebSocket*, but it's only a one-way connection, meaning clients can't send events to a server. There's also an interesting feature: if the connection drops, clients like browsers automatically try to reconnect. The protocol itself is pretty elegant. Here's an example of the flow:

```
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache

data: Wibble Wobble

event: user_joined
data: {"username": "admin"}

data: You can also split messages
data: across multiple data lines
```

After implementing *WebSocket*, making *Server-Sent Events* was an easy task. I reused almost everything I learned during its development:

```gleam
pub type SSEMessages(user_message) {
  // Custom message
  User(user_message)
  // TCP connection closed
  Close
}

fn create_socket_selector(
  user_subject: Subject(user_message),
) -> Selector(SSEMessages(user_message)) {
  process.new_selector()
  // Listen for messages from other parts of the application
  |> process.select_map(user_subject, fn(msg) { User(msg) })
  // Listen for TCP close events
  |> process.select_record(atom.create("tcp_closed"), 1, fn(_) { Close })
  |> process.select_record(atom.create("ssl_closed"), 1, fn(_) { Close })
}
```

The selector doesn't listen for general `tcp`/`ssl` events, as the client will never send any messages to our server. Then I created an *actor* that handled these messages:

```gleam
pub fn start(
  transport: Transport,
  socket: Socket,
  on_init: fn(Subject(user_message)) -> user_state,
  handler: fn(SSEConnection, user_state, user_message) -> SSENext(user_state),
  on_close: fn(SSEConnection, user_state) -> Nil,
) -> Result(Selector(process.Down), actor.StartError) {
  actor.new_with_initialiser(1000, fn(_subject) {
    let subject = process.new_subject()
    // User initializes their state
    let state = on_init(subject)
    let selector = create_socket_selector(subject)

    actor.initialised(state)
    |> actor.returning(subject)
    |> actor.selecting(selector)
    |> Ok
  })
  |> actor.on_message(fn(state, message) {
    case message {
      // Handle user messages in the handler
      User(message) -> {
        let conn = SSEConnection(transport, socket)
        case handler(conn, state, message) {
          Continue(new_state) -> actor.continue(new_state)
          NormalStop -> {
            on_close(conn, state)
            actor.stop()
          }
          AbnormalStop(reason) -> {
            on_close(conn, state)
            actor.stop_abnormal(reason)
          }
        }
      }
      // Connection closed
      Close -> {
        on_close(SSEConnection(transport, socket), state)
        actor.stop()
      }
    }
  })
  |> actor.start()
  |> result.map(fn(started) {
    let assert Ok(pid) = process.subject_owner(started.data)
    // Transfer socket control to the actor
    let _ = transport.controlling_process(transport, socket, pid)
    set_socket_active(transport, socket)

    // Return a selector that monitors the actor
    process.select_specific_monitor(
      process.new_selector(),
      process.monitor(pid),
      function.identity,
    )
  })
}
```

I built a simple [real-time chat](https://github.com/vshakitskiy/ewe/tree/mistress/examples/sse) to test it: clients connect to an *SSE* endpoint, and when anyone POSTs a message, it broadcasts to all connected clients. It worked almost on the first try, which felt amazing after the struggles with *WebSocket*.

## What's Next?

With version 1.0 released, *ewe* supports *HTTP/1.0*, *HTTP/1.1*, *WebSockets*, and *Server-Sent Events*. It handles *streaming request bodies*, *chunked responses*, and *file streaming*. For a v1, this is a great start. The next goal is getting *ewe* integrated into [*Wisp*](https://github.com/gleam-wisp/wisp), Gleam's most popular web framework. Right now it's only working with *mist*, but I already [opened a PR](https://github.com/gleam-wisp/wisp/pull/146) to include *ewe* as another web server provider.

Then, there's *HTTP/2*. Honestly, it is a completely different beast, and I think it will take some time just to understand the specification, let alone implement it correctly. But it's not impossible. I will slowly make it real, so no worries here.

---

During the development of my web server I learned a lot about Gleam itself, as well as networks and protocols. I really want to express a huge thank you for all the support and suggestions I received from the Gleam community during development. This is the warmest and most active [place](https://gleam.run/community/) I've ever encountered, and I will continue to promote and use Gleam as my most loved technology ever.
