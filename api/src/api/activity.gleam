//// GitHub contribution calendar refreshed on a timer and kept in 
//// `persistent_term`.

import gleam/bit_array
import gleam/crypto
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/json
import gleam/list
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result
import gleam/string
import wisp

const refresh_interval_milliseconds = 86_400_000

const retry_interval_milliseconds = 900_000

const user_agent = "wiskiy.dev"

const contributions_query = "query($login: String!) {
  user(login: $login) {
    contributionsCollection {
      contributionCalendar {
        totalContributions
        weeks { contributionDays { date contributionCount } }
      }
    }
  }
}"

pub type Credentials {
  Credentials(login: String, token: String)
}

pub type Snapshot {
  Missing
  Ready(json: String, etag: String)
}

pub opaque type Message {
  Refresh
}

pub type Error {
  RequestFailed(httpc.HttpError)
  UnexpectedStatus(status: Int)
  UnreadableCalendar(json.DecodeError)
}

type State {
  State(self: process.Subject(Message), credentials: Credentials)
}

// STORE -----------------------------------------------------------------------

type Key {
  GithubActivity
}

pub fn snapshot() -> Snapshot {
  persistent_get(GithubActivity, Missing)
}

pub fn put(snapshot: Snapshot) -> Nil {
  let _ = persistent_put(GithubActivity, snapshot)
  Nil
}

@external(erlang, "persistent_term", "put")
fn persistent_put(key: Key, value: Snapshot) -> atom.Atom

@external(erlang, "persistent_term", "get")
fn persistent_get(key: Key, default: Snapshot) -> Snapshot

// ACTOR -----------------------------------------------------------------------

pub fn supervised(
  credentials: Credentials,
) -> supervision.ChildSpecification(process.Subject(Message)) {
  supervision.worker(fn() { start(credentials) })
}

fn start(
  credentials: Credentials,
) -> Result(actor.Started(process.Subject(Message)), actor.StartError) {
  actor.new_with_initialiser(1000, fn(self) {
    process.send(self, Refresh)

    actor.initialised(State(self:, credentials:))
    |> actor.returning(self)
    |> Ok
  })
  |> actor.on_message(handle_message)
  |> actor.start
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Refresh -> {
      let delay = case fetch(state.credentials) {
        Ok(snapshot) -> {
          put(snapshot)
          refresh_interval_milliseconds
        }
        Error(error) -> {
          wisp.log_error(
            "github activity refresh failed: " <> string.inspect(error),
          )
          retry_interval_milliseconds
        }
      }

      let _timer = process.send_after(state.self, delay, Refresh)
      actor.continue(state)
    }
  }
}

// HANDLER ---------------------------------------------------------------------

pub fn handle_request(request: wisp.Request) -> wisp.Response {
  case snapshot() {
    Missing -> wisp.response(503)
    Ready(json:, etag:) ->
      case request.get_header(request, "if-none-match") {
        Ok(matched) if matched == etag -> wisp.response(304)
        Ok(_) | Error(Nil) -> wisp.json_response(json, 200)
      }
      |> response.set_header("etag", etag)
      |> response.set_header("cache-control", "public, max-age=3600")
  }
}

// FETCHING --------------------------------------------------------------------

fn fetch(config: Credentials) -> Result(Snapshot, Error) {
  let body =
    json.object([
      #("query", json.string(contributions_query)),
      #("variables", json.object([#("login", json.string(config.login))])),
    ])
    |> json.to_string

  let request =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_scheme(http.Https)
    |> request.set_host("api.github.com")
    |> request.set_path("/graphql")
    |> request.set_header("authorization", "bearer " <> config.token)
    |> request.set_header("user-agent", user_agent)
    |> request.set_header("content-type", "application/json")
    |> request.set_body(body)

  use response <- result.try(
    httpc.send(request)
    |> result.map_error(RequestFailed),
  )

  case response.status {
    200 -> from_response(response.body)
    status -> Error(UnexpectedStatus(status:))
  }
}

pub fn from_response(body: String) -> Result(Snapshot, Error) {
  use days <- result.try(
    json.parse(body, calendar_decoder())
    |> result.map_error(UnreadableCalendar),
  )

  case days {
    [] -> Ok(Missing)
    [Day(date: start, ..), ..] -> {
      let json =
        json.object([
          #("start", json.string(start)),
          #("total", json.int(list.fold(days, 0, fn(t, d) { t + d.count }))),
          #("counts", json.array(days, fn(day) { json.int(day.count) })),
        ])
        |> json.to_string

      Ok(Ready(json:, etag: etag(json)))
    }
  }
}

fn etag(json: String) -> String {
  let digest =
    crypto.hash(crypto.Sha256, <<json:utf8>>)
    |> bit_array.base16_encode
    |> string.slice(at_index: 0, length: 16)

  "\"" <> digest <> "\""
}

// DECODING --------------------------------------------------------------------

type Day {
  Day(date: String, count: Int)
}

fn calendar_decoder() -> decode.Decoder(List(Day)) {
  use weeks <- decode.subfield(
    ["data", "user", "contributionsCollection", "contributionCalendar", "weeks"],
    decode.list(week_decoder()),
  )
  decode.success(list.flatten(weeks))
}

fn week_decoder() -> decode.Decoder(List(Day)) {
  use days <- decode.field("contributionDays", decode.list(day_decoder()))
  decode.success(days)
}

fn day_decoder() -> decode.Decoder(Day) {
  use date <- decode.field("date", decode.string)
  use count <- decode.field("contributionCount", decode.int)
  decode.success(Day(date:, count:))
}

// CREDENTIALS -----------------------------------------------------------------

pub fn credentials(login: String, token: String) -> Result(Credentials, Nil) {
  case string.trim(login), string.trim(token) {
    "", _token | _login, "" -> Error(Nil)
    login, token -> Ok(Credentials(login:, token:))
  }
}
