# Pinned to what CI tests on; CI fails if the two drift.
FROM hexpm/elixir:1.20.4-erlang-29.1.1-alpine-3.24.2 AS builder

# Nothing to apk add: every production dependency is pure Elixir or Erlang.
WORKDIR /app

# Without it the VM runs latin1, and this game is made of emoji.
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

# The commit the footer names; there is no .git in the context. After the dependency layers so a
# new commit does not rebuild them. The ENV is not redundant: BuildKit keys a layer on an ARG only
# when the command mentions it.
ARG APP_VERSION
ENV APP_VERSION=${APP_VERSION}

# runtime.exs is read at boot, so the build needs no database and no secret.
RUN mix assets.deploy && mix release

# --- runtime ---
FROM alpine:3.24.2 AS runner

# What the ERTS links against, and ca-certificates for a database reached over TLS.
RUN apk add --no-cache libstdc++ openssl ncurses-libs libgcc ca-certificates
WORKDIR /app

ENV LANG=C.UTF-8

# Links the ghcr package to this repository.
LABEL org.opencontainers.image.source="https://github.com/sunny-azu-red/mini-lineage-remastered"
LABEL org.opencontainers.image.description="Mini-Lineage Remastered — a text-based RPG in Elixir and Phoenix LiveView"
LABEL org.opencontainers.image.licenses="MIT"

# Before the copy, so --chown sets ownership as files land; a `chown -R` after would duplicate the
# release into a layer of its own. /app itself is chowned for the release's runtime config.
RUN addgroup -S app && adduser -S -G app app && chown app:app /app

# The release brings its own ERTS; nothing here needs Elixir or Mix.
COPY --from=builder --chown=app:app /app/_build/prod/rel/mini_lineage ./

ENV PHX_SERVER=true

USER app

# Migrations run in the same container that serves, so a fresh database is never served against.
CMD ["sh", "-c", "bin/mini_lineage eval 'MiniLineage.Release.migrate()' && exec bin/mini_lineage start"]
