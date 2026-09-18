//// Module to work with dates

import gleam/float
import gleam/int
import gleam/order
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp

const days_in_week = 7

/// Parses `YYYY-MM-DD` string to date.
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

/// Converts date to `YYYY-MM-DD` string.
pub fn to_iso(date: calendar.Date) -> String {
  int.to_string(date.year)
  <> "-"
  <> pad(calendar.month_to_int(date.month))
  <> "-"
  <> pad(date.day)
}

/// Converts date to human readable form.
pub fn to_human(date: calendar.Date) -> String {
  int.to_string(date.day)
  <> " "
  <> calendar.month_to_string(date.month)
  <> ", "
  <> int.to_string(date.year)
}

/// Converts date to proper RSS format.
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

pub fn compare(one: calendar.Date, other: calendar.Date) -> order.Order {
  case int.compare(one.year, other.year) {
    order.Eq ->
      case
        int.compare(
          calendar.month_to_int(one.month),
          calendar.month_to_int(other.month),
        )
      {
        order.Eq -> int.compare(one.day, other.day)
        months -> months
      }
    years -> years
  }
}

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

pub fn day_at(start: calendar.Date, offset: Int) -> calendar.Date {
  let #(date, _time) =
    timestamp.from_calendar(start, midday(), calendar.utc_offset)
    |> timestamp.add(duration.hours(24 * offset))
    |> timestamp.to_calendar(calendar.utc_offset)

  date
}

fn weekday_index(date: calendar.Date) -> Int {
  let seconds =
    timestamp.from_calendar(date, midday(), calendar.utc_offset)
    |> timestamp.to_unix_seconds
    |> float.round

  let days = int.floor_divide(seconds, 86_400) |> result.unwrap(0)
  int.modulo(days + 4, days_in_week) |> result.unwrap(0)
}

fn midday() -> calendar.TimeOfDay {
  calendar.TimeOfDay(12, 0, 0, 0)
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
