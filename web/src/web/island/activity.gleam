//// GitHub contribution calendar from `/api/activity`.

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
import lustre/event
import rsvp
import web/browser
import web/date

pub const mount_id = "activity"

const endpoint = "/api/activity"

const weeks = 53

const levels = 4

const tooltip_id = "activity-day"

const navigation_keys = [
  "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Home", "End", "Escape",
]

pub fn main() -> Nil {
  let app = lustre.application(init:, update:, view:)

  let assert Ok(_started) = lustre.start(app, onto: "#" <> mount_id, with: Nil)

  Nil
}

pub type Model {
  Model(calendar: Calendar, selection: Selection)
}

pub type Calendar {
  Loading
  Loaded(start: calendar.Date, total: Int, counts: List(Int))
  Unavailable
}

pub type Selection {
  Hidden(index: Int)
  Selected(index: Int)
}

pub fn init(_flags: Nil) -> #(Model, effect.Effect(Message)) {
  #(Model(calendar: Loading, selection: Hidden(0)), load())
}

pub type Message {
  CalendarReceived(Result(Calendar, rsvp.Error(String)))
  DaySelected(index: Int)
  DayNavigated(index: Int, key: String)
  SelectionCleared
}

pub fn update(
  model: Model,
  message: Message,
) -> #(Model, effect.Effect(Message)) {
  case message {
    CalendarReceived(Ok(calendar)) -> #(
      Model(calendar:, selection: Hidden(0)),
      effect.none(),
    )
    CalendarReceived(Error(_error)) -> #(
      Model(calendar: Unavailable, selection: Hidden(0)),
      effect.none(),
    )
    DaySelected(index:) -> {
      let selection = selection_at(model.calendar, index)

      #(Model(..model, selection:), position_selection(selection))
    }
    SelectionCleared -> clear_selection(model)
    DayNavigated(index:, key:) ->
      case key {
        "ArrowUp" -> move_to(model, index - 1)
        "ArrowDown" -> move_to(model, index + 1)
        "ArrowLeft" -> move_to(model, index - date.days_in_week)
        "ArrowRight" -> move_to(model, index + date.days_in_week)
        "Home" -> move_to(model, 0)
        "End" -> move_to(model, weeks * date.days_in_week - 1)
        "Escape" -> clear_selection(model)
        _other -> #(model, effect.none())
      }
  }
}

fn selection_at(calendar: Calendar, index: Int) -> Selection {
  case calendar {
    Loading | Unavailable | Loaded(counts: [], ..) -> Hidden(0)
    Loaded(counts:, ..) ->
      Selected(int.clamp(
        index,
        min: 0,
        max: int.min(list.length(counts), weeks * date.days_in_week) - 1,
      ))
  }
}

fn move_to(model: Model, index: Int) -> #(Model, effect.Effect(Message)) {
  let selection = selection_at(model.calendar, index)
  let focus = case selection {
    Hidden(..) -> effect.none()
    Selected(index:) -> {
      use _dispatch <- effect.from
      browser.focus(day_id(index))
    }
  }

  #(
    Model(..model, selection:),
    effect.batch([focus, position_selection(selection)]),
  )
}

fn clear_selection(model: Model) -> #(Model, effect.Effect(Message)) {
  #(Model(..model, selection: Hidden(model.selection.index)), effect.none())
}

