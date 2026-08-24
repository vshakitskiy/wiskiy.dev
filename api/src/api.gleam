import ewe
import gleam/erlang/process
import wisp
import wisp/wisp_ewe

pub fn main() -> Nil {
  wisp.configure_logger()

  let secret_key_base = wisp.random_string(64)
  let listener_name = process.new_name("ewe_listener")
  let connection_factory_name = process.new_name("ewe_connection_factory")

  let assert Ok(_) =
    handle_request
    |> wisp_ewe.handler(secret_key_base)
    |> ewe.new(listener_name, connection_factory_name, _)
    |> ewe.listening(on: 8080)
    |> ewe.bind(to: "0.0.0.0")
    |> ewe.start

  process.sleep_forever()
}

fn handle_request(req: wisp.Request) -> wisp.Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes

  case wisp.path_segments(req) {
    ["health"] -> wisp.ok()

    _ -> wisp.not_found()
  }
}
