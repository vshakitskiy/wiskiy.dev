//// My age in years counting up live with rolling digits.

import gleam/float
import gleam/int
import gleam/list
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/element/keyed
import web/browser

pub const mount_id = "age"

const birthday = calendar.Date(year: 2006, month: calendar.August, day: 8)

const midnight = calendar.TimeOfDay(
  hours: 0,
  minutes: 0,
  seconds: 0,
  nanoseconds: 0,
)

/// The average Gregorian year.
const seconds_per_year = 31_556_952.0

const decimals = 8

const tick_interval_milliseconds = 80

pub fn main() -> Nil {
  let app = lustre.application(init:, update:, view:)
  let assert Ok(_started) = lustre.start(app, onto: "#" <> mount_id, with: Nil)
  Nil
}

// MODEL -----------------------------------------------------------------------

pub type Model {
  Model(now: timestamp.Timestamp, phase: Phase)
}

/// Digits only roll once counting starts.
pub type Phase {
  FirstPaint
  Counting
}

pub fn init(_flags: Nil) -> #(Model, effect.Effect(Message)) {
  #(Model(now: timestamp.system_time(), phase: FirstPaint), tick())
}

// UPDATE ----------------------------------------------------------------------

pub type Message {
  Ticked
}

pub fn update(
  _model: Model,
  message: Message,
) -> #(Model, effect.Effect(Message)) {
  case message {
    Ticked -> #(Model(now: timestamp.system_time(), phase: Counting), tick())
  }
}

fn tick() -> effect.Effect(Message) {
  use dispatch <- effect.from
  use <- browser.after(milliseconds: tick_interval_milliseconds)
  dispatch(Ticked)
}

// AGE -------------------------------------------------------------------------

/// The age as text, like `19.12345678`.
fn reading(now: timestamp.Timestamp) -> String {
  let born = timestamp.from_calendar(birthday, midnight, calendar.utc_offset)
  let years =
    { timestamp.to_unix_seconds(now) -. timestamp.to_unix_seconds(born) }
    /. seconds_per_year

  let whole = float.truncate(years)
  let scale = power(10, decimals)

  let fraction =
    int.min(
      float.round({ years -. int.to_float(whole) } *. int.to_float(scale)),
      scale - 1,
    )

  int.to_string(whole)
  <> "."
  <> string.pad_start(int.to_string(fraction), to: decimals, with: "0")
}

fn power(base: Int, exponent: Int) -> Int {
  case exponent {
    0 -> 1
    _positive -> base * power(base, exponent - 1)
  }
}

// VIEW ------------------------------------------------------------------------

pub fn view(model: Model) -> element.Element(Message) {
  let reading = reading(model.now)

  html.span(
    [
      attribute.class("age"),
      attribute.attribute("role", "img"),
      attribute.attribute("aria-label", reading <> " years old"),
    ],
    reading
      |> string.to_graphemes
      |> list.map(character(_, model.phase)),
  )
}

fn character(grapheme: String, phase: Phase) -> element.Element(Message) {
  case int.parse(grapheme) {
    Ok(digit) -> reel(digit, phase)
    Error(Nil) ->
      html.span([attribute.class("age-point")], [html.text(grapheme)])
  }
}

/// A digit stacked on the one it replaced. Keying it by digit makes a change
/// mount a fresh strip, which replays the roll animation.
fn reel(digit: Int, phase: Phase) -> element.Element(Message) {
  let previous = case phase {
    FirstPaint -> digit
    Counting -> { digit + 9 } % 10
  }

  keyed.element("span", [attribute.class("digit")], [
    #(
      int.to_string(digit),
      html.span([attribute.class("digit-strip")], [cell(digit), cell(previous)]),
    ),
  ])
}

fn cell(digit: Int) -> element.Element(Message) {
  html.span([attribute.class("digit-cell")], [html.text(int.to_string(digit))])
}