fn position_selection(selection: Selection) -> effect.Effect(Message) {
  case selection {
    Hidden(..) -> effect.none()
    Selected(..) -> {
      use _dispatch, _root <- effect.before_paint
      position_tooltip(tooltip_id)
    }
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

fn level(count: Int, busiest: Int) -> Int {
  case count, busiest {
    0, _busiest -> 0
    _count, 0 -> 0
    count, busiest ->
      int.min(levels, { count * levels + busiest - 1 } / busiest)
  }
}

fn slots(counts: List(Int)) -> List(Int) {
  let total = weeks * date.days_in_week
  let reported = list.length(counts)

  case int.compare(reported, total) {
    order.Lt -> list.append(counts, list.repeat(0, total - reported))
    order.Eq -> counts
    order.Gt -> list.take(counts, total)
  }
}

pub fn view(model: Model) -> element.Element(Message) {
  html.div([attribute.class("activity")], [
    element.memo(
      [element.ref(model.calendar), element.ref(model.selection.index)],
      fn() { grid(model.calendar, model.selection.index) },
    ),
    tooltip(model),
    legend(),
  ])
}

fn grid(calendar: Calendar, selected: Int) -> element.Element(Message) {
  let #(counts, start) = case calendar {
    Loading | Unavailable -> #([], Error(Nil))
    Loaded(counts:, start:, ..) -> #(counts, Ok(start))
  }

  let reported = list.length(counts)
  let cells = slots(counts)
  let busiest = list.fold(cells, 0, int.max)

  html.div(
    [
      attribute.class(case calendar {
        Loading -> "activity-grid is-loading"
        Loaded(..) -> "activity-grid is-loaded"
        Unavailable -> "activity-grid"
      }),
      attribute.attribute("role", "group"),
      attribute.attribute(
        "aria-label",
        label(calendar) <> ". Use arrow keys to explore days.",
      ),
      event.on_mouse_leave(SelectionCleared),
    ],
    list.index_map(cells, fn(count, index) {
      let selected = selected == index

      element.memo([element.ref(calendar), element.ref(selected)], fn() {
        let day = case start, index < reported {
          Ok(start), True -> Ok(date.day_at(start, index))
          Ok(_start), False | Error(Nil), _reported -> Error(Nil)
        }

        cell(count, busiest, day, wave(calendar, index), index, selected)
      })
    }),
  )
}

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
  wave: List(attribute.Attribute(Message)),
  index: Int,
  selected: Bool,
) -> element.Element(Message) {
  let attributes = [level_class(level(count, busiest)), ..wave]

  case day {
    Error(Nil) ->
      html.div([attribute.attribute("aria-hidden", "true"), ..attributes], [])
    Ok(day) ->
      html.button(
        [
          attribute.type_("button"),
          attribute.id(day_id(index)),
          attribute.attribute("aria-label", describe(count, day)),
          attribute.attribute("aria-describedby", tooltip_id),
          attribute.attribute("tabindex", case selected {
            True -> "0"
            False -> "-1"
          }),
          event.on_mouse_enter(DaySelected(index:)),
          event.on_mouse_leave(SelectionCleared),
          event.on_focus(DaySelected(index:)),
          event.on_blur(SelectionCleared),
          event.on_click(DaySelected(index:)),
          navigation(index),
          ..attributes
        ],
        [],
      )
  }
}

fn day_id(index: Int) -> String {
  mount_id <> "-day-" <> int.to_string(index)
}

fn navigation(index: Int) -> attribute.Attribute(Message) {
  event.advanced("keydown", {
    use key <- decode.field("key", decode.string)

    decode.success(event.handler(
      DayNavigated(index:, key:),
      prevent_default: list.contains(navigation_keys, key),
      stop_propagation: False,
    ))
  })
}

fn tooltip(model: Model) -> element.Element(Message) {
  let index = model.selection.index
  let text = case model.calendar {
    Loaded(start:, counts:, ..) ->
      case list.first(list.drop(counts, index)) {
        Ok(count) -> describe(count, date.day_at(start, index))
        Error(Nil) -> ""
      }
    Loading | Unavailable -> ""
  }

  html.div(
    [
      attribute.id(tooltip_id),
      attribute.class(case model.selection {
        Hidden(..) -> "activity-tooltip"
        Selected(..) -> "activity-tooltip is-shown"
      }),
      attribute.attribute("data-anchor", day_id(index)),
      attribute.attribute("role", "tooltip"),
      attribute.attribute("aria-live", "polite"),
    ],
    [html.span([attribute.class("activity-tooltip-text")], [html.text(text)])],
  )
}

@external(javascript, "./activity_ffi.mjs", "position_tooltip")
fn position_tooltip(_id: String) -> Nil {
  Nil
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

  html.div(
    [
      attribute.class("activity-legend"),
      attribute.attribute("aria-hidden", "true"),
    ],
    [legend_text("less"), ..list.append(swatches, [legend_text("more")])],
  )
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
