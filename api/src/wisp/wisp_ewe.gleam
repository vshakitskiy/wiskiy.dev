//// Adapter that runs Wisp request handlers on the Ewe web server.

import ewe
import exception
import gleam/http/request
import gleam/http/response
import gleam/option
import gleam/string
import wisp
import wisp/internal

const max_body_size = 8_000_000

/// Convert a Wisp request handler into a function that can be run with the Ewe
/// web server.
///
/// # Examples
///
/// ```gleam
/// pub fn main() {
///   let secret_key_base = "..."
///   let listener_name = process.new_name("ewe_listener")
///   let connection_factory_name = process.new_name("ewe_connection_factory")
///
///   let assert Ok(_started) =
///     handle_request
///     |> wisp_ewe.handler(secret_key_base)
///     |> ewe.new(listener_name:, connection_factory_name:, handler: _)
///     |> ewe.listening(on: 8000)
///     |> ewe.start
///
///   process.sleep_forever()
/// }
/// ```
///
/// The secret key base is used for signing and encryption. To be able to
/// verify and decrypt messages you will need to use the same key each time
/// your program is run. Keep this value secret! Malicious people with this
/// value will likely be able to hack your application.
///
pub fn handler(
  handler: fn(wisp.Request) -> wisp.Response,
  secret_key_base: String,
) -> fn(request.Request(ewe.Connection)) -> response.Response(ewe.Body) {
  fn(request: request.Request(ewe.Connection)) {
    let connection = request.body
    let wisp_request =
      internal.make_connection(body_reader(request), secret_key_base)
      |> request.set_body(request, _)

    use <- exception.defer(fn() {
      let assert Ok(Nil) = wisp.delete_temporary_files(wisp_request)
    })

    handler(wisp_request)
    |> to_ewe_response(connection)
  }
}

fn body_reader(request: request.Request(ewe.Connection)) -> internal.Reader {
  fn(size) {
    case
      ewe.read_body_chunk(request, max_chunk_bytes: size, limit: max_body_size)
    {
      Ok(ewe.Chunk(data:, request:)) ->
        Ok(internal.Chunk(data, body_reader(request)))
      Ok(ewe.Done(..)) -> Ok(internal.ReadingFinished)
      Error(_reason) -> Error(Nil)
    }
  }
}

fn to_ewe_response(
  response: response.Response(wisp.Body),
  connection: ewe.Connection,
) -> response.Response(ewe.Body) {
  case response.body {
    wisp.Text(text) -> response.set_body(response, ewe.Text(text))
    wisp.Bytes(bytes) -> response.set_body(response, ewe.Bytes(bytes))
    wisp.File(path:, offset:, limit:) ->
      send_file(response, connection, path, offset, limit)
  }
}

fn send_file(
  response: response.Response(wisp.Body),
  connection: ewe.Connection,
  path: String,
  offset: Int,
  limit: option.Option(Int),
) -> response.Response(ewe.Body) {
  case ewe.file(connection, path, offset: option.Some(offset), limit:) {
    Ok(file) -> response.set_body(response, file)
    Error(error) -> {
      wisp.log_error(string.inspect(error))
      response.new(500) |> response.set_body(ewe.Empty)
    }
  }
}
