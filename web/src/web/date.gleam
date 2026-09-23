//// Parsing and formatting calendar dates.

import gleam/float
import gleam/int
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp

pub const days_in_week = 7

const seconds_per_day = 86_400

const midday = calendar.TimeOfDay(
  hours: 12,
  minutes: 0,
  seconds: 0,
  nanoseconds: 0,
)

/// Parses a `YYYY-MM-DD` string.
pub fn parse(text: String) -> Result(calendar.Date, Nil) {
  case string.split(text, "-") {
    [year, month, day] -> {
      use year <- result.try(int.parse(year))
      use month <- result.try(int.parse(month))
      use day <- result.try(int.parse(day))
      use month <- result.try(calendar.month_from_int(month))
      Ok(calendar.Date(year:, month:, day:))
    }
    _malformed -> Error(Nil)
  }
}

/// Formats a date as `YYYY-MM-DD`.
pub fn to_iso8601(date: calendar.Date) -> String {
  int.to_string(date.year)
  <> "-"
  <> pad(calendar.month_to_int(date.month))
  <> "-"
  <> pad(date.day)
}

/// Formats a date for people to read, like `8 August, 2006`.
pub fn to_human(date: calendar.Date) -> String {
  int.to_string(date.day)
  <> " "
  <> calendar.month_to_string(date.month)
  <> ", "
  <> int.to_string(date.year)
}

/// Formats a date the way RSS expects, like `Tue, 08 Aug 2006 00:00:00 GMT`.
pub fn to_rfc822(date: calendar.Date) -> String {
  short_weekday(date)
  <> ", "
  <> pad(date.day)
  <> " "
  <> short_month(date)
  <> " "
  <> int.to_string(date.year)
  <> " 00:00:00 GMT"
}

/// The name of the day of the week, like `Tuesday`.
pub fn weekday(date: calendar.Date) -> String {
  case weekday_index(date) {
    0 -> "Sunday"
    1 -> "Monday"
    2 -> "Tuesday"
    3 -> "Wednesday"
    4 -> "Thursday"
    5 -> "Friday"
    _saturday -> "Saturday"
  }
}

/// The date `offset` days after `start`.
pub fn day_at(start: calendar.Date, offset: Int) -> calendar.Date {
  let #(date, _time) =
    timestamp.from_calendar(start, midday, calendar.utc_offset)
    |> timestamp.add(duration.hours(24 * offset))
    |> timestamp.to_calendar(calendar.utc_offset)

  date
}

fn weekday_index(date: calendar.Date) -> Int {
  let seconds =
    timestamp.from_calendar(date, midday, calendar.utc_offset)
    |> timestamp.to_unix_seconds
    |> float.round

  let days = int.floor_divide(seconds, seconds_per_day) |> result.unwrap(0)
  int.modulo(days + 4, days_in_week) |> result.unwrap(0)
}

fn short_weekday(date: calendar.Date) -> String {
  string.slice(weekday(date), at_index: 0, length: 3)
}

fn short_month(date: calendar.Date) -> String {
  string.slice(calendar.month_to_string(date.month), at_index: 0, length: 3)
}

fn pad(value: Int) -> String {
  int.to_string(value) |> string.pad_start(to: 2, with: "0")
}
