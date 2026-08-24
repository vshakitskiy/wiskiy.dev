import gleam/json
import gleam/option.{None, Some}
import gleeunit
import web/islands/presence

pub fn main() -> Nil {
  gleeunit.main()
}

fn decode(text: String) -> Result(presence.Event, json.DecodeError) {
  json.parse(text, presence.event_decoder())
}

pub fn hello_carries_the_heartbeat_interval_test() -> Nil {
  assert "{\"op\":1,\"d\":{\"heartbeat_interval\":30000}}"
    |> decode
    == Ok(presence.Hello(heartbeat_interval: 30_000))
}

pub fn init_state_is_the_presence_itself_test() -> Nil {
  assert "{\"op\": 0, \"seq\": 1, \"t\": \"INIT_STATE\", \"d\": {\"discord_status\": \"dnd\", \"activities\": []}}"
    |> decode
    == Ok(
      presence.PresenceReceived(presence.Known(
        status: presence.DoNotDisturb,
        listening: presence.Nothing,
      )),
    )
}

pub fn a_real_soundcloud_payload_decodes_test() -> Nil {
  assert "{\"op\":0,\"d\":{\"kv\":{},\"discord_user\":{\"avatar\":\"b9d5b7028df6084a9bc98398b717eba3\",\"avatar_decoration_data\":null,\"bot\":false,\"discriminator\":\"0\",\"display_name\":\"wiskiy\",\"global_name\":\"wiskiy\",\"id\":\"511911643475738656\",\"primary_guild\":null,\"public_flags\":128,\"username\":\"vshakitskiy\"},\"activities\":[{\"application_id\":\"383226320970055681\",\"assets\":{\"large_image\":\"1359298813310795827\",\"large_text\":\"Editing a GLEAM file\",\"small_image\":\"1359299466493956258\",\"small_text\":\"Visual Studio Code\"},\"created_at\":1787591481654,\"details\":\"Editing presence.gleam\",\"id\":\"a9b7261f1edfbdb6\",\"name\":\"Visual Studio Code\",\"platform\":\"desktop\",\"session_id\":\"860a5ca58c9f8ea99659db4505b80874\",\"timestamps\":{\"start\":1787561827568},\"type\":0},{\"application_id\":\"1090770350251458592\",\"assets\":{\"large_image\":\"mp:external/AxH7LKleYb4lHbABvXpDlRLBw-FGCJxEF1or9JCBwsc/https/i1.sndcdn.com/artworks-5kQuiFyjxgG82DZw-Vr8Mtw-t500x500.jpg\"},\"created_at\":1787591742448,\"details\":\"uwu *nuzzles ur gurls*\",\"id\":\"a8e0c6396f77a666\",\"name\":\"holidaygir1225\",\"platform\":\"desktop\",\"session_id\":\"860a5ca58c9f8ea99659db4505b80874\",\"state\":\"holidaygir1225\",\"status_display_type\":1,\"timestamps\":{\"end\":1787591911959,\"start\":1787591737959},\"type\":2}],\"discord_status\":\"online\",\"active_on_discord_web\":false,\"active_on_discord_desktop\":true,\"active_on_discord_mobile\":false,\"listening_to_spotify\":false,\"spotify\":null},\"t\":\"PRESENCE_UPDATE\"}"
    |> decode
    == Ok(
      presence.PresenceReceived(presence.Known(
        status: presence.Online,
        listening: presence.Track(
          title: "uwu *nuzzles ur gurls*",
          artist: "holidaygir1225",
          artwork: Some(
            "https://i1.sndcdn.com/artworks-5kQuiFyjxgG82DZw-Vr8Mtw-t500x500.jpg",
          ),
          timing: presence.Timed(
            start_milliseconds: 1_787_591_737_959,
            end_milliseconds: 1_787_591_911_959,
          ),
        ),
      )),
    )
}

pub fn spotify_is_not_mistaken_for_soundcloud_test() -> Nil {
  assert "{\"op\": 0, \"t\": \"PRESENCE_UPDATE\", \"d\": {\"discord_status\": \"online\", \"activities\": [{\"type\": 2, \"application_id\": \"802958789555781663\", \"name\": \"Spotify\", \"details\": \"Let Go\", \"state\": \"Ark Patrol\"}]}}"
    |> decode
    == Ok(
      presence.PresenceReceived(presence.Known(
        status: presence.Online,
        listening: presence.Nothing,
      )),
    )
}

pub fn a_non_listening_activity_is_not_a_track_test() -> Nil {
  assert "{\"op\": 0, \"t\": \"PRESENCE_UPDATE\", \"d\": {\"discord_status\": \"idle\", \"activities\": [{\"type\": 0, \"name\": \"Visual Studio Code\", \"details\": \"editing\"}]}}"
    |> decode
    == Ok(
      presence.PresenceReceived(presence.Known(
        status: presence.Idle,
        listening: presence.Nothing,
      )),
    )
}

pub fn a_track_without_timestamps_still_shows_test() -> Nil {
  assert "{\"op\": 0, \"t\": \"PRESENCE_UPDATE\", \"d\": {\"discord_status\": \"online\", \"activities\": [{\"type\": 2, \"application_id\": \"1090770350251458592\", \"name\": \"holidaygir1225\", \"details\": \"Untitled\"}]}}"
    |> decode
    == Ok(
      presence.PresenceReceived(presence.Known(
        status: presence.Online,
        listening: presence.Track(
          title: "Untitled",
          artist: "holidaygir1225",
          artwork: None,
          timing: presence.Untimed,
        ),
      )),
    )
}

pub fn an_unknown_status_falls_back_to_offline_test() -> Nil {
  assert "{\"op\": 0, \"t\": \"PRESENCE_UPDATE\", \"d\": {\"discord_status\": \"streaming\", \"activities\": []}}"
    |> decode
    == Ok(
      presence.PresenceReceived(presence.Known(
        status: presence.Offline,
        listening: presence.Nothing,
      )),
    )
}

pub fn frames_we_do_not_care_about_are_ignored_test() -> Nil {
  assert "{\"op\":4,\"d\":{}}"
    |> decode
    == Ok(presence.Ignored)
}
