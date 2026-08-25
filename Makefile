.PHONY: client client-ssg client-islands api dev

ISLANDS := web/islands/guestbook web/islands/presence web/islands/activity

client: client-ssg client-islands

client-ssg:
	cd web && gleam run -m build

client-islands:
	cd web && gleam run -m lustre/dev build --minify --no-html \
		--outdir=dist/js $(ISLANDS)

api:
	cd api && gleam run

dev:
	watchexec -w web/src -w web/priv -- $(MAKE) client & \
	watchexec -r -w api/src -- $(MAKE) api & \
	wait
