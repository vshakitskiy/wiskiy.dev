import gleam/int
import gleam/list
import lustre
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub const mount_id = "guestbook"

pub fn main() -> Nil {
  let app = lustre.application(init:, update:, view:)
  let assert Ok(_) = lustre.start(app, onto: "#" <> mount_id, with: Nil)
  Nil
}

pub type Model {
  Model(draft: String, entries: List(String))
}

pub type Msg {
  UserUpdatedDraft(String)
  UserSubmittedDraft
}

pub fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  // TODO: fetch existing entries from the api with rsvp
  #(Model(draft: "", entries: []), effect.none())
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserUpdatedDraft(draft) -> #(Model(..model, draft:), effect.none())

    // TODO: POST to the api instead of keeping this client side
    UserSubmittedDraft ->
      case model.draft {
        "" -> echo #(model, effect.none())
        draft -> #(
          Model(draft: "", entries: [draft, ..model.entries]),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([], [
    html.div([], [
      html.input([
        attr.value(model.draft),
        attr.placeholder("say hi"),
        event.on_input(UserUpdatedDraft),
      ]),
      html.button([event.on_click(UserSubmittedDraft)], [html.text("sign")]),
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
