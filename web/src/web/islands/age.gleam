//// My age with the counting animation.

import gleam/float
import gleam/int
import gleam/list
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import lustre
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed
import web/browser

pub const mount_id = "age"

const birthday = calendar.Date(2006, calendar.August, 8)

/// The Gregorian average.
const seconds_per_year = 31_556_952.0

const decimals = 8

const tick_interval_milliseconds = 80

fn outgoing(digit: Int) -> Int {
  { digit + 9 } % 10
}

pub fn main() -> Nil {
  let app = lustre.application(init:, update:, view:)
  let assert Ok(_started) = lustre.start(app, onto: "#" <> mount_id, with: Nil)
  Nil
}

// MODEL -----------------------------------------------------------------------

pub type Model {
  Model(now: Timestamp, phase: Phase)
}

pub type Phase {
  FirstPaint
  Counting
}

pub fn init(_flags: Nil) -> #(Model, Effect(Message)) {
  #(Model(now: timestamp.system_time(), phase: FirstPaint), tick())
}

// UPDATE ----------------------------------------------------------------------

pub type Message {
  Ticked
}

pub fn update(_model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    Ticked -> #(Model(now: timestamp.system_time(), phase: Counting), tick())
  }
}

fn tick() -> Effect(Message) {
  use dispatch <- effect.from
  use <- browser.after(milliseconds: tick_interval_milliseconds)
  dispatch(Ticked)
}

// AGE -------------------------------------------------------------------------

pub fn years(now: Timestamp) -> Float {
  let born =
    timestamp.from_calendar(
      birthday,
      calendar.TimeOfDay(0, 0, 0, 0),
      calendar.utc_offset,
    )

  { timestamp.to_unix_seconds(now) -. timestamp.to_unix_seconds(born) }
  /. seconds_per_year
}

pub fn whole(now: Timestamp) -> String {
  years(now) |> float.truncate |> int.to_string
}

pub fn fraction(now: Timestamp) -> String {
  let years = years(now)
  let fraction = years -. int.to_float(float.truncate(years))
  let scale = power(10, decimals)

  let digits = int.min(float.round(fraction *. int.to_float(scale)), scale - 1)

  "."
  <> int.to_string(digits)
  |> string.pad_start(to: decimals, with: "0")
}

fn power(base: Int, exponent: Int) -> Int {
  case exponent {
    0 -> 1
    _more -> base * power(base, exponent - 1)
  }
}

// VIEW ------------------------------------------------------------------------

pub fn view(model: Model) -> Element(Message) {
  html.span(
    [
      attr.class("age"),
      attr.attribute("role", "img"),
      attr.attribute("aria-label", reading(model.now) <> " years old"),
    ],
    reading(model.now)
      |> string.to_graphemes
      |> list.map(character(_, model.phase)),
  )
}

pub fn reading(now: Timestamp) -> String {
  whole(now) <> fraction(now)
}

fn character(character: String, phase: Phase) -> Element(Message) {
  case int.parse(character) {
    Error(Nil) -> html.span([attr.class("age-point")], [html.text(character)])
    Ok(digit) -> reel(digit, phase)
  }
}

fn reel(digit: Int, phase: Phase) -> Element(Message) {
  let arriving_from = case phase {
    FirstPaint -> digit
    Counting -> outgoing(digit)
  }

  keyed.element("span", [attr.class("digit")], [
    #(
      int.to_string(digit),
      html.span([attr.class("digit-strip")], [cell(digit), cell(arriving_from)]),
    ),
  ])
}

fn cell(digit: Int) -> Element(Message) {
  html.span([attr.class("digit-cell")], [html.text(int.to_string(digit))])
}
