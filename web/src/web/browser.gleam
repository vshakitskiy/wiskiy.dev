//// Browser helpers shared by the islands.

/// Runs `run` once, after `milliseconds` have passed.
@external(javascript, "./browser_ffi.mjs", "after")
pub fn after(milliseconds _milliseconds: Int, run _run: fn() -> Nil) -> Nil {
  Nil
}
