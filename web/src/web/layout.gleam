import gleam/list
import lustre/attribute as attr
import lustre/element.{type Element}
import lustre/element/html

const site_name = "wiskiy.dev"

pub type Island {
  Island(module: String)
}

pub fn page(
  title title: String,
  description description: String,
  islands islands: List(Island),
  body body: List(Element(a)),
) -> Element(a) {
  html.html([attr.lang("en")], [
    head(title, description),
    html.body([], [html.main([], body), footer(), ..scripts(islands)]),
  ])
}

pub fn strip_message(view: Element(a)) -> Element(Nil) {
  element.map(view, fn(_message) { Nil })
}

fn head(title: String, description: String) -> Element(a) {
  html.head([], [
    html.meta([attr.charset("utf-8")]),
    html.meta([
      attr.name("viewport"),
      attr.content("width=device-width, initial-scale=1"),
    ]),
    html.title([], title <> " @ " <> site_name),
    html.meta([attr.name("description"), attr.content(description)]),
    html.link([attr.rel("icon"), attr.href("/favicon.ico")]),
    html.link([attr.rel("stylesheet"), attr.href("/style.css")]),
    html.link([
      attr.rel("alternate"),
      attr.type_("application/rss+xml"),
      attr.href("/feed.xml"),
    ]),
    html.script(
      [attr.type_("speculationrules")],
      "{\"prerender\":[{\"where\":{\"href_matches\":\"/*\"},\"eagerness\":\"moderate\"}]}",
    ),
  ])
}

fn scripts(islands: List(Island)) -> List(Element(a)) {
  use Island(module:) <- list.map(islands)
  html.script([attr.src("/js/" <> module <> ".js"), attr.type_("module")], "")
}

fn nav() -> Element(a) {
  html.nav([], [
    link("home", "/"),
    link("work", "/work.html"),
    link("guestbook", "/guestbook.html"),
  ])
}

fn footer() -> Element(a) {
  html.footer([], [html.text("`footer`")])
}

fn link(text: String, to href: String) -> Element(a) {
  html.a([attr.href(href)], [html.text(text)])
}
