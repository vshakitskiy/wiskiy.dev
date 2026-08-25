//// GitHub contribution grid filled in from the api.

import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/order
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp
import lustre
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import rsvp

pub const mount_id = "activity"

const endpoint = "/api/activity"

const weeks = 53

const days_in_week = 7

const levels = 4

pub fn main() -> Nil {
  let app = lustre.application(init:, update:, view:)
  let assert Ok(_) = lustre.start(app, onto: "#" <> mount_id, with: Nil)
  Nil
}

// MODEL -----------------------------------------------------------------------

pub type Model {
  Model(calendar: Calendar)
}

pub type Calendar {
  Loading
  Loaded(start: String, total: Int, counts: List(Int))
  Unavailable
}

pub fn init(_flags: Nil) -> #(Model, Effect(Message)) {
  #(Model(calendar: Loading), load())
}

// UPDATE ----------------------------------------------------------------------

pub type Message {
  CalendarReceived(Result(Calendar, rsvp.Error(String)))
}

pub fn update(_model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    CalendarReceived(Ok(calendar)) -> #(Model(calendar:), effect.none())
    CalendarReceived(Error(_error)) -> #(
      Model(calendar: Unavailable),
      effect.none(),
    )
  }
}

fn load() -> Effect(Message) {
  rsvp.get(endpoint, rsvp.expect_json(calendar_decoder(), CalendarReceived))
}

pub fn calendar_decoder() -> decode.Decoder(Calendar) {
  use start <- decode.field("start", decode.string)
  use total <- decode.field("total", decode.int)
  use counts <- decode.field("counts", decode.list(decode.int))
  decode.success(Loaded(start:, total:, counts:))
}

// LEVELS ----------------------------------------------------------------------

pub fn level(count: Int, busiest: Int) -> Int {
  case count, busiest {
    0, _busiest -> 0
    _count, 0 -> 0
    count, busiest ->
      int.min(levels, { count * levels + busiest - 1 } / busiest)
  }
}

pub fn slots(counts: List(Int)) -> List(Int) {
  let total = weeks * days_in_week
  let reported = list.length(counts)

  case int.compare(reported, total) {
    order.Lt -> list.append(counts, list.repeat(0, total - reported))
    order.Eq -> counts
    order.Gt -> list.take(counts, total)
  }
}

// VIEW ------------------------------------------------------------------------

pub fn view(model: Model) -> Element(Message) {
  let #(counts, start) = case model.calendar {
    Loading | Unavailable -> #([], Error(Nil))
    Loaded(counts:, start:, ..) -> #(counts, parse_date(start))
  }

  let reported = list.length(counts)
  let cells = slots(counts)
  let busiest = list.fold(cells, 0, int.max)

  html.div([attr.class("activity")], [
    html.div(
      [
        attr.class("activity-grid"),
        attr.attribute("role", "img"),
        attr.attribute("aria-label", label(model.calendar)),
      ],
      list.index_map(cells, fn(count, index) {
        cell(count, busiest, case index < reported {
          False -> Error(Nil)
          True -> result.map(start, day_at(_, index))
        })
      }),
    ),
    legend(),
  ])
}

fn cell(
  count: Int,
  busiest: Int,
  date: Result(calendar.Date, Nil),
) -> Element(a) {
  let described = case date {
    Error(Nil) -> []
    Ok(date) -> [attr.attribute("data-day", describe(count, date))]
  }

  html.div(
    [
      attr.class(
        "activity-cell activity-level-" <> int.to_string(level(count, busiest)),
      ),
      ..described
    ],
    [],
  )
}

fn describe(count: Int, date: calendar.Date) -> String {
  let when =
    weekday(date)
    <> ", "
    <> int.to_string(date.day)
    <> " "
    <> calendar.month_to_string(date.month)

  case count {
    0 -> "No contributions on " <> when
    1 -> "1 contribution on " <> when
    _many -> int.to_string(count) <> " contributions on " <> when
  }
}

fn legend() -> Element(a) {
  html.div([attr.class("activity-legend")], [
    html.span([attr.class("activity-legend-text")], [html.text("less")]),
    ..list.append(
      list.map([0, 1, 2, 3, 4], fn(each) {
        html.div(
          [attr.class("activity-cell activity-level-" <> int.to_string(each))],
          [],
        )
      }),
      [html.span([attr.class("activity-legend-text")], [html.text("more")])],
    )
  ])
}

fn label(calendar: Calendar) -> String {
  case calendar {
    Loading -> "GitHub contributions, loading"
    Unavailable -> "GitHub contributions, unavailable"
    Loaded(total:, ..) ->
      int.to_string(total) <> " contributions in the last year"
  }
}

// DATES -----------------------------------------------------------------------

pub fn weekday(date: calendar.Date) -> String {
  case weekday_index(date) {
    0 -> "Sunday"
    1 -> "Monday"
    2 -> "Tuesday"
    3 -> "Wednesday"
    4 -> "Thursday"
    5 -> "Friday"
    _saturday -> "Saturday"
  }
}

fn weekday_index(date: calendar.Date) -> Int {
  let seconds =
    timestamp.from_calendar(
      date,
      calendar.TimeOfDay(12, 0, 0, 0),
      calendar.utc_offset,
    )
    |> timestamp.to_unix_seconds
    |> float.round

  let days = int.floor_divide(seconds, 86_400) |> result.unwrap(0)
  int.modulo(days + 4, days_in_week) |> result.unwrap(0)
}

pub fn day_at(start: calendar.Date, offset: Int) -> calendar.Date {
  let #(date, _time) =
    timestamp.from_calendar(
      start,
      calendar.TimeOfDay(12, 0, 0, 0),
      calendar.utc_offset,
    )
    |> timestamp.add(duration.hours(24 * offset))
    |> timestamp.to_calendar(calendar.utc_offset)

  date
}

fn parse_date(text: String) -> Result(calendar.Date, Nil) {
  case string.split(text, "-") {
    [year, month, day] -> {
      use year <- result.try(int.parse(year))
      use month <- result.try(int.parse(month))
      use day <- result.try(int.parse(day))
      use month <- result.try(calendar.month_from_int(month))
      Ok(calendar.Date(year:, month:, day:))
    }
    _malformed -> Error(Nil)
  }
}
