FROM ghcr.io/gleam-lang/gleam:v1.18.0-erlang-alpine AS build
RUN apk add --no-cache git
WORKDIR /build
COPY api ./
RUN gleam export erlang-shipment

FROM erlang:29-alpine
COPY --from=build /build/build/erlang-shipment /app
ENTRYPOINT ["/bin/sh", "/app/entrypoint.sh"]
CMD ["run"]
