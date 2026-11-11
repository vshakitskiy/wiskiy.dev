@external(javascript, "./browser_ffi.mjs", "after")
pub fn after(milliseconds _milliseconds: Int, run _run: fn() -> Nil) -> Nil {
  Nil
}

/// Defers callbacks while the page is hidden.
@external(javascript, "./browser_ffi.mjs", "after_visible")
pub fn after_visible(
  milliseconds _milliseconds: Int,
  run _run: fn() -> Nil,
) -> Nil {
  Nil
}

/// No-op if the element is missing.
@external(javascript, "./browser_ffi.mjs", "focus")
pub fn focus(id _id: String) -> Nil {
  Nil
}
