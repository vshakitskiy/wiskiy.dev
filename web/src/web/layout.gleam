//// The HTML layout every page shares.

import gleam/list
import gleam/time/calendar
import lustre/attribute
import lustre/element
import lustre/element/html
import web/date

pub const site_name = "wiskiy.dev"

pub const site_url = "https://wiskiy.dev"

/// Where the RSS feed is published.
pub const feed_path = "/feed.xml"

const source = "https://github.com/vshakitskiy/wiskiy.dev"

/// An island's compiled module loaded from `/js/<module>.js`.
pub type Island {
  Island(module: String)
}

/// What a page is. This is for the better link previews.
pub type Kind {
  /// A regular page served at `path`.
  Website(path: String)
  /// An article served at `path`.
  Article(path: String, published: calendar.Date, tags: List(String))
  /// The not found page.
  NotFound
}

/// Wraps `body` in a full HTML document.
pub fn page(
  title title: String,
  description description: String,
  kind kind: Kind,
  islands islands: List(Island),
  body body: List(element.Element(a)),
) -> element.Element(a) {
  html.html([attribute.lang("en")], [
    head(title, description, kind),
    html.body([], [html.main([], body), footer(), ..scripts(islands)]),
  ])
}

/// Drops an island view's message type so it can be prerendered into a page.
pub fn strip_message(view: element.Element(a)) -> element.Element(Nil) {
  element.map(view, fn(_message) { Nil })
}

fn head(title: String, description: String, kind: Kind) -> element.Element(a) {
  html.head([], [
    html.meta([attribute.charset("utf-8")]),
    html.meta([
      attribute.name("viewport"),
      attribute.content("width=device-width, initial-scale=1"),
    ]),
    html.title([], title),
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
    // Prerender same site pages on hover so navigation feels instant.
    html.script(
      [attribute.type_("speculationrules")],
      "{\"prerender\":[{\"where\":{\"href_matches\":\"/*\"},\"eagerness\":\"moderate\"}]}",
    ),
    ..open_graph(title, description, kind)
  ])
}

/// Open Graph tags which chat apps and social sites read to build link previews. 
/// Twitter falls back to these for everything but the card type.
fn open_graph(
  title: String,
  description: String,
  kind: Kind,
) -> List(element.Element(a)) {
  let shared = [
    property("og:site_name", site_name),
    property("og:title", title),
    property("og:description", description),
    property("og:locale", "en_US"),
    html.meta([attribute.name("twitter:card"), attribute.content("summary")]),
  ]

  let specific = case kind {
    Website(path:) -> [property("og:type", "website"), ..address(path)]
    Article(path:, published:, tags:) -> [
      property("og:type", "article"),
      property("article:published_time", date.to_iso8601(published)),
      ..list.append(list.map(tags, property("article:tag", _)), address(path))
    ]
    NotFound -> [property("og:type", "website")]
  }

  list.append(shared, specific)
}

/// The page's canonical URL for search engines and link previews alike.
fn address(path: String) -> List(element.Element(a)) {
  let url = site_url <> path

  [
    property("og:url", url),
    html.link([attribute.rel("canonical"), attribute.href(url)]),
  ]
}

fn property(name: String, content: String) -> element.Element(a) {
  html.meta([attribute.attribute("property", name), attribute.content(content)])
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
      external_link("Lustre", "https://lustre.build"),
    ]),
    html.span([attribute.class("footer-links")], [
      external_link("source", source),
      external_link("feed", feed_path),
    ]),
  ])
}

fn external_link(text: String, url: String) -> element.Element(a) {
  html.a(
    [
      attribute.href(url),
      attribute.target("_blank"),
      attribute.rel("noopener noreferrer"),
    ],
    [html.text(text)],
  )
}
