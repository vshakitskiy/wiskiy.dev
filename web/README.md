# web

The static portfolio and its interactive Lustre islands.

Run `make client` from the repository root or `gleam run -m web/build` in this
folder to build the complete site into `dist/`.

## Articles

Add Markdown files under `writing/` with TOML frontmatter:

```toml
title = "An article"
date = "2026-11-10"
description = "A short summary."
public = true
tags = ["gleam"]
# Optional Gleam entry modules:
islands = ["web/island/demo"]
```

Public articles are sorted newest first. Dates must be valid `YYYY-MM-DD` values
and public article slugs must be unique. Project records live in
`src/web/island/work.gleam`. The preview script reads their JSON export from
`gleam run -m web/preview`.

```sh
gleam format --check src dev test
gleam check
```
