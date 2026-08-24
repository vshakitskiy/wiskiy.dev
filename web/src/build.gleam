import filepath
import gleam/io
import gleam/list
import lustre/element.{type Element}
import simplifile
import temporary
import web/page

const out_dir = "dist"

const assets_dir = "priv/assets"

const pages = [
  #(page.home, "index.html"),
  #(page.guestbook, "guestbook.html"),
  #(page.not_found, "not_found.html"),
]

pub fn main() -> Nil {
  let assert Ok(Nil) = {
    use dir <- temporary.create(temporary.directory())

    list.each(pages, fn(entry) {
      let #(view, filename) = entry
      write_page(dir, view(), filename)
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

  io.println("Built " <> out_dir <> "/")
}

fn write_page(
  directory: String,
  element: Element(Nil),
  filename: String,
) -> Nil {
  let assert Ok(_) =
    element.to_document_string(element)
    |> simplifile.write(to: filepath.join(directory, filename))
    as { "failed to write " <> filename <> "!" }

  Nil
}
