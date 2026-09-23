//// Every page of the site. Islands are prerendered with their initial model
//// so the page looks fine before any JavaScript runs.

import gleam/int
import gleam/list
import gleam/result
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/element/svg
import web/date
import web/islands/activity
import web/islands/age
import web/islands/archive
import web/islands/guestbook
import web/islands/presence
import web/islands/work
import web/layout
import web/socials
import web/writing

// TODO: any webrings???

const recent_articles = 4

const flag_clip = "flag-corners"

// HOME ------------------------------------------------------------------------

pub fn home(posts: List(writing.Post)) -> element.Element(Nil) {
  let #(presence_model, _presence_effect) = presence.init(Nil)
  let #(activity_model, _activity_effect) = activity.init(Nil)
  let #(work_model, _work_effect) = work.init(Nil)
  let #(age_model, _age_effect) = age.init(Nil)

  layout.page(
    title: layout.site_name,
    description: "software engineer & gleam enthusiast",
    kind: layout.Website(path: "/"),
    islands: [
      layout.Island("presence"),
      layout.Island("activity"),
      layout.Island("work"),
      layout.Island("age"),
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
        recent(posts),
        html.a([attribute.class("more"), attribute.href(writing.index)], [
          html.text("all writing →"),
        ]),
      ]),
    ],
  )
}

/// A flag with rounded corners sized to sit inline with text.
fn flag() -> element.Element(a) {
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
          svg.rect([
            attribute.attribute("width", "9"),
            attribute.attribute("height", "6"),
            attribute.attribute("rx", "0.85"),
          ]),
        ]),
      ]),
      svg.g([attribute.attribute("clip-path", "url(#" <> flag_clip <> ")")], [
        band(top: 0, colour: "#ebe6dc"),
        band(top: 2, colour: "#002f87"),
        band(top: 4, colour: "#bf2419"),
      ]),
    ],
  )
}

fn band(top top: Int, colour colour: String) -> element.Element(a) {
  svg.rect([
    attribute.attribute("y", int.to_string(top)),
    attribute.attribute("width", "9"),
    attribute.attribute("height", "2"),
    attribute.attribute("fill", colour),
  ])
}

// GUESTBOOK -------------------------------------------------------------------

pub fn guestbook() -> element.Element(Nil) {
  let #(model, _effect) = guestbook.init(Nil)

  layout.page(
    title: "Guestbook",
    description: "Leave a message.",
    kind: layout.Website(path: "/guestbook"),
    islands: [layout.Island("guestbook")],
    body: [
      html.h1([], [html.text("Guestbook")]),
      html.section([attribute.id(guestbook.mount_id)], [
        guestbook.view(model)
        |> layout.strip_message,
      ]),
    ],
  )
}

// NOT FOUND -------------------------------------------------------------------

pub fn not_found(posts: List(writing.Post)) -> element.Element(Nil) {
  layout.page(
    title: "Not found",
    description: "There's nothing here!",
    kind: layout.NotFound,
    islands: [],
    body: [
      back(to: "/", label: "home"),
      html.section([attribute.class("lost")], [
        html.h1(
          [
            attribute.class("lost-code"),
            attribute.attribute("aria-label", "404, page not found"),
          ],
          [
            reel(4, spins: 14, duration: "1.1s"),
            reel(0, spins: 18, duration: "1.4s"),
            reel(4, spins: 22, duration: "1.7s"),
          ],
        ),
        html.p([attribute.class("lost-text")], [
          html.text("You may be lost, this page doesn't exist!"),
        ]),
      ]),
      case posts {
        [] -> element.none()
        posts ->
          html.section([], [
            html.h2([], [html.text("Maybe you seek for one of these?")]),
            recent(posts),
          ])
      },
    ],
  )
}

/// A column of digits that spins down and lands on `digit` like a slot
/// machine reel. The strip starts `spins - 1` cells up and slides into place.
fn reel(
  digit: Int,
  spins spins: Int,
  duration duration: String,
) -> element.Element(a) {
  let cells =
    int.range(from: spins - 1, to: -1, with: [], run: fn(cells, offset) {
      let shown = int.modulo(digit - offset, 10) |> result.unwrap(digit)
      let cell =
        html.span([attribute.class("lost-cell")], [
          html.text(int.to_string(shown)),
        ])

      [cell, ..cells]
    })

  html.span(
    [attribute.class("lost-reel"), attribute.attribute("aria-hidden", "true")],
    [
      html.span(
        [
          attribute.class("lost-strip"),
          attribute.styles([
            #("--from", "-" <> int.to_string(spins - 1) <> "em"),
            #("--spin", duration),
          ]),
        ],
        cells,
      ),
    ],
  )
}

// WRITING ---------------------------------------------------------------------

pub fn writing(posts: List(writing.Post)) -> element.Element(Nil) {
  let model = archive.from_entries(list.map(posts, to_entry))

  layout.page(
    title: "Writing",
    description: "Things I've written down.",
    kind: layout.Website(path: writing.index),
    islands: [layout.Island("archive")],
    body: [
      back(to: "/", label: "home"),
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

pub fn post(post: writing.Post) -> element.Element(Nil) {
  layout.page(
    title: post.title,
    description: post.description,
    kind: layout.Article(
      path: writing.path(post),
      published: post.date,
      tags: post.tags,
    ),
    islands: list.map(post.islands, layout.Island),
    body: [
      back(to: writing.index, label: "writing"),
      html.article([attribute.class("post")], [
        html.header([attribute.class("post-header")], [
          html.h1([], [html.text(post.title)]),
          html.p([attribute.class("post-meta")], [
            html.time(
              [attribute.attribute("datetime", date.to_iso8601(post.date))],
              [html.text(date.to_human(post.date))],
            ),
          ]),
          tag_list(post.tags),
        ]),
        ..writing.render(post)
      ]),
      ..highlighting(post)
    ],
  )
}

/// highlight.js loaded only on articles that have code blocks.
fn highlighting(post: writing.Post) -> List(element.Element(a)) {
  case writing.has_code(post) {
    False -> []
    True -> [
      html.script([attribute.src("/vendor/highlight.min.js")], ""),
      html.script([attribute.src("/vendor/gleam.min.js")], ""),
      html.script([], "hljs.highlightAll();"),
    ]
  }
}

fn tag_list(tags: List(String)) -> element.Element(a) {
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

// SHARED ----------------------------------------------------------------------

/// The newest few articles.
fn recent(posts: List(writing.Post)) -> element.Element(a) {
  list.take(posts, recent_articles)
  |> list.map(to_entry)
  |> archive.entry_list
}

fn to_entry(post: writing.Post) -> archive.Entry {
  archive.Entry(
    path: writing.path(post),
    title: post.title,
    date: date.to_human(post.date),
    description: post.description,
    tags: post.tags,
  )
}

fn back(to href: String, label label: String) -> element.Element(a) {
  html.a([attribute.class("back"), attribute.href(href)], [
    html.text("← " <> label),
  ])
}
