import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

pub fn main() -> Nil {
  let app = lustre.application(init:, update:, view:)
  let assert Ok(_) = lustre.start(app, onto: "#probe", with: Nil)
  Nil
}

pub type Model {
  Model(n: Int)
}

pub type Msg {
  Noop
}

pub fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  #(Model(0), effect.none())
}

pub fn update(model: Model, _msg: Msg) -> #(Model, Effect(Msg)) {
  #(model, effect.none())
}

pub fn view(_model: Model) -> Element(Msg) {
  html.div([], [html.text("probe")])
}
