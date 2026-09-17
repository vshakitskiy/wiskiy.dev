//// A list with a preview panel that follows the pointer down the rows.

import gleam/int
import gleam/list
import lustre
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub const mount_id = "work"

pub type Project {
  Project(name: String, description: String, url: String, media: Media)
}

pub type Media {
  Image(source: String)
  Video(source: String)
}

pub const projects = [
  Project(
    name: "ewe",
    description: "a fluffy Gleam web server",
    url: "https://github.com/vshakitskiy/ewe",
    media: Image("/work/ewe.jpg"),
  ),
  Project(
    name: "tup",
    description: "acceptor pool using relay supervisor",
    url: "https://github.com/vshakitskiy/tup",
    media: Image("/work/tup.png"),
  ),
]

pub fn main() -> Nil {
  let app = lustre.application(init:, update:, view:)
  let assert Ok(_started) = lustre.start(app, onto: "#" <> mount_id, with: Nil)
  Nil
}

// MODEL -----------------------------------------------------------------------

pub type Model {
  Model(preview: Preview)
}

pub type Preview {
  Hidden(at: Int)
  Shown(at: Int)
}

pub fn init(_flags: Nil) -> #(Model, Effect(Message)) {
  #(Model(preview: Hidden(at: 0)), effect.none())
}

// UPDATE ----------------------------------------------------------------------

pub type Message {
  ProjectEntered(index: Int)
  ListLeft
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  let preview = case message {
    ProjectEntered(index:) -> Shown(at: index)
    ListLeft -> Hidden(at: row_of(model.preview))
  }

  #(Model(preview:), effect.none())
}

fn row_of(preview: Preview) -> Int {
  case preview {
    Hidden(at:) | Shown(at:) -> at
  }
}

// VIEW ------------------------------------------------------------------------

type Visibility {
  Showing
  Faded
}

pub fn view(model: Model) -> Element(Message) {
  let parked = row_of(model.preview)

  html.div([attr.class("work")], [
    html.ul(
      [attr.class("work-list"), event.on_mouse_leave(ListLeft)],
      list.index_map(projects, row),
    ),
    preview(model.preview, parked),
  ])
}

fn row(project: Project, index: Int) -> Element(Message) {
  html.li([attr.class("work-item")], [
    html.a(
      [
        attr.class("work-link"),
        attr.href(project.url),
        attr.target("_blank"),
        attr.rel("noopener noreferrer"),
        event.on_mouse_enter(ProjectEntered(index:)),
        event.on_focus(ProjectEntered(index:)),
      ],
      [
        html.span([attr.class("work-name")], [html.text(project.name)]),
        html.span([attr.class("work-description")], [
          html.text(project.description),
        ]),
      ],
    ),
  ])
}

fn preview(state: Preview, parked: Int) -> Element(Message) {
  let visibility = case state {
    Shown(at: _shown_row) -> Showing
    Hidden(at: _hidden_row) -> Faded
  }

  html.div(
    [
      attr.class("work-preview " <> class_for(visibility)),
      attr.attribute("aria-hidden", "true"),
      attr.style(
        "transform",
        "translateY(calc(var(--work-row) * " <> int.to_string(parked) <> "))",
      ),
    ],
    list.index_map(projects, fn(project, index) {
      media(project, case index == parked {
        True -> Showing
        False -> Faded
      })
    }),
  )
}

fn media(project: Project, visibility: Visibility) -> Element(Message) {
  let classes = "work-media " <> class_for(visibility)

  case project.media {
    Image(source:) ->
      html.img([
        attr.class(classes),
        attr.src(source),
        attr.alt(project.name),
        attr.attribute("loading", "lazy"),
      ])

    Video(source:) ->
      html.video(
        [
          attr.class(classes),
          attr.src(source),
          attr.attribute("autoplay", ""),
          attr.attribute("muted", ""),
          attr.attribute("loop", ""),
          attr.attribute("playsinline", ""),
        ],
        [],
      )
  }
}

fn class_for(visibility: Visibility) -> String {
  case visibility {
    Showing -> "is-shown"
    Faded -> "is-faded"
  }
}
