//// Markdown articles with TOML frontmatter.

import filepath
import frontmatter
import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/calendar
import lustre/attribute
import lustre/element
import lustre/element/html
import mork
import mork/document
import simplifile
import tom
import web/date

pub const index = "/writing"

const slug_characters = "abcdefghijklmnopqrstuvwxyz0123456789-_"

pub type Post {
  Post(
    slug: String,
    title: String,
    date: calendar.Date,
    description: String,
    visibility: Visibility,
    tags: List(String),
    islands: List(String),
    content: document.Document,
  )
}

pub type Visibility {
  Public
  Draft
}

pub type PostError {
  DirectoryUnreadable(path: String, reason: simplifile.FileError)
  PostUnreadable(path: String, reason: simplifile.FileError)
  PostMissingFrontmatter(path: String)
  PostInvalidFrontmatter(path: String, reason: tom.ParseError)
  PostInvalidField(path: String, field: String)
  PostInvalidDate(path: String, date: String)
  PostInvalidSlug(path: String)
  PostDuplicateSlug(slug: String, first_path: String, second_path: String)
}

pub type RenderError {
  UnsupportedMarkdown(article: String, feature: String)
}

pub fn parse_posts(directory: String) -> Result(List(Post), PostError) {
  use files <- result.try(
    simplifile.read_directory(directory)
    |> result.map_error(DirectoryUnreadable(directory, _)),
  )

  let files =
    list.filter(files, string.ends_with(_, ".md"))
    |> list.sort(string.compare)

  use #(_slugs, posts) <- result.try(
    list.try_fold(files, #(dict.new(), []), fn(accumulator, file) {
      let #(slugs, posts) = accumulator
      let path = filepath.join(directory, file)

      use post <- result.try(parse_post(path))

      case post.visibility {
        Draft -> Ok(accumulator)
        Public ->
          case dict.get(slugs, post.slug) {
            Ok(first_path) ->
              Error(PostDuplicateSlug(post.slug, first_path, path))
            Error(Nil) ->
              Ok(#(dict.insert(slugs, post.slug, path), [post, ..posts]))
          }
      }
    }),
  )

  posts
  |> list.sort(fn(one, other) {
    calendar.naive_date_compare(other.date, one.date)
  })
  |> Ok
}

fn parse_post(path: String) -> Result(Post, PostError) {
  use raw <- result.try(
    simplifile.read(path) |> result.map_error(PostUnreadable(path, _)),
  )

  let extracted = frontmatter.extract(raw)

  use frontmatter <- result.try(option.to_result(
    extracted.frontmatter,
    PostMissingFrontmatter(path),
  ))

  use toml <- result.try(
    tom.parse(frontmatter) |> result.map_error(PostInvalidFrontmatter(path, _)),
  )

  use title <- result.try(field(toml, "title", tom.get_string, path))
  use description <- result.try(field(toml, "description", tom.get_string, path))
  use public <- result.try(field(toml, "public", tom.get_bool, path))

  use written <- result.try(field(toml, "date", tom.get_string, path))
  use date <- result.try(
    date.parse(written) |> result.replace_error(PostInvalidDate(path, written)),
  )

  use tags <- result.try(field(toml, "tags", tom.get_array, path))
  use tags <- result.try(strings(tags, "tags", path))

  use islands <- result.try(case tom.get_array(toml, ["islands"]) {
    Ok(islands) -> strings(islands, "islands", path)
    Error(tom.NotFound(..)) -> Ok([])
    Error(tom.WrongType(..)) -> Error(PostInvalidField(path, "islands"))
  })

  let slug = path |> filepath.base_name |> filepath.strip_extension |> slugify

  use slug <- result.try(case slug {
    "" -> Error(PostInvalidSlug(path))
    slug -> Ok(slug)
  })

  Ok(Post(
    slug:,
    title:,
    date:,
    description:,
    visibility: case public {
      True -> Public
      False -> Draft
    },
    tags:,
    islands:,
    content: mork.parse(extracted.content),
  ))
}

