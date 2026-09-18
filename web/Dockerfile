FROM ghcr.io/gleam-lang/gleam:v1.18.0-erlang-alpine AS build
RUN apk add --no-cache git make libstdc++ libgcc
WORKDIR /build
COPY Makefile ./
COPY web ./web
RUN make client

FROM caddy:2-alpine
COPY web/Caddyfile /etc/caddy/Caddyfile
COPY --from=build /build/web/dist /srv
