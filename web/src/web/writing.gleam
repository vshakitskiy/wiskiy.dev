//// Articles read from `writing/` and rendered to HTML.
////
//// Each article is a Markdown file that starts with TOML frontmatter:
////
//// ```toml
//// title = "Hello"
//// date = "2025-10-19"
//// description = "A first post."
//// public = true
//// tags = ["gleam"]
////  # optional:
//// islands = ["web/islands/demo"]
//// ```

import filepath
import frontmatter
import gleam/dict
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

/// Path of the page that lists every article.
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
}

// PARSING ---------------------------------------------------------------------

/// Reads every public article in `directory`, newest first.
pub fn parse_posts(directory: String) -> Result(List(Post), PostError) {
  use files <- result.try(
    simplifile.read_directory(directory)
    |> result.map_error(DirectoryUnreadable(directory, _)),
  )

  use posts <- result.try(
    list.filter(files, string.ends_with(_, ".md"))
    |> list.try_map(fn(file) { parse_post(filepath.join(directory, file)) }),
  )

  list.filter(posts, fn(post) { post.visibility == Public })
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
  use written <- result.try(field(toml, "date", tom.get_string, path))
  use date <- result.try(
    date.parse(written) |> result.replace_error(PostInvalidDate(path, written)),
  )
  use description <- result.try(field(toml, "description", tom.get_string, path))
  use public <- result.try(field(toml, "public", tom.get_bool, path))
  use tags <- result.try(field(toml, "tags", tom.get_array, path))
  use tags <- result.try(strings(tags, "tags", path))
  use islands <- result.try(case tom.get_array(toml, ["islands"]) {
    Ok(islands) -> strings(islands, "islands", path)
    Error(tom.NotFound(..)) -> Ok([])
    Error(tom.WrongType(..)) -> Error(PostInvalidField(path, "islands"))
  })

  Ok(Post(
    slug: path |> filepath.base_name |> filepath.strip_extension |> slugify,
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

// QUERIES ---------------------------------------------------------------------

/// Path of the article's own page.
pub fn path(post: Post) -> String {
  index <> "/" <> post.slug
}

/// Whether the article has a code block and so needs syntax highlighting.
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

// RENDERING -------------------------------------------------------------------

/// Renders the article body. Markdown the site doesn't support yet stops the 
/// build with a panic.
pub fn render(post: Post) -> List(element.Element(a)) {
  list.map(post.content.blocks, render_block)
}

fn render_block(block: document.Block) -> element.Element(a) {
  case block {
    document.Paragraph(inlines:, ..) -> html.p([], render_inlines(inlines))

    document.Heading(level:, id:, inlines:, ..) ->
      render_heading(level, id, inlines)

    document.Code(lang:, text:) -> render_code_block(lang, text)

    document.BlockQuote(blocks:) ->
      html.blockquote([], list.map(blocks, render_block))

    document.BulletList(items:, ..) ->
      html.ul([], list.map(items, render_list_item))

    document.OrderedList(items:, ..) ->
      html.ol([], list.map(items, render_list_item))

    document.ThematicBreak -> html.hr([])

    document.HtmlBlock(raw:) -> element.unsafe_raw_html("", "div", [], raw)

    document.Table(..) -> panic as "tables are not supported yet"

    document.Newline | document.Empty -> element.none()
  }
}

fn render_list_item(item: document.ListItem) -> element.Element(a) {
  html.li([], list.map(item.blocks, render_block))
}

fn render_heading(
  level: Int,
  id: String,
  inlines: List(document.Inline),
) -> element.Element(a) {
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

  heading([attribute.id(id)], render_inlines(inlines))
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

  html.pre([], [html.code(attributes, [html.text(string.trim(text))])])
}

fn render_inlines(inlines: List(document.Inline)) -> List(element.Element(a)) {
  list.map(inlines, render_inline)
}

fn render_inline(inline: document.Inline) -> element.Element(a) {
  case inline {
    document.Text(text) -> html.text(text)

    document.Emphasis(inlines) -> html.em([], render_inlines(inlines))

    document.Strong(inlines) -> html.strong([], render_inlines(inlines))

    document.CodeSpan(code) -> html.code([], [html.text(code)])

    document.FullLink(text:, data:) ->
      render_link(render_inlines(text), destination_to_href(data.dest))

    document.Autolink(text:, uri:) ->
      render_link([html.text(option.unwrap(text, uri))], uri)

    document.EmailAutolink(mail:) ->
      render_link([html.text(mail)], "mailto:" <> mail)

    document.FullImage(text:, data:) -> render_image(text, data.dest)

    document.Strikethrough(inlines) -> html.s([], render_inlines(inlines))

    document.Highlight(inlines) -> html.mark([], render_inlines(inlines))

    document.InlineHtml(tag:, attrs:, children:) ->
      element.element(
        tag,
        list.map(dict.to_list(attrs), fn(pair) {
          let #(name, value) = pair
          attribute.attribute(name, value)
        }),
        render_inlines(children),
      )

    document.HardBreak -> html.br([])

    document.SoftBreak -> html.text("\n")

    document.RawHtml(raw) -> element.unsafe_raw_html("", "span", [], raw)

    document.RefImage(..) -> panic as "reference images are not supported yet"
    document.RefLink(..) -> panic as "reference links are not supported yet"
    document.Footnote(..) -> panic as "footnotes are not supported yet"
    document.InlineFootnote(..) -> panic as "footnotes are not supported yet"
    document.Checkbox(..) -> panic as "checkboxes are not supported yet"
    document.Delim(..) -> panic as "delimiters are not supported yet"
  }
}

/// Links that leave the site open in a new tab.
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
) -> element.Element(a) {
  let alt =
    list.map(text, fn(inline) {
      case inline {
        document.Text(text) -> text
        _formatted -> ""
      }
    })
    |> string.concat

  html.img([attribute.src(destination_to_href(destination)), attribute.alt(alt)])
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
