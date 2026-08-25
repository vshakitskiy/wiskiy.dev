import gleam/int
import gleam/json
import gleam/list
import gleam/string
import gleam/time/calendar
import gleeunit
import lustre/element
import web/islands/activity

pub fn main() -> Nil {
  gleeunit.main()
}

const slot_count = 371

pub fn an_empty_day_is_level_zero_test() -> Nil {
  assert activity.level(0, 10) == 0
}

pub fn a_single_contribution_is_visible_test() -> Nil {
  assert activity.level(1, 100) == 1
}

pub fn the_busiest_day_is_the_darkest_test() -> Nil {
  assert activity.level(10, 10) == 4
}

pub fn levels_scale_with_the_busiest_day_test() -> Nil {
  assert list.map([1, 2, 3, 4, 5, 6, 7, 8], activity.level(_, 8))
    == [1, 1, 2, 2, 3, 3, 4, 4]
}

pub fn a_year_with_no_contributions_does_not_divide_by_zero_test() -> Nil {
  assert activity.level(0, 0) == 0
}

pub fn a_short_year_is_padded_at_the_end_test() -> Nil {
  let padded = activity.slots([1, 2, 3])

  assert list.length(padded) == slot_count
  assert list.take(padded, 3) == [1, 2, 3]
  assert list.drop(padded, slot_count - 3) == [0, 0, 0]
}

pub fn a_real_length_year_keeps_its_alignment_test() -> Nil {
  let padded = activity.slots(list.append(list.repeat(7, 366), [4]))

  assert list.length(padded) == slot_count
  assert list.drop(padded, 366) == [4, 0, 0, 0, 0]
}

pub fn an_exact_year_is_untouched_test() -> Nil {
  let counts = list.repeat(1, slot_count)
  assert activity.slots(counts) == counts
}

pub fn a_long_year_is_trimmed_to_the_grid_test() -> Nil {
  let counts = list.append(list.repeat(1, slot_count), list.repeat(9, 5))
  let trimmed = activity.slots(counts)

  assert list.length(trimmed) == slot_count
  assert list.contains(trimmed, 9) == False
}

pub fn a_payload_from_the_api_decodes_test() -> Nil {
  assert json.parse(
      "{\"start\":\"2025-08-24\",\"total\":4,\"counts\":[0,3,1,0]}",
      activity.calendar_decoder(),
    )
    == Ok(activity.Loaded(start: "2025-08-24", total: 4, counts: [0, 3, 1, 0]))
}

// DATES -----------------------------------------------------------------------

fn date(year: Int, month: Int, day: Int) -> calendar.Date {
  let assert Ok(month) = calendar.month_from_int(month)
  calendar.Date(year:, month:, day:)
}

pub fn the_epoch_was_a_thursday_test() -> Nil {
  assert activity.weekday(date(1970, 1, 1)) == "Thursday"
}

pub fn the_calendar_opens_on_a_sunday_test() -> Nil {
  assert activity.weekday(date(2025, 8, 24)) == "Sunday"
}

pub fn every_weekday_is_reachable_test() -> Nil {
  assert list.map([24, 25, 26, 27, 28, 29, 30], fn(day) {
      activity.weekday(date(2025, 8, day))
    })
    == [
      "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday",
      "Saturday",
    ]
}

pub fn a_date_before_the_epoch_still_works_test() -> Nil {
  assert activity.weekday(date(1969, 7, 20)) == "Sunday"
}

pub fn offsetting_by_zero_is_the_same_day_test() -> Nil {
  assert activity.day_at(date(2025, 8, 24), 0) == date(2025, 8, 24)
}

pub fn offsetting_rolls_over_a_month_test() -> Nil {
  assert activity.day_at(date(2025, 8, 24), 8) == date(2025, 9, 1)
}

pub fn offsetting_rolls_over_a_year_test() -> Nil {
  assert activity.day_at(date(2025, 12, 31), 1) == date(2026, 1, 1)
}

pub fn offsetting_crosses_a_leap_day_test() -> Nil {
  assert activity.day_at(date(2024, 2, 28), 1) == date(2024, 2, 29)
  assert activity.day_at(date(2024, 2, 28), 2) == date(2024, 3, 1)
}

pub fn offsetting_skips_a_non_leap_february_test() -> Nil {
  assert activity.day_at(date(2025, 2, 28), 1) == date(2025, 3, 1)
}

pub fn the_last_reported_day_lands_where_github_said_test() -> Nil {
  let last = activity.day_at(date(2025, 8, 24), 366)

  assert last == date(2026, 8, 25)
  assert activity.weekday(last) == "Tuesday"
}

// RENDERING -------------------------------------------------------------------

fn render(calendar: activity.Calendar) -> String {
  activity.view(activity.Model(calendar:))
  |> element.to_string
}

pub fn the_loading_grid_describes_nothing_test() -> Nil {
  let markup = render(activity.Loading)

  assert string.contains(markup, "contributions on") == False
  assert count(markup, "activity-cell") == slot_count + 5
}

pub fn a_loaded_grid_describes_each_reported_day_test() -> Nil {
  let markup =
    render(activity.Loaded(start: "2025-08-24", total: 9, counts: [0, 1, 5]))

  assert string.contains(markup, "No contributions on Sunday, 24 August")
  assert string.contains(markup, "1 contribution on Monday, 25 August")
  assert string.contains(markup, "5 contributions on Tuesday, 26 August")
}

pub fn future_days_are_not_described_test() -> Nil {
  let markup =
    render(activity.Loaded(start: "2025-08-24", total: 1, counts: [1]))

  assert count(markup, "data-day=") == 1
}

fn count(haystack: String, needle: String) -> Int {
  string.split(haystack, needle) |> list.length |> int.subtract(1)
}
