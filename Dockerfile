# The builder's Elixir and OTP are pinned to the versions the game is developed and tested against.
FROM hexpm/elixir:1.19.6-erlang-28.5.0.6-alpine-3.22.5 AS builder

RUN apk add --no-cache build-base git
WORKDIR /app

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

# The build context carries no .git, so the sha cannot be discovered here — pass it in, or the
# image reports itself as a debug build and keeps showing error detail to players.
ARG APP_VERSION
ENV APP_VERSION=$APP_VERSION

# `mix assets.deploy` minifies and digests; config/runtime.exs is read at boot, not here, so the
# build needs no database and no secret.
RUN mix assets.deploy && mix compile && mix release

# --- runtime ---
FROM alpine:3.22.5 AS runner

RUN apk add --no-cache libstdc++ openssl ncurses-libs libgcc
WORKDIR /app

# The release brings its own ERTS; nothing here needs Elixir or Mix.
COPY --from=builder /app/_build/prod/rel/mini_lineage ./

ENV PHX_SERVER=true
EXPOSE 4000

RUN addgroup -S app && adduser -S -G app app && chown -R app:app /app
USER app

# Migrations run in the same container that serves, so a fresh database is never served against.
CMD ["sh", "-c", "bin/mini_lineage eval 'MiniLineage.Release.migrate()' && exec bin/mini_lineage start"]
