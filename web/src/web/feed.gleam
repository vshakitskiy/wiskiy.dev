//// The RSS feed of the articles.

import gleam/list
import lustre/attribute
import lustre/element
import lustre/element/html
import web/date
import web/layout
import web/writing

const description = "My writings about Gleam, servers and whatever else."

const author = "vshakitskiy@gmail.com"

/// Builds the `<rss>` document, newest article first.
pub fn from_posts(posts: List(writing.Post)) -> element.Element(a) {
  element.element("rss", [attribute.attribute("version", "2.0")], [
    element.element("channel", [], [
      text_element("title", layout.site_name),
      link(layout.site_url),
      text_element("description", description),
      text_element("language", "en"),
      ..list.append(published(posts), list.map(posts, item))
    ]),
  ])
}

fn published(posts: List(writing.Post)) -> List(element.Element(a)) {
  case posts {
    [] -> []
    [newest, ..] -> [text_element("pubDate", date.to_rfc822(newest.date))]
  }
}

fn item(post: writing.Post) -> element.Element(a) {
  let url = layout.site_url <> writing.path(post)

  element.element("item", [], [
    text_element("title", post.title),
    link(url),
    element.element("guid", [attribute.attribute("isPermaLink", "true")], [
      html.text(url),
    ]),
    text_element("description", post.description),
    text_element("author", author),
    text_element("pubDate", date.to_rfc822(post.date)),
    ..list.map(post.tags, text_element("category", _))
  ])
}

fn text_element(name: String, text: String) -> element.Element(a) {
  element.element(name, [], [html.text(text)])
}

fn link(url: String) -> element.Element(a) {
  element.unsafe_raw_html("", "link", [], url)
}
