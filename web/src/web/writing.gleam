//// Articles read from `writing/` and rendered to the html file.

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

pub type Post {
  Post(
    slug: String,
    title: String,
    date: calendar.Date,
    description: String,
    public: Bool,
    tags: List(String),
    islands: List(String),
    content: document.Document,
  )
}

pub type PostError {
  FileError(simplifile.FileError)
  MissingFrontmatter
  TomlParseError(tom.ParseError)
  TomlFieldError(field: String)
  UnreadableDate(date: String)
}

type Metadata {
  Metadata(
    title: String,
    date: calendar.Date,
    description: String,
    public: Bool,
    tags: List(String),
    islands: List(String),
  )
}

pub fn parse_posts(directory: String) -> Result(List(Post), PostError) {
  use files <- result.try(
    simplifile.read_directory(directory) |> result.map_error(FileError),
  )

  use posts <- result.try(
    list.filter(files, string.ends_with(_, ".md"))
    |> list.try_map(parse_post(directory, _)),
  )

  list.filter(posts, fn(post) { post.public })
  |> list.sort(fn(one, other) { date.compare(other.date, one.date) })
  |> Ok
}

pub fn parse_post(
  directory: String,
  filename: String,
) -> Result(Post, PostError) {
  let path = directory <> "/" <> filename
  let slug = string.replace(filename, ".md", "") |> slugify

  use raw <- result.try(simplifile.read(path) |> result.map_error(FileError))

  let extracted = frontmatter.extract(raw)

  use front <- result.try(case extracted.frontmatter {
    option.Some(frontmatter) -> Ok(frontmatter)
    option.None -> Error(MissingFrontmatter)
  })

  use metadata <- result.try(parse_metadata(front))

  Ok(Post(
    slug:,
    title: metadata.title,
    date: metadata.date,
    description: metadata.description,
    public: metadata.public,
    tags: metadata.tags,
    islands: metadata.islands,
    content: mork.parse(extracted.content),
  ))
}

fn parse_metadata(raw: String) -> Result(Metadata, PostError) {
  use toml <- result.try(tom.parse(raw) |> result.map_error(TomlParseError))

  use title <- get_field(toml, tom.get_string, "title")
  use written <- get_field(toml, tom.get_string, "date")
  use date <- result.try(
    date.parse(written) |> result.replace_error(UnreadableDate(written)),
  )
  use description <- get_field(toml, tom.get_string, "description")
  use public <- get_field(toml, tom.get_bool, "public")
  use tags <- get_field(toml, tom.get_array, "tags")

  use tags <- result.try(strings(tags, "tags"))

  use islands <- result.try(case tom.get_array(toml, ["islands"]) {
    Error(_missing) -> Ok([])
    Ok(islands) -> strings(islands, "islands")
  })

  Ok(Metadata(title:, date:, description:, public:, tags:, islands:))
}

fn strings(
  values: List(tom.Toml),
  field: String,
) -> Result(List(String), PostError) {
  use value <- list.try_map(values)
  case value {
    tom.String(text) -> Ok(text)
    _other -> Error(TomlFieldError(field))
  }
}

fn get_field(
  toml: toml,
  getter: fn(toml, List(String)) -> Result(value, tom.GetError),
  field: String,
  next: fn(value) -> Result(result, PostError),
) -> Result(result, PostError) {
  getter(toml, [field])
  |> result.replace_error(TomlFieldError(field))
  |> result.try(next)
}

pub fn render(post: Post) -> List(element.Element(a)) {
  list.map(post.content.blocks, render_block)
}

