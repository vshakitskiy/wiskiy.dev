import lustre/attribute as attr
import lustre/element.{type Element}
import lustre/element/html
import web/islands/guestbook
import web/layout.{Island}

// TODO: any webrings??? 

pub fn home() -> Element(Nil) {
  layout.page(
    title: "Home",
    description: "software engineer & gleam enthusiast",
    islands: [],
    body: [
      html.section([], [
        // TODO: discord presence circle color status with lanyard 
        // TODO: show soundcloud track from discord presence on top
        html.h1([], [html.text("wiskiy")]),
        html.p([], [html.text("software engineer & gleam enthusiast")]),
        html.ul([], [
          // TODO: github, tangled, discord, telegram as api redirects..?
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

pub fn work() -> Element(Nil) {
  layout.page(
    title: "Work",
    description: "Things I've built.",
    islands: [],
    body: [html.h1([], [html.text("Work")])],
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
      html.section([attr.id(guestbook.mount_id)], [
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
