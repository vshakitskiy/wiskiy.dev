//// Discord presence from Lanyard over its websocket gateway.
////
//// Until the first payload arrives the island renders only the username. Once 
//// a presence lands a status dot appears next to the name and a SoundCloud
//// activity adds a track line above it.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/order
import gleam/string
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/element/keyed
import web/browser

pub const mount_id = "presence"

const username = "wiskiy"

const discord_id = "511911643475738656"

const socket_url = "wss://api.lanyard.rest/socket"

const reconnect_delay_milliseconds = 5000

const tick_interval_milliseconds = 1000

const track_exit_milliseconds = 400

const listening_activity = 2

// I am not sure whatever this id is persistent accross the devices
const soundcloud_application_id = "1090770350251458592"

pub fn main() -> Nil {
  let app = lustre.application(init:, update:, view:)
  let assert Ok(_) = lustre.start(app, onto: "#" <> mount_id, with: Nil)
  Nil
}

// MODEL -----------------------------------------------------------------------

pub type Socket

pub type Model {
  Model(connection: Connection, presence: Presence, clock: Clock)
}

pub type Connection {
  Connecting
  Open(socket: Socket)
  Closed
}

pub type Presence {
  Unknown
  Known(status: Status, listening: Listening)
}

pub type Status {
  Online
  Idle
  DoNotDisturb
  Offline
}

pub type Listening {
  Nothing
  Track(
    title: String,
    artist: String,
    artwork: option.Option(String),
    timing: Timing,
    playback: Playback,
  )
}

pub type Playback {
  Playing
  Ending
}

pub type Timing {
  Untimed
  Timed(start_milliseconds: Int, end_milliseconds: Int)
}

pub type Clock {
  Paused
  Ticking(now_milliseconds: Int)
}

pub fn init(_flags: Nil) -> #(Model, effect.Effect(Message)) {
  #(
    Model(connection: Connecting, presence: Unknown, clock: Paused),
    open_socket(),
  )
}

// UPDATE ----------------------------------------------------------------------

pub type Message {
  SocketOpened(socket: Socket)
  SocketSentText(text: String)
  SocketClosed
  ReconnectDelayElapsed
  Ticked(now_milliseconds: Int)
  TrackEnded
}

pub fn update(
  model: Model,
  message: Message,
) -> #(Model, effect.Effect(Message)) {
  case message {
    SocketOpened(socket:) -> #(
      Model(..model, connection: Open(socket)),
      subscribe(socket),
    )

    SocketSentText(text:) ->
      case json.parse(text, event_decoder()) {
        Error(_error) -> #(model, effect.none())
        Ok(Ignored) -> #(model, effect.none())
        Ok(Hello(heartbeat_interval:)) -> #(
          model,
          start_heartbeat(model.connection, heartbeat_interval),
        )
        Ok(PresenceReceived(presence:)) -> {
          let #(presence, exit) = settle(model.presence, presence)
          let model = Model(..model, presence:)
          #(model, effect.batch([start_clock(model), exit]))
        }
      }

    SocketClosed -> #(
      Model(..model, connection: Closed),
      reconnect_after(reconnect_delay_milliseconds),
    )

    ReconnectDelayElapsed -> #(
      Model(..model, connection: Connecting),
      open_socket(),
    )

    TrackEnded ->
      case model.presence {
        Unknown -> #(model, effect.none())
        Known(status:, listening: _finished) -> #(
          Model(..model, presence: Known(status:, listening: Nothing)),
          effect.none(),
        )
      }

    Ticked(now_milliseconds:) ->
      case timing_of(model.presence) {
        Untimed -> #(Model(..model, clock: Paused), effect.none())
        Timed(..) -> #(
          Model(..model, clock: Ticking(now_milliseconds:)),
          tick_after(tick_interval_milliseconds),
        )
      }
  }
}

fn timing_of(presence: Presence) -> Timing {
  case presence {
    Unknown -> Untimed
    Known(listening: Nothing, ..) -> Untimed
    Known(listening: Track(timing:, ..), ..) -> timing
  }
}

