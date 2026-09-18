//// The searchable index of the articles.

import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/string
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event

pub const mount_id = "archive"

pub const index_id = "archive-index"

pub type Entry {
  Entry(
    path: String,
    title: String,
    date: String,
    description: String,
    tags: List(String),
  )
}

// MODEL -----------------------------------------------------------------------

pub type Model {
  Model(entries: List(Entry), query: String, filter: Filter)
}

pub type Filter {
  Everything
  Tagged(tag: String)
}

pub fn from_entries(entries: List(Entry)) -> Model {
  Model(entries:, query: "", filter: Everything)
}

pub fn main() -> Nil {
  let app = lustre.application(init:, update:, view:)
  let assert Ok(_started) = lustre.start(app, onto: "#" <> mount_id, with: Nil)
  Nil
}

pub fn init(_flags: Nil) -> #(Model, effect.Effect(Message)) {
  let entries = case json.parse(embedded(index_id), entries_decoder()) {
    Ok(entries) -> entries
    Error(_unreadable) -> []
  }

  #(from_entries(entries), effect.none())
}

// UPDATE ----------------------------------------------------------------------

pub type Message {
  QueryChanged(query: String)
  TagChosen(tag: String)
  FilterCleared
}

pub fn update(
  model: Model,
  message: Message,
) -> #(Model, effect.Effect(Message)) {
  let model = case message {
    QueryChanged(query:) -> Model(..model, query:)
    FilterCleared -> Model(..model, filter: Everything)
    TagChosen(tag:) ->
      case model.filter {
        Tagged(current) if current == tag -> Model(..model, filter: Everything)
        Everything | Tagged(_other) -> Model(..model, filter: Tagged(tag))
      }
  }

  #(model, effect.none())
}

// SEARCH ----------------------------------------------------------------------

pub fn matching(model: Model) -> List(Entry) {
  use entry <- list.filter(model.entries)
  matches_query(entry, model.query) && matches_filter(entry, model.filter)
}

fn matches_query(entry: Entry, query: String) -> Bool {
  case string.trim(query) {
    "" -> True
    query -> {
      let query = string.lowercase(query)
      let haystack =
        string.lowercase(
          entry.title
          <> " "
          <> entry.description
          <> " "
          <> string.join(entry.tags, " "),
        )

      string.contains(haystack, query)
    }
  }
}

fn matches_filter(entry: Entry, filter: Filter) -> Bool {
  case filter {
    Everything -> True
    Tagged(tag:) -> list.contains(entry.tags, tag)
  }
}

pub fn tags(entries: List(Entry)) -> List(String) {
  use seen, entry <- list.fold(entries, [])
  use seen, tag <- list.fold(entry.tags, seen)

  case list.contains(seen, tag) {
    True -> seen
    False -> list.append(seen, [tag])
  }
}

// JSON ------------------------------------------------------------------------

pub fn to_json(entries: List(Entry)) -> String {
  json.array(entries, fn(entry) {
    json.object([
      #("path", json.string(entry.path)),
      #("title", json.string(entry.title)),
      #("date", json.string(entry.date)),
      #("description", json.string(entry.description)),
      #("tags", json.array(entry.tags, json.string)),
    ])
  })
  |> json.to_string
  |> string.replace("<", "\\u003C")
}

pub fn entries_decoder() -> decode.Decoder(List(Entry)) {
  decode.list({
    use path <- decode.field("path", decode.string)
    use title <- decode.field("title", decode.string)
    use date <- decode.field("date", decode.string)
    use description <- decode.field("description", decode.string)
    use tags <- decode.field("tags", decode.list(decode.string))
    decode.success(Entry(path:, title:, date:, description:, tags:))
  })
}

// VIEW ------------------------------------------------------------------------

pub fn view(model: Model) -> element.Element(Message) {
  let found = matching(model)

  html.div([attribute.class("archive")], [
    html.div([attribute.class("archive-controls")], [
      html.input([
        attribute.class("archive-search"),
        attribute.type_("search"),
        attribute.value(model.query),
        attribute.placeholder("search writing"),
        attribute.attribute("aria-label", "Search writing"),
        event.on_input(QueryChanged),
      ]),
      tag_row(model),
    ]),
    case found {
      [] ->
        html.p([attribute.class("archive-empty")], [
          html.text("Nothing matches."),
        ])
      found ->
        html.ul([attribute.class("entries")], list.map(found, entry_view))
    },
  ])
}

fn tag_row(model: Model) -> element.Element(Message) {
  let all = tags(model.entries)

  case all {
    [] -> element.none()
    all ->
      html.div([attribute.class("archive-tags")], [
        html.button(
          [
            attribute.class(case model.filter {
              Everything -> "tag is-active"
              Tagged(_tag) -> "tag"
            }),
            event.on_click(FilterCleared),
          ],
          [html.text("all")],
        ),
        ..list.map(all, fn(tag) {
          html.button(
            [
              attribute.class(case model.filter {
                Tagged(current) if current == tag -> "tag is-active"
                Everything | Tagged(_other) -> "tag"
              }),
              event.on_click(TagChosen(tag:)),
            ],
            [html.text(tag)],
          )
        })
      ])
  }
}

fn entry_view(entry: Entry) -> element.Element(Message) {
  html.li([], [
    html.a([attribute.class("entry"), attribute.href(entry.path)], [
      html.span([attribute.class("entry-head")], [
        html.span([attribute.class("entry-title")], [html.text(entry.title)]),
        html.span([attribute.class("entry-date")], [html.text(entry.date)]),
      ]),
      html.span([attribute.class("entry-description")], [
        html.text(entry.description),
      ]),
    ]),
  ])
}

// FFI -------------------------------------------------------------------------

@external(javascript, "./archive_ffi.mjs", "embedded")
fn embedded(_id: String) -> String {
  ""
}
