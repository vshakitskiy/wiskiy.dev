//// A list with a preview panel that follows the pointer down the rows.

import gleam/int
import gleam/list
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
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

pub fn init(_flags: Nil) -> #(Model, effect.Effect(Message)) {
  #(Model(preview: Hidden(at: 0)), effect.none())
}

// UPDATE ----------------------------------------------------------------------

pub type Message {
  ProjectEntered(index: Int)
  ListLeft
}

pub fn update(
  model: Model,
  message: Message,
) -> #(Model, effect.Effect(Message)) {
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

pub fn view(model: Model) -> element.Element(Message) {
  let parked = row_of(model.preview)

  html.div([attribute.class("work")], [
    html.ul(
      [attribute.class("work-list"), event.on_mouse_leave(ListLeft)],
      list.index_map(projects, row),
    ),
    preview(model.preview, parked),
  ])
}

fn row(project: Project, index: Int) -> element.Element(Message) {
  html.li([attribute.class("work-item")], [
    html.a(
      [
        attribute.class("work-link"),
        attribute.href(project.url),
        attribute.target("_blank"),
        attribute.rel("noopener noreferrer"),
        event.on_mouse_enter(ProjectEntered(index:)),
        event.on_focus(ProjectEntered(index:)),
      ],
      [
        html.span([attribute.class("work-name")], [html.text(project.name)]),
        html.span([attribute.class("work-description")], [
          html.text(project.description),
        ]),
      ],
    ),
  ])
}

fn preview(state: Preview, parked: Int) -> element.Element(Message) {
  let visibility = case state {
    Shown(at: _shown_row) -> Showing
    Hidden(at: _hidden_row) -> Faded
  }

  html.div(
    [
      attribute.class("work-preview " <> class_for(visibility)),
      attribute.attribute("aria-hidden", "true"),
      attribute.style(
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

fn media(project: Project, visibility: Visibility) -> element.Element(Message) {
  let classes = "work-media " <> class_for(visibility)

  case project.media {
    Image(source:) ->
      html.img([
        attribute.class(classes),
        attribute.src(source),
        attribute.alt(project.name),
        attribute.attribute("loading", "lazy"),
      ])

    Video(source:) ->
      html.video(
        [
          attribute.class(classes),
          attribute.src(source),
          attribute.attribute("autoplay", ""),
          attribute.attribute("muted", ""),
          attribute.attribute("loop", ""),
          attribute.attribute("playsinline", ""),
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
