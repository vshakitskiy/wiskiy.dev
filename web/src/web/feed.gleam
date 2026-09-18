//// The RSS feed.

import gleam/list
import lustre/attribute
import lustre/element.{element as tag}
import lustre/element/html
import web/date
import web/writing

pub const site = "https://wiskiy.dev"

const title = "wiskiy.dev"

const description = "My writings about Gleam, servers and whatever else."

const author = "vshakitskiy@gmail.com"

pub const path = "/feed.xml"

pub fn from_posts(posts: List(writing.Post)) -> element.Element(a) {
  tag("rss", [attribute.attribute("version", "2.0")], [
    tag("channel", [], [
      tag("title", [], [html.text(title)]),
      link(site),
      tag("description", [], [html.text(description)]),
      tag("language", [], [html.text("en")]),
      ..list.append(published(posts), list.map(posts, item))
    ]),
  ])
}

fn published(posts: List(writing.Post)) -> List(element.Element(a)) {
  case posts {
    [] -> []
    [newest, ..] -> [
      tag("pubDate", [], [html.text(date.to_rfc822(newest.date))]),
    ]
  }
}

fn item(post: writing.Post) -> element.Element(a) {
  let url = site <> writing.path(post)

  tag("item", [], [
    tag("title", [], [html.text(post.title)]),
    link(url),
    tag("guid", [attribute.attribute("isPermaLink", "true")], [html.text(url)]),
    tag("description", [], [html.text(post.description)]),
    tag("author", [], [html.text(author)]),
    tag("pubDate", [], [html.text(date.to_rfc822(post.date))]),
    ..list.map(post.tags, fn(tag_name) {
      tag("category", [], [html.text(tag_name)])
    })
  ])
}

fn link(url: String) -> element.Element(a) {
  element.unsafe_raw_html("", "link", [], url)
}
