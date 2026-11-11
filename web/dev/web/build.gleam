//// Stages the complete site before replacing `dist/`.

import filepath
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import lustre/element
import shellout
import simplifile
import temporary
import web/feed
import web/page
import web/writing

const output_directory = "dist"

const assets_directory = "priv/assets"

const writing_directory = "writing"

const builtin_islands = [
  "web/island/guestbook",
  "web/island/presence",
  "web/island/activity",
  "web/island/work",
  "web/island/archive",
  "web/island/age",
]

type BuildError {
  CouldNotPrepareBuild(reason: simplifile.FileError)
  CouldNotReadArticles(reason: writing.PostError)
  CouldNotRenderArticle(reason: writing.RenderError)
  CouldNotWriteOutput(path: String, reason: simplifile.FileError)
  CouldNotCopyAssets(
    source: String,
    destination: String,
    reason: simplifile.FileError,
  )
  CouldNotBuildIslands(status: Int, output: String)
  ConflictingIslandBundles(first: String, second: String)
  CouldNotMovePreviousBuild(reason: simplifile.FileError)
  CouldNotPublishBuild(reason: simplifile.FileError)
  CouldNotRestorePreviousBuild(
    backup: String,
    publication_error: simplifile.FileError,
    restoration_error: simplifile.FileError,
  )
}

pub fn main() -> Nil {
  let outcome =
    temporary.directory()
    |> temporary.in_directory("build")
    |> temporary.with_prefix("site-")
    |> temporary.create(build)
    |> result.map_error(CouldNotPrepareBuild)
    |> result.flatten

  case outcome {
    Ok(count) ->
      io.println(
        "Built "
        <> output_directory
        <> "/ with "
        <> int.to_string(count)
        <> " article(s)",
      )
    Error(CouldNotBuildIslands(status:, output:)) -> {
      io.println_error(output)
      io.println_error(
        "Island build failed with status " <> int.to_string(status),
      )
      shellout.exit(1)
    }
    Error(error) -> {
      io.println_error("Site build failed: " <> string.inspect(error))
      shellout.exit(1)
    }
  }
}

fn build(temporary_directory: String) -> Result(Int, BuildError) {
  use posts <- result.try(
    writing.parse_posts(writing_directory)
    |> result.map_error(CouldNotReadArticles),
  )

  let directory = filepath.join(temporary_directory, "site")

  use Nil <- result.try(create_directory(directory))
  use Nil <- result.try(write_page(directory, page.home(posts), "index.html"))
  use Nil <- result.try(write_page(
    directory,
    page.writing(posts),
    "writing.html",
  ))
  use Nil <- result.try(write_page(
    directory,
    page.not_found(posts),
    "not_found.html",
  ))
  use Nil <- result.try(write_feed(directory, posts))

  let articles_directory = filepath.join(directory, "writing")

  use Nil <- result.try(create_directory(articles_directory))
  use Nil <- result.try(
    list.try_each(posts, fn(post) {
      use rendered <- result.try(
        page.post(post) |> result.map_error(CouldNotRenderArticle),
      )

      write_page(articles_directory, rendered, post.slug <> ".html")
    }),
  )

  use Nil <- result.try(copy_assets(assets_directory, directory))
  use Nil <- result.try(build_islands(directory, posts))

  use Nil <- result.try(publish(
    directory,
    backup: temporary_directory <> "-previous",
  ))

  Ok(list.length(posts))
}

fn create_directory(path: String) -> Result(Nil, BuildError) {
  simplifile.create_directory_all(path)
  |> result.map_error(CouldNotWriteOutput(path, _))
}

fn write_feed(
  directory: String,
  posts: List(writing.Post),
) -> Result(Nil, BuildError) {
  let path = filepath.join(directory, "feed.xml")

  feed.from_posts(posts)
  |> element.to_string
  |> string.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n", _)
  |> simplifile.write(to: path)
  |> result.map_error(CouldNotWriteOutput(path, _))
}

fn write_page(
  directory: String,
  element: element.Element(Nil),
  filename: String,
) -> Result(Nil, BuildError) {
  let path = filepath.join(directory, filename)

  element.to_document_string(element)
  |> simplifile.write(to: path)
  |> result.map_error(CouldNotWriteOutput(path, _))
}

fn copy_assets(source: String, destination: String) -> Result(Nil, BuildError) {
  use entries <- result.try(
    simplifile.read_directory(source)
    |> result.map_error(CouldNotCopyAssets(source, destination, _)),
  )
  use entry <- list.try_each(entries)

  let source = filepath.join(source, entry)
  let destination = filepath.join(destination, entry)

  use info <- result.try(
    simplifile.file_info(source)
    |> result.map_error(CouldNotCopyAssets(source, destination, _)),
  )

  case simplifile.file_info_type(info) {
    simplifile.File ->
      simplifile.copy_file(source, destination)
      |> result.map_error(CouldNotCopyAssets(source, destination, _))
    simplifile.Directory -> {
      use Nil <- result.try(
        simplifile.create_directory(destination)
        |> result.map_error(CouldNotCopyAssets(source, destination, _)),
      )

      copy_assets(source, destination)
    }
    simplifile.Symlink | simplifile.Other ->
      Error(CouldNotCopyAssets(source, destination, simplifile.Eftype))
  }
}

fn build_islands(
  directory: String,
  posts: List(writing.Post),
) -> Result(Nil, BuildError) {
  let islands =
    list.append(
      builtin_islands,
      list.flat_map(posts, fn(post) { post.islands }),
    )
    |> list.unique

  use Nil <- result.try(
    list.try_each(islands, fn(island) {
      case
        list.find(islands, fn(other) {
          island != other
          && filepath.base_name(island) == filepath.base_name(other)
        })
      {
        Ok(other) -> Error(ConflictingIslandBundles(island, other))
        Error(Nil) -> Ok(Nil)
      }
    }),
  )

  use output <- result.try(
    shellout.command(
      run: "gleam",
      with: [
        "run",
        "--no-print-progress",
        "-m",
        "lustre/dev",
        "build",
        "--minify",
        "--no-html",
        "--outdir=" <> filepath.join(directory, "js"),
        ..islands
      ],
      in: ".",
      opt: [],
    )
    |> result.map_error(fn(error) {
      let #(status, output) = error
      CouldNotBuildIslands(status:, output:)
    }),
  )

  io.print(output)
  Ok(Nil)
}

fn publish(
  directory: String,
  backup backup: String,
) -> Result(Nil, BuildError) {
  use previous <- result.try(case simplifile.rename(output_directory, backup) {
    Ok(Nil) -> Ok(True)
    Error(simplifile.Enoent) -> Ok(False)
    Error(reason) -> Error(CouldNotMovePreviousBuild(reason))
  })

  case simplifile.rename(directory, output_directory) {
    Ok(Nil) -> {
      case previous {
        False -> Nil
        True ->
          case simplifile.delete(backup) {
            Ok(Nil) -> Nil
            Error(reason) ->
              io.println_error(
                "Published successfully; could not remove backup "
                <> backup
                <> ": "
                <> simplifile.describe_error(reason),
              )
          }
      }

      Ok(Nil)
    }
    Error(publication_error) ->
      case previous {
        False -> Error(CouldNotPublishBuild(publication_error))
        True ->
          case simplifile.rename(backup, output_directory) {
            Ok(Nil) -> Error(CouldNotPublishBuild(publication_error))
            Error(restoration_error) ->
              Error(CouldNotRestorePreviousBuild(
                backup:,
                publication_error:,
                restoration_error:,
              ))
          }
      }
  }
}
