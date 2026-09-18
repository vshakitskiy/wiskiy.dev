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

const out_dir = "dist"

const assets_dir = "priv/assets"

const writing_dir = "writing"

const writing_out = "writing"

pub fn main() -> Nil {
  let assert Ok(posts) = writing.parse_posts(writing_dir)
    as "failed to read writing/!"

  let assert Ok(Nil) = {
    use dir <- temporary.create(temporary.directory())

    write_page(dir, page.home(posts), "index.html")
    write_page(dir, page.writing(posts), "writing.html")
    write_page(dir, page.not_found(posts), "not_found.html")

    write_feed(dir, posts)

    let posts_dir = filepath.join(dir, writing_out)
    let assert Ok(_) = simplifile.create_directory(posts_dir)
      as "failed to create writing output directory!"

    list.each(posts, fn(post) {
      write_page(posts_dir, page.post(post), post.slug <> ".html")
    })

    let assert Ok(_) = simplifile.copy_directory(at: assets_dir, to: dir)
      as "failed to copy assets!"

    let _ = simplifile.delete(out_dir)
    let assert Ok(_) = simplifile.create_directory(out_dir)
      as "failed to create output directory!"
    let assert Ok(_) = simplifile.copy_directory(at: dir, to: out_dir)
      as "failed to copy temporary directory into output directory!"

    Nil
  }

  io.println(
    "Built "
    <> out_dir
    <> "/ with "
    <> int.to_string(list.length(posts))
    <> " article(s)",
  )
}

fn write_feed(directory: String, posts: List(writing.Post)) -> Nil {
  let assert Ok(_) =
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
  let assert Ok(_) =
    element.to_document_string(element)
    |> simplifile.write(to: filepath.join(directory, filename))
    as { "failed to write " <> filename <> "!" }

  Nil
}
