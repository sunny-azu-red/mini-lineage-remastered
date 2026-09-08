# `mix test` picks :test on its own, so arriving here in another environment means MIX_ENV is
# exported in the shell. Without this the first sandbox call fails complaining about the pool,
# which says nothing about why.
if Mix.env() != :test do
  Mix.raise("""
  mix test must run in MIX_ENV=test, but this is #{Mix.env()}.

  MIX_ENV is exported in your shell. Run `unset MIX_ENV`, or open a new terminal.
  """)
end

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MiniLineage.Repo, :manual)
