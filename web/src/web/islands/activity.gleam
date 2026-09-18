//// GitHub contribution grid filled in from the api.

import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/order
import gleam/result
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

pub fn view(model: Model) -> element.Element(Message) {
  let #(counts, start) = case model.calendar {
    Loading | Unavailable -> #([], Error(Nil))
    Loaded(counts:, start:, ..) -> #(counts, date.parse(start))
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
        let day = case index < reported {
          False -> Error(Nil)
          True -> result.map(start, date.day_at(_, index))
        }

        cell(count, busiest, day, wave(model.calendar, index))
      }),
    ),
    legend(),
  ])
}

fn wave(calendar: Calendar, index: Int) -> List(attribute.Attribute(a)) {
  case calendar {
    Loading | Loaded(..) -> {
      let column = index / days_in_week
      let row = index % days_in_week
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
    [
      attribute.class(
        "activity-cell activity-level-" <> int.to_string(level(count, busiest)),
      ),
      ..list.append(described, wave)
    ],
    [],
  )
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
  html.div([attribute.class("activity-legend")], [
    html.span([attribute.class("activity-legend-text")], [html.text("less")]),
    ..list.append(
      list.map([0, 1, 2, 3, 4], fn(each) {
        html.div(
          [
            attribute.class(
              "activity-cell activity-level-" <> int.to_string(each),
            ),
          ],
          [],
        )
      }),
      [
        html.span([attribute.class("activity-legend-text")], [html.text("more")]),
      ],
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
