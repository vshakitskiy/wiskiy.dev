import gleam/list
import lustre/attribute
import lustre/element
import lustre/element/html

const site_name = "wiskiy.dev"

const feed_path = "/feed.xml"

const source = "https://github.com/vshakitskiy/wiskiy.dev"

pub type Island {
  Island(module: String)
}

pub fn page(
  title title: String,
  description description: String,
  islands islands: List(Island),
  body body: List(element.Element(a)),
) -> element.Element(a) {
  html.html([attribute.lang("en")], [
    head(title, description),
    html.body([], [html.main([], body), footer(), ..scripts(islands)]),
  ])
}

pub fn strip_message(view: element.Element(a)) -> element.Element(Nil) {
  element.map(view, fn(_message) { Nil })
}

fn head(title: String, description: String) -> element.Element(a) {
  html.head([], [
    html.meta([attribute.charset("utf-8")]),
    html.meta([
      attribute.name("viewport"),
      attribute.content("width=device-width, initial-scale=1"),
    ]),
    html.title([], title <> " @ " <> site_name),
    html.meta([attribute.name("description"), attribute.content(description)]),
    html.link([attribute.rel("icon"), attribute.href("/favicon.ico")]),
    html.link([
      attribute.rel("preload"),
      attribute.href("/fonts/space-mono/space-mono-regular.woff2"),
      attribute.attribute("as", "font"),
      attribute.type_("font/woff2"),
      attribute.attribute("crossorigin", ""),
    ]),
    html.link([attribute.rel("stylesheet"), attribute.href("/style.css")]),
    html.link([
      attribute.rel("alternate"),
      attribute.type_("application/rss+xml"),
      attribute.href(feed_path),
    ]),
    html.script(
      [attribute.type_("speculationrules")],
      "{\"prerender\":[{\"where\":{\"href_matches\":\"/*\"},\"eagerness\":\"moderate\"}]}",
    ),
  ])
}

fn scripts(islands: List(Island)) -> List(element.Element(a)) {
  use Island(module:) <- list.map(islands)
  html.script(
    [attribute.src("/js/" <> module <> ".js"), attribute.type_("module")],
    "",
  )
}

fn footer() -> element.Element(a) {
  html.footer([attribute.class("footer")], [
    html.span([], [
      html.text("made with "),
      out("Lustre", "https://lustre.build"),
    ]),
    html.span([attribute.class("footer-links")], [
      out("source", source),
      out("feed", feed_path),
    ]),
  ])
}

fn out(text: String, url: String) -> element.Element(a) {
  html.a(
    [
      attribute.href(url),
      attribute.target("_blank"),
      attribute.rel("noopener noreferrer"),
    ],
    [html.text(text)],
  )
}