fn render_block(block: document.Block) -> element.Element(a) {
  case block {
    document.Paragraph(raw: _, inlines:) ->
      html.p([], list.map(inlines, render_inline))

    document.Heading(level:, id:, raw: _, inlines:) ->
      render_heading(level, id, inlines)

    document.Code(lang:, text:) -> render_code_block(lang, text)

    document.BlockQuote(blocks:) ->
      html.blockquote([], list.map(blocks, render_block))

    document.BulletList(pack: _, items:) ->
      html.ul([], list.map(items, render_list_item))

    document.OrderedList(pack: _, items:, start: _) ->
      html.ol([], list.map(items, render_list_item))

    document.ThematicBreak -> html.hr([])

    document.HtmlBlock(raw:) -> element.unsafe_raw_html("", "div", [], raw)

    document.Table(..) -> panic as "Table not implemented"

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
    _ -> html.h6
  }

  let id = case id, inlines {
    "", [document.Text(text)] -> slugify(text)
    "", _ -> ""
    id, _ -> id
  }

  heading([attribute.id(id)], list.map(inlines, render_inline))
}

fn render_code_block(
  lang: option.Option(String),
  text: String,
) -> element.Element(a) {
  let #(lang_class, lang_attr) = case lang {
    option.Some(l) -> #("hljs language-" <> l, l)
    option.None -> #("", "")
  }

  html.pre([], [
    html.code(
      [attribute.class(lang_class), attribute.attribute("data-lang", lang_attr)],
      [
        html.text(string.trim(text)),
      ],
    ),
  ])
}

fn render_inline(inline: document.Inline) -> element.Element(a) {
  case inline {
    document.Text(text) -> html.text(text)

    document.Emphasis(inlines) -> html.em([], list.map(inlines, render_inline))

    document.Strong(inlines) ->
      html.strong([], list.map(inlines, render_inline))

    document.CodeSpan(code) -> html.code([], [html.text(code)])

    document.FullLink(text:, data:) ->
      render_link(list.map(text, render_inline), dest_to_href(data.dest))

    document.Autolink(text:, uri:) ->
      render_link([html.text(option.unwrap(text, ""))], uri)

    document.EmailAutolink(mail:) ->
      render_link([html.text(mail)], "mailto:" <> mail)

    document.FullImage(text:, data:) -> render_image(text, data.dest)

    document.Strikethrough(inlines) ->
      html.s([], list.map(inlines, render_inline))

    document.Highlight(inlines) ->
      html.mark([], list.map(inlines, render_inline))

    document.InlineHtml(tag:, attrs:, children:) ->
      element.element(
        tag,
        list.map(dict.to_list(attrs), fn(p) { attribute.attribute(p.0, p.1) }),
        list.map(children, render_inline),
      )

    document.HardBreak -> html.br([])
    document.SoftBreak -> html.text("\n")

    document.RawHtml(raw) -> element.unsafe_raw_html("", "span", [], raw)

    document.RefImage(..) -> panic as "RefImage not implemented"
    document.RefLink(..) -> panic as "RefLink not implemented"
    document.Footnote(..) -> panic as "Footnote not implemented"
    document.InlineFootnote(..) -> panic as "InlineFootnote not implemented"
    document.Checkbox(..) -> panic as "Checkbox not implemented"
    document.Delim(..) -> panic as "Delim not implemented"
  }
}

fn render_link(
  children: List(element.Element(a)),
  href: String,
) -> element.Element(a) {
  let target = case href {
    "http://" <> _ | "https://" <> _ -> "_blank"
    _ -> ""
  }

  html.a(
    [
      attribute.href(href),
      attribute.target(target),
      attribute.rel("noopener noreferrer"),
    ],
    children,
  )
}

fn render_image(
  text: List(document.Inline),
  dest: document.Destination,
) -> element.Element(a) {
  let alt =
    list.map(text, fn(i) {
      case i {
        document.Text(t) -> t
        _ -> ""
      }
    })
    |> string.join("")

  html.img([attribute.src(dest_to_href(dest)), attribute.alt(alt)])
}

fn dest_to_href(dest: document.Destination) -> String {
  case dest {
    document.Absolute(uri:) | document.Relative(uri:) -> uri
    document.Anchor(id:) -> "#" <> id
  }
}

fn slugify(text: String) -> String {
  let allowed = "abcdefghijklmnopqrstuvwxyz0123456789-_"

  text
  |> string.lowercase
  |> string.replace(" ", "-")
  |> string.replace("'", "")
  |> string.to_graphemes
  |> list.filter(string.contains(allowed, _))
  |> string.join("")
}

pub const index = "/writing"

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
