import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import web/islands/guestbook
import web/islands/presence
import web/layout.{Island}

// TODO: any webrings??? 

pub fn home() -> Element(Nil) {
  let #(presence_model, _effect) = presence.init(Nil)

  layout.page(
    title: "Home",
    description: "software engineer & gleam enthusiast",
    islands: [Island("presence")],
    body: [
      html.section([], [
        html.div([attribute.id(presence.mount_id)], [
          presence.view(presence_model)
          |> layout.strip_message,
        ]),
        html.p([], [html.text("software engineer & gleam enthusiast")]),
        html.ul([], [
          // TODO: github, tangled, discord and telegram links
        ]),
      ]),
      html.section([], [
        html.p([], [
          html.text(
            "I am `calculated` years old living in Russia `icon` working on system designs mostly as a developer for the developers and other software using Gleam.",
          ),
        ]),
      ]),
      html.section([], [
        html.h2([], [html.text("Featuring")]),
        // TODO: git activity here..? or maybe on more well designed place, but 
        // I dun want this to be a separate section.
        html.p([], [
          html.text("Things I've worked on that deserves some acknowledgement!"),
        ]),
        html.ul([], [
          // TODO: featured work, on hover show some image preview..?
        ]),
      ]),
      html.section([], [
        html.h2([], [html.text("Writing")]),
        html.ul([], [
          // TODO: list current writing list
        ]),
      ]),
    ],
  )
}

pub fn guestbook() -> Element(Nil) {
  let #(model, _effect) = guestbook.init(Nil)

  layout.page(
    title: "Guestbook",
    description: "Leave a message.",
    islands: [Island("guestbook")],
    body: [
      html.h1([], [html.text("Guestbook")]),
      html.section([attribute.id(guestbook.mount_id)], [
        guestbook.view(model)
        |> layout.strip_message,
      ]),
    ],
  )
}

pub fn not_found() -> Element(Nil) {
  layout.page(
    title: "Not found",
    description: "There's nothing here.",
    islands: [],
    body: [html.h1([], [html.text("404")])],
  )
}
