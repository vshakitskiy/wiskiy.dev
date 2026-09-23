//// The searchable list of articles on the writing page.
////
//// The page is prerendered with every article and the entries are also 
//// embedded as JSON so the island can filter them without a request.

import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event

pub const mount_id = "archive"

/// Id of the `<script>` tag that holds the entries as JSON.
pub const index_id = "archive-index"

pub fn main() -> Nil {
  let app = lustre.application(init:, update:, view:)
  let assert Ok(_started) = lustre.start(app, onto: "#" <> mount_id, with: Nil)
  Nil
}

// MODEL -----------------------------------------------------------------------

pub type Model {
  Model(entries: List(Entry), query: String, filter: Filter)
}

pub type Entry {
  Entry(
    path: String,
    title: String,
    date: String,
    description: String,
    tags: List(String),
  )
}

pub type Filter {
  Everything
  Tagged(tag: String)
}

pub fn from_entries(entries: List(Entry)) -> Model {
  Model(entries:, query: "", filter: Everything)
}

pub fn init(_flags: Nil) -> #(Model, effect.Effect(Message)) {
  let entries =
    json.parse(embedded(index_id), entries_decoder())
    |> result.unwrap([])

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
      case model.filter == Tagged(tag) {
        True -> Model(..model, filter: Everything)
        False -> Model(..model, filter: Tagged(tag))
      }
  }

  #(model, effect.none())
}

// SEARCH ----------------------------------------------------------------------

fn matching(model: Model) -> List(Entry) {
  use entry <- list.filter(model.entries)
  matches_query(entry, model.query) && matches_filter(entry, model.filter)
}

fn matches_query(entry: Entry, query: String) -> Bool {
  case string.trim(query) {
    "" -> True
    query -> {
      let haystack =
        string.lowercase(
          entry.title
          <> " "
          <> entry.description
          <> " "
          <> string.join(entry.tags, " "),
        )

      string.contains(haystack, string.lowercase(query))
    }
  }
}

fn matches_filter(entry: Entry, filter: Filter) -> Bool {
  case filter {
    Everything -> True
    Tagged(tag:) -> list.contains(entry.tags, tag)
  }
}

/// Every tag in use in order of first appearance.
fn tags(entries: List(Entry)) -> List(String) {
  list.flat_map(entries, fn(entry) { entry.tags })
  |> list.unique
}

// JSON ------------------------------------------------------------------------

/// Encodes the entries for embedding in a `<script>` tag.
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

fn entries_decoder() -> decode.Decoder(List(Entry)) {
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
    case matching(model) {
      [] ->
        html.p([attribute.class("archive-empty")], [
          html.text("Nothing matches."),
        ])
      found -> entry_list(found)
    },
  ])
}

/// The list of article links, also used for recent writing on the home page.
pub fn entry_list(entries: List(Entry)) -> element.Element(a) {
  html.ul([attribute.class("entries")], list.map(entries, entry_view))
}

fn tag_row(model: Model) -> element.Element(Message) {
  case tags(model.entries) {
    [] -> element.none()
    tags ->
      html.div([attribute.class("archive-tags")], [
        tag_button("all", model.filter == Everything, FilterCleared),
        ..list.map(tags, fn(tag) {
          tag_button(tag, model.filter == Tagged(tag), TagChosen(tag:))
        })
      ])
  }
}

fn tag_button(
  label: String,
  active: Bool,
  message: Message,
) -> element.Element(Message) {
  html.button(
    [
      attribute.class(case active {
        True -> "tag is-active"
        False -> "tag"
      }),
      event.on_click(message),
    ],
    [html.text(label)],
  )
}

fn entry_view(entry: Entry) -> element.Element(a) {
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

/// Text content of the element with the given id or `""` if there is none.
@external(javascript, "./archive_ffi.mjs", "embedded")
fn embedded(_id: String) -> String {
  ""
}
