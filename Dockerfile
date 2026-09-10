# The builder's Elixir and OTP are pinned to the versions the game is developed and tested against.
FROM hexpm/elixir:1.19.6-erlang-28.5.0.6-alpine-3.22.5 AS builder

RUN apk add --no-cache build-base git
WORKDIR /app

# Without a UTF-8 locale the VM runs with latin1 name encoding and warns that Elixir "may
# malfunction". This game is made of emoji; it needs the real thing.
ENV LANG=C.UTF-8
ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

# Dependencies first, so editing game code does not re-fetch or recompile them.
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
COPY config config
RUN mix deps.compile

COPY assets assets
COPY priv priv
COPY lib lib

# Names the commit in the footer. CI passes it; config/prod.exs reads it. Not read from a .git —
# a deploy has none.
#
# Declared here, after the dependency layers, so a new commit does not rebuild them. The ENV is
# not redundant: BuildKit keys a layer on an ARG only when the command mentions it, and mix reads
# this from the environment instead — so without it the release below could be served from cache
# and carry the previous build's commit.
ARG APP_VERSION
ENV APP_VERSION=${APP_VERSION}

# `mix assets.deploy` compiles, minifies and digests; config/runtime.exs is read at boot, not
# here, so the build needs no database and no secret.
RUN mix assets.deploy && mix release

# --- runtime ---
FROM alpine:3.22.5 AS runner

# ca-certificates so the database can be reached over TLS; the rest is what the ERTS links against.
RUN apk add --no-cache libstdc++ openssl ncurses-libs libgcc ca-certificates
WORKDIR /app

ENV LANG=C.UTF-8

# Links the package to this repository on GitHub, which gives it the README and makes where an
# image came from answerable from the image itself.
LABEL org.opencontainers.image.source="https://github.com/sunny-azu-red/mini-lineage-remastered"
LABEL org.opencontainers.image.description="Mini-Lineage Remastered — a text-based RPG in Elixir and Phoenix LiveView"
LABEL org.opencontainers.image.licenses="MIT"

# The release brings its own ERTS; nothing here needs Elixir or Mix.
COPY --from=builder /app/_build/prod/rel/mini_lineage ./

ENV PHX_SERVER=true

RUN addgroup -S app && adduser -S -G app app && chown -R app:app /app
USER app

# Migrations run in the same container that serves, so a fresh database is never served against.
CMD ["sh", "-c", "bin/mini_lineage eval 'MiniLineage.Release.migrate()' && exec bin/mini_lineage start"]
