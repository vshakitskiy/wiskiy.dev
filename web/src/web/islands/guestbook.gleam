//// A guestbook..?

import gleam/int
import gleam/list
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event

pub const mount_id = "guestbook"

pub fn main() -> Nil {
  let app = lustre.application(init:, update:, view:)
  let assert Ok(_started) = lustre.start(app, onto: "#" <> mount_id, with: Nil)
  Nil
}

// MODEL -----------------------------------------------------------------------

pub type Model {
  Model(draft: String, entries: List(String))
}

pub fn init(_flags: Nil) -> #(Model, effect.Effect(Message)) {
  // TODO: fetch existing entries from the api with rsvp
  #(Model(draft: "", entries: []), effect.none())
}

// UPDATE ----------------------------------------------------------------------

pub type Message {
  DraftChanged(draft: String)
  DraftSubmitted
}

pub fn update(
  model: Model,
  message: Message,
) -> #(Model, effect.Effect(Message)) {
  case message {
    DraftChanged(draft:) -> #(Model(..model, draft:), effect.none())

    // TODO: POST to the api instead of keeping this client side
    DraftSubmitted ->
      case model.draft {
        "" -> #(model, effect.none())
        draft -> #(
          Model(draft: "", entries: [draft, ..model.entries]),
          effect.none(),
        )
      }
  }
}

// VIEW ------------------------------------------------------------------------

pub fn view(model: Model) -> element.Element(Message) {
  html.div([], [
    html.div([], [
      html.input([
        attribute.value(model.draft),
        attribute.placeholder("say hi"),
        event.on_input(DraftChanged),
      ]),
      html.button([event.on_click(DraftSubmitted)], [html.text("sign")]),
    ]),
    html.p([], [
      html.text(int.to_string(list.length(model.entries)) <> " entries"),
    ]),
    html.ul(
      [],
      list.map(model.entries, fn(entry) { html.li([], [html.text(entry)]) }),
    ),
  ])
}
