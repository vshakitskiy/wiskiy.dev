import gleam/float
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg
import web/date
import web/islands/activity
import web/islands/age
import web/islands/archive
import web/islands/guestbook
import web/islands/presence
import web/islands/work
import web/layout.{Island}
import web/socials
import web/writing.{type Post}

// TODO: any webrings??? 

pub fn home(posts: List(Post)) -> Element(Nil) {
  let #(presence_model, _presence_effect) = presence.init(Nil)
  let #(activity_model, _activity_effect) = activity.init(Nil)
  let #(work_model, _work_effect) = work.init(Nil)
  let #(age_model, _age_effect) = age.init(Nil)

  layout.page(
    title: "Home",
    description: "software engineer & gleam enthusiast",
    islands: [
      Island("presence"),
      Island("activity"),
      Island("work"),
      Island("age"),
    ],
    body: [
      html.section([], [
        html.div([attribute.id(presence.mount_id)], [
          presence.view(presence_model)
          |> layout.strip_message,
        ]),
        html.p([], [html.text("software engineer & gleam enthusiast")]),
        socials.view(),
      ]),
      html.section([], [
        html.p([], [
          html.text("I am "),
          html.span([attribute.id(age.mount_id)], [
            age.view(age_model)
            |> layout.strip_message,
          ]),
          html.text(" years old living in Russia "),
          flag(),
          html.text(
            ", working on system designs mostly as a developer for the developers and other software using Gleam.",
          ),
        ]),
      ]),
      html.section([], [
        html.h2([], [html.text("Projects")]),
        html.div([attribute.id(work.mount_id)], [
          work.view(work_model)
          |> layout.strip_message,
        ]),
        html.div([attribute.id(activity.mount_id)], [
          activity.view(activity_model)
          |> layout.strip_message,
        ]),
      ]),
      html.section([], [
        html.h2([], [html.text("Writing")]),
        entries(list.take(posts, recent_articles)),
        html.a([attribute.class("more"), attribute.href("/writing.html")], [
          html.text("all writing →"),
        ]),
      ]),
    ],
  )
}

pub fn guestbook() -> Element(Nil) {
  let #(model, _effect) = guestbook.init(Nil)

  layout.page(
    title: "Guestbook",
    description: "Leave a message.",
    islands: [Island("guestbook")],
    body: [
      html.h1([], [html.text("Guestbook")]),
      html.section([attribute.id(guestbook.mount_id)], [
        guestbook.view(model)
        |> layout.strip_message,
      ]),
    ],
  )
}

pub fn not_found() -> Element(Nil) {
  layout.page(
    title: "Not found",
    description: "There's nothing here.",
    islands: [],
    body: [html.h1([], [html.text("404")])],
  )
}

// WRITING ---------------------------------------------------------------------

pub fn writing(posts: List(Post)) -> Element(Nil) {
  let model = archive.from_entries(list.map(posts, to_entry))

  layout.page(
    title: "Writing",
    description: "Things I've written down.",
    islands: [Island("archive")],
    body: [
      html.a([attribute.class("back"), attribute.href("/")], [
        html.text("← home"),
      ]),
      html.h1([], [html.text("Writing")]),
      html.div([attribute.id(archive.mount_id)], [
        archive.view(model)
        |> layout.strip_message,
      ]),
      html.script(
        [
          attribute.type_("application/json"),
          attribute.id(archive.index_id),
        ],
        archive.to_json(model.entries),
      ),
    ],
  )
}

fn to_entry(post: Post) -> archive.Entry {
  archive.Entry(
    path: writing.path(post),
    title: post.title,
    date: date.to_human(post.date),
    description: post.description,
    tags: post.tags,
  )
}

pub fn post(post: Post) -> Element(Nil) {
  layout.page(
    title: post.title,
    description: post.description,
    islands: list.map(post.islands, Island),
    body: [
      html.a([attribute.class("back"), attribute.href("/writing.html")], [
        html.text("← writing"),
      ]),
      html.article([attribute.class("post")], [
        html.header([attribute.class("post-header")], [
          html.h1([], [html.text(post.title)]),
          html.p([attribute.class("post-meta")], [
            html.time(
              [attribute.attribute("datetime", date.to_iso(post.date))],
              [html.text(date.to_human(post.date))],
            ),
          ]),
          tag_list(post.tags),
        ]),
        ..writing.render(post)
      ]),
    ],
  )
}

const recent_articles = 4

fn entries(posts: List(Post)) -> Element(Nil) {
  html.ul([attribute.class("entries")], list.map(posts, entry))
}

fn entry(post: Post) -> Element(Nil) {
  html.li([], [
    html.a([attribute.class("entry"), attribute.href(writing.path(post))], [
      html.span([attribute.class("entry-head")], [
        html.span([attribute.class("entry-title")], [html.text(post.title)]),
        html.span([attribute.class("entry-date")], [
          html.text(date.to_human(post.date)),
        ]),
      ]),
      html.span([attribute.class("entry-description")], [
        html.text(post.description),
      ]),
    ]),
  ])
}

fn tag_list(tags: List(String)) -> Element(Nil) {
  case tags {
    [] -> element.none()
    tags ->
      html.ul(
        [attribute.class("tags")],
        list.map(tags, fn(tag) {
          html.li([attribute.class("tag")], [html.text(tag)])
        }),
      )
  }
}

fn flag() -> Element(Nil) {
  svg.svg(
    [
      attribute.class("flag"),
      attribute.attribute("viewBox", "0 0 9 6"),
      attribute.attribute("role", "img"),
      attribute.attribute("aria-label", "Russia"),
    ],
    [
      svg.defs([], [
        svg.clip_path([attribute.id(flag_clip)], [
          rounded(x: 0.0, y: 0.0, width: 9.0, height: 6.0, radius: 0.85),
        ]),
      ]),
      svg.g([attribute.attribute("clip-path", "url(#" <> flag_clip <> ")")], [
        band(0.0, "#ffffff"),
        band(2.0, "#0039a6"),
        band(4.0, "#d52b1e"),
      ]),
      svg.rect([
        attribute.attribute("x", "0.15"),
        attribute.attribute("y", "0.15"),
        attribute.attribute("width", "8.7"),
        attribute.attribute("height", "5.7"),
        attribute.attribute("rx", "0.7"),
        attribute.attribute("fill", "none"),
        attribute.attribute("stroke", "currentColor"),
        attribute.attribute("stroke-opacity", "0.35"),
        attribute.attribute("stroke-width", "0.3"),
      ]),
    ],
  )
}

const flag_clip = "flag-corners"

fn band(top: Float, colour: String) -> Element(Nil) {
  svg.rect([
    attribute.attribute("x", "0"),
    attribute.attribute("y", float.to_string(top)),
    attribute.attribute("width", "9"),
    attribute.attribute("height", "2"),
    attribute.attribute("fill", colour),
  ])
}

fn rounded(
  x x: Float,
  y y: Float,
  width width: Float,
  height height: Float,
  radius radius: Float,
) -> Element(Nil) {
  svg.rect([
    attribute.attribute("x", float.to_string(x)),
    attribute.attribute("y", float.to_string(y)),
    attribute.attribute("width", float.to_string(width)),
    attribute.attribute("height", float.to_string(height)),
    attribute.attribute("rx", float.to_string(radius)),
  ])
}
