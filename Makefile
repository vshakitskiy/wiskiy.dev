.PHONY: client client-ssg client-islands client-watch serve dev

ISLANDS := web/islands/guestbook

client: client-ssg client-islands

client-ssg:
	cd web && gleam run -m build

client-islands:
	cd web && gleam run -m lustre/dev build --minify --no-html \
		--outdir=dist/js $(ISLANDS)

client-watch:
	@echo "Watching web/{src,priv,writing} for changes..."
	@while true; do \
		inotifywait -qr -e modify,create,delete,move \
			web/src web/priv web/writing 2>/dev/null; \
		echo "Change detected, rebuilding..."; \
		$(MAKE) client; \
	done

serve:
	deno run --allow-net --allow-read scripts/http_server_files.ts

dev:
	@$(MAKE) client
	@$(MAKE) serve & $(MAKE) client-watch
