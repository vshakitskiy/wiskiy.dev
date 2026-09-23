//// The GitHub contribution grid filled in from `/api/activity`.
////
//// It shows a loading wave until the counts arrive then fades each day in.

import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/order
import gleam/time/calendar
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import rsvp
import web/date

pub const mount_id = "activity"

const endpoint = "/api/activity"

const weeks = 53

/// The busiest level; days with no contributions are level 0.
const levels = 4

pub fn main() -> Nil {
  let app = lustre.application(init:, update:, view:)
  let assert Ok(_started) = lustre.start(app, onto: "#" <> mount_id, with: Nil)
  Nil
}

// MODEL -----------------------------------------------------------------------

pub type Model {
  Model(calendar: Calendar)
}

pub type Calendar {
  Loading
  Loaded(start: calendar.Date, total: Int, counts: List(Int))
  Unavailable
}

pub fn init(_flags: Nil) -> #(Model, effect.Effect(Message)) {
  #(Model(calendar: Loading), load())
}

// UPDATE ----------------------------------------------------------------------

pub type Message {
  CalendarReceived(Result(Calendar, rsvp.Error(String)))
}

pub fn update(
  _model: Model,
  message: Message,
) -> #(Model, effect.Effect(Message)) {
  case message {
    CalendarReceived(Ok(calendar)) -> #(Model(calendar:), effect.none())
    CalendarReceived(Error(_error)) -> #(
      Model(calendar: Unavailable),
      effect.none(),
    )
  }
}

fn load() -> effect.Effect(Message) {
  rsvp.get(endpoint, rsvp.expect_json(calendar_decoder(), CalendarReceived))
}

fn calendar_decoder() -> decode.Decoder(Calendar) {
  use start <- decode.field("start", date_decoder())
  use total <- decode.field("total", decode.int)
  use counts <- decode.field("counts", decode.list(decode.int))
  decode.success(Loaded(start:, total:, counts:))
}

fn date_decoder() -> decode.Decoder(calendar.Date) {
  use text <- decode.then(decode.string)
  case date.parse(text) {
    Ok(date) -> decode.success(date)
    Error(Nil) ->
      decode.failure(calendar.Date(1970, calendar.January, 1), "Date")
  }
}

// GRID ------------------------------------------------------------------------

/// Scales a day's count to a level from 0 to `levels`, relative to the
/// busiest day. Any contribution at all shows as at least level 1.
fn level(count: Int, busiest: Int) -> Int {
  case count, busiest {
    0, _busiest -> 0
    _count, 0 -> 0
    count, busiest ->
      int.min(levels, { count * levels + busiest - 1 } / busiest)
  }
}

/// Pads or trims the counts to exactly fill the grid.
fn slots(counts: List(Int)) -> List(Int) {
  let total = weeks * date.days_in_week
  let reported = list.length(counts)

  case int.compare(reported, total) {
    order.Lt -> list.append(counts, list.repeat(0, total - reported))
    order.Eq -> counts
    order.Gt -> list.take(counts, total)
  }
}

// VIEW ------------------------------------------------------------------------

pub fn view(model: Model) -> element.Element(Message) {
  let #(counts, start) = case model.calendar {
    Loading | Unavailable -> #([], Error(Nil))
    Loaded(counts:, start:, ..) -> #(counts, Ok(start))
  }

  let reported = list.length(counts)
  let cells = slots(counts)
  let busiest = list.fold(cells, 0, int.max)

  html.div([attribute.class("activity")], [
    html.div(
      [
        attribute.class(case model.calendar {
          Loading -> "activity-grid is-loading"
          Loaded(..) -> "activity-grid is-loaded"
          Unavailable -> "activity-grid"
        }),
        attribute.attribute("role", "img"),
        attribute.attribute("aria-label", label(model.calendar)),
      ],
      list.index_map(cells, fn(count, index) {
        let day = case start, index < reported {
          Ok(start), True -> Ok(date.day_at(start, index))
          Ok(_start), False | Error(Nil), _reported -> Error(Nil)
        }

        cell(count, busiest, day, wave(model.calendar, index))
      }),
    ),
    legend(),
  ])
}

/// Delays each cell's animation by its diagonal so it sweeps across the grid.
fn wave(calendar: Calendar, index: Int) -> List(attribute.Attribute(a)) {
  case calendar {
    Loading | Loaded(..) -> {
      let column = index / date.days_in_week
      let row = index % date.days_in_week
      [attribute.style("--wave", int.to_string(column + row))]
    }
    Unavailable -> []
  }
}

fn cell(
  count: Int,
  busiest: Int,
  day: Result(calendar.Date, Nil),
  wave: List(attribute.Attribute(a)),
) -> element.Element(a) {
  let described = case day {
    Error(Nil) -> []
    Ok(day) -> [attribute.attribute("data-day", describe(count, day))]
  }

  html.div(
    [level_class(level(count, busiest)), ..list.append(described, wave)],
    [],
  )
}

fn level_class(level: Int) -> attribute.Attribute(a) {
  attribute.class("activity-cell activity-level-" <> int.to_string(level))
}

fn describe(count: Int, day: calendar.Date) -> String {
  let when =
    date.weekday(day)
    <> ", "
    <> int.to_string(day.day)
    <> " "
    <> calendar.month_to_string(day.month)

  case count {
    0 -> "No contributions on " <> when
    1 -> "1 contribution on " <> when
    _many -> int.to_string(count) <> " contributions on " <> when
  }
}

fn legend() -> element.Element(a) {
  let swatches =
    int.range(from: levels, to: -1, with: [], run: fn(swatches, level) {
      [html.div([level_class(level)], []), ..swatches]
    })

  html.div([attribute.class("activity-legend")], [
    legend_text("less"),
    ..list.append(swatches, [legend_text("more")])
  ])
}

fn legend_text(text: String) -> element.Element(a) {
  html.span([attribute.class("activity-legend-text")], [html.text(text)])
}

fn label(calendar: Calendar) -> String {
  case calendar {
    Loading -> "GitHub contributions, loading"
    Unavailable -> "GitHub contributions, unavailable"
    Loaded(total:, ..) ->
      int.to_string(total) <> " contributions in the last year"
  }
}