fn field(
  toml: dict.Dict(String, tom.Toml),
  name: String,
  get: fn(dict.Dict(String, tom.Toml), List(String)) ->
    Result(value, tom.GetError),
  path: String,
) -> Result(value, PostError) {
  get(toml, [name])
  |> result.replace_error(PostInvalidField(path, name))
}

fn strings(
  values: List(tom.Toml),
  name: String,
  path: String,
) -> Result(List(String), PostError) {
  list.try_map(values, tom.as_string)
  |> result.replace_error(PostInvalidField(path, name))
}

pub fn path(post: Post) -> String {
  index <> "/" <> post.slug
}

pub fn has_code(post: Post) -> Bool {
  list.any(post.content.blocks, contains_code)
}

fn contains_code(block: document.Block) -> Bool {
  case block {
    document.Code(..) -> True
    document.BlockQuote(blocks:) -> list.any(blocks, contains_code)
    document.BulletList(items:, ..) | document.OrderedList(items:, ..) ->
      list.any(items, fn(item) { list.any(item.blocks, contains_code) })
    document.Paragraph(..)
    | document.Heading(..)
    | document.ThematicBreak
    | document.HtmlBlock(..)
    | document.Table(..)
    | document.Newline
    | document.Empty -> False
  }
}

pub fn render(post: Post) -> Result(List(element.Element(a)), RenderError) {
  list.try_map(post.content.blocks, render_block)
  |> result.map_error(UnsupportedMarkdown(path(post), _))
}

fn render_block(block: document.Block) -> Result(element.Element(a), String) {
  case block {
    document.Paragraph(inlines:, ..) ->
      render_inlines(inlines) |> result.map(html.p([], _))

    document.Heading(level:, id:, inlines:, ..) ->
      render_heading(level, id, inlines)

    document.Code(lang:, text:) -> Ok(render_code_block(lang, text))

    document.BlockQuote(blocks:) ->
      list.try_map(blocks, render_block)
      |> result.map(html.blockquote([], _))

    document.BulletList(items:, ..) ->
      list.try_map(items, render_list_item) |> result.map(html.ul([], _))

    document.OrderedList(items:, start:, ..) -> {
      let attributes = case start {
        option.Some(start) -> [
          attribute.attribute("start", int.to_string(start)),
        ]
        option.None -> []
      }

      list.try_map(items, render_list_item)
      |> result.map(html.ol(attributes, _))
    }

    document.ThematicBreak -> Ok(html.hr([]))

    document.HtmlBlock(raw:) -> Ok(element.unsafe_raw_html("", "div", [], raw))

    document.Table(..) -> Error("tables")

    document.Newline | document.Empty -> Ok(element.none())
  }
}

fn render_list_item(
  item: document.ListItem,
) -> Result(element.Element(a), String) {
  list.try_map(item.blocks, render_block) |> result.map(html.li([], _))
}

fn render_heading(
  level: Int,
  id: String,
  inlines: List(document.Inline),
) -> Result(element.Element(a), String) {
  let heading = case level {
    1 -> html.h1
    2 -> html.h2
    3 -> html.h3
    4 -> html.h4
    5 -> html.h5
    _deeper -> html.h6
  }

  let id = case id, inlines {
    "", [document.Text(text)] -> slugify(text)
    "", _formatted -> ""
    explicit, _inlines -> explicit
  }

  render_inlines(inlines) |> result.map(heading([attribute.id(id)], _))
}

fn render_code_block(
  language: option.Option(String),
  text: String,
) -> element.Element(a) {
  let attributes = case language {
    option.Some(language) -> [
      attribute.class("hljs language-" <> language),
      attribute.attribute("data-lang", language),
    ]
    option.None -> []
  }

  html.pre([], [html.code(attributes, [html.text(text)])])
}

fn render_inlines(
  inlines: List(document.Inline),
) -> Result(List(element.Element(a)), String) {
  list.try_map(inlines, render_inline)
}

