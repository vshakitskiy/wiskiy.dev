//// The api server. It starts as an OTP application, serves the GitHub activity 
//// endpoint and the built site in development environment.

import api/activity
import api/web
import ewe
import gleam/erlang/application
import gleam/erlang/process
import gleam/http
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/result
import wisp
import wisp/wisp_ewe

/// Keeps the node alive while the application supervisor does the work.
pub fn main() -> Nil {
  process.sleep_forever()
}

/// Starts the web server and, when credentials are set, the activity worker.
/// Called by OTP as the application start callback.
pub fn start(
  _start_type: application.StartType,
  _start_arguments: List(Nil),
) -> Result(process.Pid, actor.StartError) {
  wisp.configure_logger()

  let context = web.create_context()
  let secret_key_base = wisp.random_string(64)
  let listener_name = process.new_name("ewe_listener")
  let connection_factory_name = process.new_name("ewe_connection_factory")

  let server =
    handle_request(context, _)
    |> wisp_ewe.handler(secret_key_base)
    |> ewe.new(listener_name, connection_factory_name, _)
    |> ewe.listening(on: context.port)
    |> ewe.bind(to: "::")

  supervisor.new(supervisor.OneForOne)
  |> add_activity(context.activity)
  |> supervisor.add(ewe.supervised(server))
  |> supervisor.start
  |> result.map(fn(started) { started.pid })
}

/// Called by OTP as the application stop callback.
pub fn stop(_state: Nil) -> Nil {
  Nil
}

fn add_activity(
  builder: supervisor.Builder,
  config: web.Activity,
) -> supervisor.Builder {
  case config {
    web.Unconfigured -> builder
    web.Configured(credentials:) ->
      supervisor.add(builder, activity.supervised(credentials))
  }
}

fn handle_request(
  context: web.Context,
  request: wisp.Request,
) -> wisp.Response {
  use <- wisp.log_request(request)
  use <- wisp.rescue_crashes

  case request.method, wisp.path_segments(request) {
    http.Get, ["health"] -> wisp.ok()
    http.Get, ["api", "activity"] -> activity.handle_request(request)
    _method, _segments ->
      case context.mode {
        web.Production -> wisp.not_found()
        web.Development -> web.serve(request, from: context.static_directory)
      }
  }
}
