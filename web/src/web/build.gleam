//// Builds the static site into `dist/`: every page, the RSS feed and the
//// assets. Run it with `gleam run -m web/build`.
////
//// Everything is written to a temporary directory first, so a failed build
//// leaves the previous `dist/` untouched.

import filepath
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import lustre/element
import simplifile
import temporary
import web/feed
import web/page
import web/writing

const output_directory = "dist"

const assets_directory = "priv/assets"

const writing_directory = "writing"

/// Articles are written to `writing/<slug>.html`, matching `writing.path`.
const posts_directory = "writing"

pub fn main() -> Nil {
  let assert Ok(posts) = writing.parse_posts(writing_directory)
    as "failed to read writing/!"

  let assert Ok(Nil) = {
    use directory <- temporary.create(temporary.directory())

    write_page(directory, page.home(posts), "index.html")
    write_page(directory, page.writing(posts), "writing.html")
    write_page(directory, page.not_found(posts), "not_found.html")

    write_feed(directory, posts)

    let posts_output = filepath.join(directory, posts_directory)
    let assert Ok(Nil) = simplifile.create_directory(posts_output)
      as "failed to create writing output directory!"

    list.each(posts, fn(post) {
      write_page(posts_output, page.post(post), post.slug <> ".html")
    })

    let assert Ok(Nil) =
      simplifile.copy_directory(at: assets_directory, to: directory)
      as "failed to copy assets!"

    // Fails when there is no previous build, which is fine.
    let _previous_build = simplifile.delete(output_directory)
    let assert Ok(Nil) = simplifile.create_directory(output_directory)
      as "failed to create output directory!"
    let assert Ok(Nil) =
      simplifile.copy_directory(at: directory, to: output_directory)
      as "failed to copy temporary directory into output directory!"

    Nil
  }

  io.println(
    "Built "
    <> output_directory
    <> "/ with "
    <> int.to_string(list.length(posts))
    <> " article(s)",
  )
}

fn write_feed(directory: String, posts: List(writing.Post)) -> Nil {
  let assert Ok(Nil) =
    feed.from_posts(posts)
    |> element.to_string
    |> string.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n", _)
    |> simplifile.write(to: filepath.join(directory, "feed.xml"))
    as "failed to write feed.xml!"

  Nil
}

fn write_page(
  directory: String,
  element: element.Element(Nil),
  filename: String,
) -> Nil {
  let assert Ok(Nil) =
    element.to_document_string(element)
    |> simplifile.write(to: filepath.join(directory, filename))
    as { "failed to write " <> filename <> "!" }

  Nil
}
