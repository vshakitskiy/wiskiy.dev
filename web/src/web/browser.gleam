//// Browser capabilities the islands share.

/// Runs callback function once after some time.
@external(javascript, "./browser_ffi.mjs", "after")
pub fn after(milliseconds _milliseconds: Int, run _run: fn() -> Nil) -> Nil {
  Nil
}
