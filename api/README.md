# api

The api server. It serves `/health` and `/api/activity` and also serves the
built portfolio when `MODE=dev`.

```sh
MODE=dev gleam run
```

| Variable           | Default       | Purpose                                     |
| ------------------ | ------------- | ------------------------------------------- |
| `MODE`             | production    | Set to `dev` to serve static files locally. |
| `PORT`             | `8080`        | HTTP listener port.                         |
| `STATIC_DIRECTORY` | `../web/dist` | Development site output.                    |
| `GITHUB_LOGIN`     | unset         | Account whose contributions are fetched.    |
| `GITHUB_TOKEN`     | unset         | GitHub API token.                           |

The activity worker starts only when both GitHub credentials are present and not
empty. It caches the calendar and refreshes daily, retrying failed refreshes
after fifteen minutes. Until a calendar is available, `/api/activity` returns
503.

```sh
gleam format --check src test
gleam check
```