fn settle(
  previous: Presence,
  next: Presence,
) -> #(Presence, effect.Effect(Message)) {
  case previous, next {
    Known(
      listening: Track(title:, artist:, artwork:, timing:, playback: Playing),
      ..,
    ),
      Known(status:, listening: Nothing)
    -> #(
      Known(
        status:,
        listening: Track(title:, artist:, artwork:, timing:, playback: Ending),
      ),
      end_track_after(track_exit_milliseconds),
    )

    _earlier, _later -> #(next, effect.none())
  }
}

// EFFECTS ---------------------------------------------------------------------

fn open_socket() -> effect.Effect(Message) {
  use dispatch <- effect.from
  connect(
    url: socket_url,
    on_open: fn(socket) { dispatch(SocketOpened(socket:)) },
    on_message: fn(text) { dispatch(SocketSentText(text:)) },
    on_close: fn() { dispatch(SocketClosed) },
  )
}

fn subscribe(socket: Socket) -> effect.Effect(Message) {
  use _dispatch <- effect.from
  send(socket:, text: initialize_payload())
}

fn start_heartbeat(
  connection: Connection,
  milliseconds: Int,
) -> effect.Effect(Message) {
  case connection {
    Connecting | Closed -> effect.none()
    Open(socket:) -> {
      use _dispatch <- effect.from
      heartbeat(socket:, milliseconds:, payload: heartbeat_payload())
    }
  }
}

fn start_clock(model: Model) -> effect.Effect(Message) {
  case model.clock {
    Ticking(..) -> effect.none()
    Paused ->
      case timing_of(model.presence) {
        Untimed -> effect.none()
        Timed(..) -> tick_after(0)
      }
  }
}

fn tick_after(milliseconds: Int) -> effect.Effect(Message) {
  use dispatch <- effect.from
  use now <- tick(milliseconds:)
  dispatch(Ticked(now_milliseconds: now))
}

fn end_track_after(milliseconds: Int) -> effect.Effect(Message) {
  use dispatch <- effect.from
  use <- browser.after(milliseconds:)
  dispatch(TrackEnded)
}

fn reconnect_after(milliseconds: Int) -> effect.Effect(Message) {
  use dispatch <- effect.from
  use <- browser.after(milliseconds:)
  dispatch(ReconnectDelayElapsed)
}

fn initialize_payload() -> String {
  json.object([
    #("op", json.int(2)),
    #("d", json.object([#("subscribe_to_id", json.string(discord_id))])),
  ])
  |> json.to_string
}