fn render_inline(
  inline: document.Inline,
) -> Result(element.Element(a), String) {
  case inline {
    document.Text(text) -> Ok(html.text(text))

    document.Emphasis(inlines) ->
      render_inlines(inlines) |> result.map(html.em([], _))

    document.Strong(inlines) ->
      render_inlines(inlines) |> result.map(html.strong([], _))

    document.CodeSpan(code) -> Ok(html.code([], [html.text(code)]))

    document.FullLink(text:, data:) ->
      render_inlines(text)
      |> result.map(render_link(_, destination_to_href(data.dest)))

    document.Autolink(text:, uri:) ->
      Ok(render_link([html.text(option.unwrap(text, uri))], uri))

    document.EmailAutolink(mail:) ->
      Ok(render_link([html.text(mail)], "mailto:" <> mail))

    document.FullImage(text:, data:) -> render_image(text, data.dest)

    document.Strikethrough(inlines) ->
      render_inlines(inlines) |> result.map(html.s([], _))

    document.Highlight(inlines) ->
      render_inlines(inlines) |> result.map(html.mark([], _))

    document.InlineHtml(tag:, attrs:, children:) -> {
      let attributes =
        list.map(dict.to_list(attrs), fn(pair) {
          let #(name, value) = pair
          attribute.attribute(name, value)
        })

      render_inlines(children)
      |> result.map(element.element(tag, attributes, _))
    }

    document.HardBreak -> Ok(html.br([]))

    document.SoftBreak -> Ok(html.text("\n"))

    document.RawHtml(raw) -> Ok(element.unsafe_raw_html("", "span", [], raw))

    document.RefImage(..) -> Error("reference images")
    document.RefLink(..) -> Error("reference links")
    document.Footnote(..) | document.InlineFootnote(..) -> Error("footnotes")
    document.Checkbox(..) -> Error("checkboxes")
    document.Delim(..) -> Error("unresolved delimiters")
  }
}

fn render_link(
  children: List(element.Element(a)),
  href: String,
) -> element.Element(a) {
  let external = case href {
    "http://" <> _rest | "https://" <> _rest -> [
      attribute.target("_blank"),
      attribute.rel("noopener noreferrer"),
    ]
    _internal -> []
  }

  html.a([attribute.href(href), ..external], children)
}

fn render_image(
  text: List(document.Inline),
  destination: document.Destination,
) -> Result(element.Element(a), String) {
  use alt <- result.try(inline_text(text))

  Ok(
    html.img([
      attribute.src(destination_to_href(destination)),
      attribute.alt(alt),
    ]),
  )
}

fn inline_text(inlines: List(document.Inline)) -> Result(String, String) {
  list.try_map(inlines, fn(inline) {
    case inline {
      document.Text(text) | document.CodeSpan(text) -> Ok(text)
      document.Emphasis(children)
      | document.Strong(children)
      | document.Strikethrough(children)
      | document.Highlight(children)
      | document.FullLink(text: children, ..)
      | document.FullImage(text: children, ..)
      | document.InlineHtml(children:, ..) -> inline_text(children)
      document.Autolink(uri:, text:) -> Ok(option.unwrap(text, uri))
      document.EmailAutolink(mail:) -> Ok(mail)
      document.HardBreak | document.SoftBreak -> Ok(" ")
      document.RawHtml(_raw) -> Ok("")
      document.RefImage(..) -> Error("reference images")
      document.RefLink(..) -> Error("reference links")
      document.Footnote(..) | document.InlineFootnote(..) -> Error("footnotes")
      document.Checkbox(..) -> Error("checkboxes")
      document.Delim(..) -> Error("unresolved delimiters")
    }
  })
  |> result.map(string.concat)
}

fn destination_to_href(destination: document.Destination) -> String {
  case destination {
    document.Absolute(uri:) | document.Relative(uri:) -> uri
    document.Anchor(id:) -> "#" <> id
  }
}

fn slugify(text: String) -> String {
  text
  |> string.lowercase
  |> string.replace(" ", "-")
  |> string.to_graphemes
  |> list.filter(string.contains(slug_characters, _))
  |> string.concat
}
