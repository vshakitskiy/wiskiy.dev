//// Project manifest for the screenshot script.

import gleam/io
import gleam/json
import web/island/work

pub fn main() -> Nil {
  work.featured()
  |> json.array(fn(project) {
    let #(kind, source) = case project.media {
      work.Image(source:) -> #("image", source)
      work.Video(source:) -> #("video", source)
    }

    json.object([
      #("name", json.string(project.name)),
      #("url", json.string(project.url)),
      #("kind", json.string(kind)),
      #("source", json.string(source)),
    ])
  })
  |> json.to_string
  |> io.println
}