fn heartbeat_payload() -> String {
  json.object([#("op", json.int(3))])
  |> json.to_string
}

// LANYARD PROTOCOL ------------------------------------------------------------

pub type Event {
  Hello(heartbeat_interval: Int)
  PresenceReceived(presence: Presence)
  Ignored
}

type Activity {
  Activity(
    kind: Int,
    application_id: option.Option(String),
    name: String,
    details: option.Option(String),
    state: option.Option(String),
    artwork: option.Option(String),
    timing: Timing,
  )
}

pub fn event_decoder() -> decode.Decoder(Event) {
  use op <- decode.field("op", decode.int)

  case op {
    1 -> {
      use heartbeat_interval <- decode.subfield(
        ["d", "heartbeat_interval"],
        decode.int,
      )
      decode.success(Hello(heartbeat_interval:))
    }

    0 -> {
      use name <- decode.field("t", decode.string)
      case name {
        "INIT_STATE" | "PRESENCE_UPDATE" -> {
          use presence <- decode.field("d", presence_decoder())
          decode.success(PresenceReceived(presence:))
        }
        _other -> decode.success(Ignored)
      }
    }

    _other -> decode.success(Ignored)
  }
}

fn presence_decoder() -> decode.Decoder(Presence) {
  use status <- decode.field("discord_status", status_decoder())
  use activities <- decode.field("activities", decode.list(activity_decoder()))
  decode.success(Known(status:, listening: now_listening(activities)))
}

fn status_decoder() -> decode.Decoder(Status) {
  use status <- decode.then(decode.string)
  case status {
    "online" -> decode.success(Online)
    "idle" -> decode.success(Idle)
    "dnd" -> decode.success(DoNotDisturb)
    _other -> decode.success(Offline)
  }
}

fn activity_decoder() -> decode.Decoder(Activity) {
  use kind <- decode.field("type", decode.int)
  use application_id <- decode.optional_field(
    "application_id",
    option.None,
    decode.optional(decode.string),
  )
  use name <- decode.field("name", decode.string)
  use details <- decode.optional_field(
    "details",
    option.None,
    decode.optional(decode.string),
  )
  use state <- decode.optional_field(
    "state",
    option.None,
    decode.optional(decode.string),
  )
  use artwork <- decode.optional_field("assets", option.None, artwork_decoder())
  use timing <- decode.optional_field("timestamps", Untimed, timing_decoder())
  decode.success(Activity(
    kind:,
    application_id:,
    name:,
    details:,
    state:,
    artwork:,
    timing:,
  ))
}

fn artwork_decoder() -> decode.Decoder(option.Option(String)) {
  use large_image <- decode.optional_field(
    "large_image",
    option.None,
    decode.optional(decode.string),
  )

  case large_image {
    option.None -> decode.success(option.None)
    option.Some(asset) -> decode.success(artwork_url(asset))
  }
}

fn artwork_url(asset: String) -> option.Option(String) {
  case asset {
    "mp:external/" <> proxied ->
      case string.split_once(proxied, "/") {
        Error(Nil) -> option.None
        Ok(#(_hash, remainder)) ->
          case string.split_once(remainder, "/") {
            Error(Nil) -> option.None
            Ok(#(scheme, url)) -> safe_url(scheme <> "://" <> url)
          }
      }
    _other -> option.None
  }
}

fn safe_url(url: String) -> option.Option(String) {
  let unsafe = ["\"", "'", "(", ")", "\\", " ", "\n", "\r", "\t"]

  case list.any(unsafe, string.contains(url, _)) {
    True -> option.None
    False -> option.Some(url)
  }
}

fn timing_decoder() -> decode.Decoder(Timing) {
  use start <- decode.optional_field(
    "start",
    option.None,
    decode.optional(decode.int),
  )
  use end <- decode.optional_field(
    "end",
    option.None,
    decode.optional(decode.int),
  )

  case start, end {
    option.Some(start_milliseconds), option.Some(end_milliseconds) ->
      decode.success(Timed(start_milliseconds:, end_milliseconds:))
    option.Some(_start), option.None -> decode.success(Untimed)
    option.None, option.Some(_end) -> decode.success(Untimed)
    option.None, option.None -> decode.success(Untimed)
  }
}

fn now_listening(activities: List(Activity)) -> Listening {
  let soundcloud_activity =
    list.find(activities, fn(activity) {
      activity.kind == listening_activity
      && activity.application_id == option.Some(soundcloud_application_id)
    })

  case soundcloud_activity {
    Error(Nil) -> Nothing
    Ok(Activity(details: option.None, ..)) -> Nothing
    Ok(Activity(
      details: option.Some(title),
      state:,
      name:,
      artwork:,
      timing:,
      ..,
    )) ->
      Track(
        title:,
        artist: option.unwrap(state, name),
        artwork:,
        timing:,
        playback: Playing,
      )
  }
}

// VIEW ------------------------------------------------------------------------

pub fn view(model: Model) -> element.Element(Message) {
  let children = case model.presence {
    Unknown -> [#("name", name_view([]))]

    Known(status:, listening: Nothing) -> [
      #("name", name_view([status_view(status)])),
    ]

    Known(
      status:,
      listening: Track(title:, artist:, artwork:, timing:, playback:),
    ) -> [
      #(
        "track",
        track_view(title, artist, artwork, timing, playback, model.clock),
      ),
      #("name", name_view([status_view(status)])),
    ]
  }

  keyed.div([attribute.class("presence")], children)
}

fn name_view(after_name: List(element.Element(a))) -> element.Element(a) {
  html.h1([attribute.class("presence-name")], [
    html.text(username),
    ..after_name
  ])
}

fn status_view(status: Status) -> element.Element(a) {
  case status {
    Offline -> element.none()
    Online | Idle | DoNotDisturb ->
      html.span(
        [
          attribute.class(
            "presence-status presence-status-" <> status_slug(status),
          ),
          attribute.attribute("role", "img"),
          attribute.attribute("aria-label", status_label(status)),
          attribute.title(status_label(status)),
        ],
        [],
      )
  }
}

fn status_slug(status: Status) -> String {
  case status {
    Online -> "online"
    Idle -> "idle"
    DoNotDisturb -> "dnd"
    Offline -> "offline"
  }
}

fn status_label(status: Status) -> String {
  case status {
    Online -> "Online on Discord"
    Idle -> "Idle on Discord"
    DoNotDisturb -> "Do not disturb on Discord"
    Offline -> "Offline on Discord"
  }
}

fn track_view(
  title: String,
  artist: String,
  artwork: option.Option(String),
  timing: Timing,
  playback: Playback,
  clock: Clock,
) -> element.Element(a) {
  let classes = case playback {
    Playing -> "presence-track"
    Ending -> "presence-track is-ending"
  }

  html.div([attribute.class(classes)], [
    artwork_view(artwork, title),
    html.div([attribute.class("presence-track-text")], [
      html.span([attribute.class("presence-track-title")], [html.text(title)]),
      html.div([attribute.class("presence-track-meta")], [
        html.span([attribute.class("presence-track-artist")], [
          html.text(artist),
        ]),
        position_view(timing, clock),
      ]),
    ]),
  ])
}

fn artwork_view(
  artwork: option.Option(String),
  title: String,
) -> element.Element(a) {
  case artwork {
    option.None -> element.none()
    option.Some(url) ->
      html.div(
        [
          attribute.class("presence-track-artwork"),
          attribute.attribute("role", "img"),
          attribute.attribute("aria-label", "Artwork for " <> title),
          attribute.style("background-image", "url(\"" <> url <> "\")"),
        ],
        [],
      )
  }
}

fn position_view(timing: Timing, clock: Clock) -> element.Element(a) {
  case timing, clock {
    Untimed, Paused -> element.none()
    Untimed, Ticking(..) -> element.none()
    Timed(..), Paused -> element.none()

    Timed(start_milliseconds:, end_milliseconds:), Ticking(now_milliseconds:) ->
      case int.compare(end_milliseconds, start_milliseconds) {
        order.Lt | order.Eq -> element.none()
        order.Gt -> {
          let duration = end_milliseconds - start_milliseconds
          let elapsed =
            int.clamp(
              now_milliseconds - start_milliseconds,
              min: 0,
              max: duration,
            )

          html.div([attribute.class("presence-track-position")], [
            html.progress(
              [
                attribute.class("presence-track-bar"),
                attribute.value(int.to_string(elapsed)),
                attribute.max(int.to_string(duration)),
              ],
              [],
            ),
            html.span([attribute.class("presence-track-time")], [
              html.text(
                position_text(elapsed) <> " / " <> position_text(duration),
              ),
            ]),
          ])
        }
      }
  }
}

fn position_text(milliseconds: Int) -> String {
  let seconds = milliseconds / 1000
  int.to_string(seconds / 60)
  <> ":"
  <> string.pad_start(int.to_string(seconds % 60), to: 2, with: "0")
}

// FFI -------------------------------------------------------------------------

@external(javascript, "./presence_ffi.mjs", "connect")
fn connect(
  url _url: String,
  on_open _on_open: fn(Socket) -> Nil,
  on_message _on_message: fn(String) -> Nil,
  on_close _on_close: fn() -> Nil,
) -> Nil {
  Nil
}

@external(javascript, "./presence_ffi.mjs", "send")
fn send(socket _socket: Socket, text _text: String) -> Nil {
  Nil
}

@external(javascript, "./presence_ffi.mjs", "heartbeat")
fn heartbeat(
  socket _socket: Socket,
  milliseconds _milliseconds: Int,
  payload _payload: String,
) -> Nil {
  Nil
}

@external(javascript, "./presence_ffi.mjs", "tick")
fn tick(milliseconds _milliseconds: Int, run _run: fn(Int) -> Nil) -> Nil {
  Nil
}
