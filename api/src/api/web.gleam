import api/activity
import envoy
import filepath
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import wisp

pub type Environment {
  Development
  Production
}

pub type Context {
  Context(
    mode: Environment,
    port: Int,
    static_directory: String,
    activity: Activity,
  )
}

pub type Activity {
  Unconfigured
  Configured(credentials: activity.Credentials)
}

const default_port = 8080

const default_static_directory = "../web/dist"

pub fn create_context() -> Context {
  Context(
    mode: case envoy.get("MODE") {
      Ok("dev") -> Development
      Ok(_) | Error(_) -> Production
    },
    port: envoy.get("PORT")
      |> result.try(int.parse)
      |> result.unwrap(default_port),
    static_directory: envoy.get("STATIC_DIRECTORY")
      |> result.unwrap(default_static_directory),
    activity: create_activity(),
  )
}

fn create_activity() -> Activity {
  let credentials = {
    use login <- result.try(envoy.get("GITHUB_LOGIN"))
    use token <- result.try(envoy.get("GITHUB_TOKEN"))
    activity.credentials(login, token)
  }

  case credentials {
    Ok(credentials) -> Configured(credentials:)
    Error(Nil) -> Unconfigured
  }
}

pub fn serve(request: wisp.Request, from directory: String) -> wisp.Response {
  use <- wisp.serve_static(request, under: "", from: directory)
  use <- wisp.serve_static(as_html(request), under: "", from: directory)

  let path = filepath.join(directory, "not_found.html")

  response.new(404)
  |> response.set_header("content-type", "text/html; charset=utf-8")
  |> response.set_body(wisp.File(path:, offset: 0, limit: option.None))
}

fn as_html(req: wisp.Request) -> wisp.Request {
  let segments = wisp.path_segments(req)
  case list.last(segments) {
    Error(_) -> request.set_path(req, "/index.html")
    Ok(last) ->
      case string.contains(last, ".") {
        True -> req
        False ->
          request.set_path(req, "/" <> string.join(segments, "/") <> ".html")
      }
  }
}
