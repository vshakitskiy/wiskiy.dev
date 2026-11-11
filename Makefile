.PHONY: client api dev previews

client:
	cd web && gleam run -m web/build

api:
	cd api && gleam run

dev:
	watchexec -w web/src -w web/dev -w web/priv -w web/writing -w web/gleam.toml -- $(MAKE) client & \
	watchexec -r -w api/src -- $(MAKE) api & \
	wait

previews:
	deno task previews $(FORCE)
