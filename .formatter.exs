[
  import_deps: [:ecto, :ecto_sql, :phoenix],
  # StreamData's own list, spelled out: it is a :test dependency, and import_deps fails in :dev.
  locals_without_parens: [all: :*, check: 1, check: 2, property: 1, property: 2],
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: [
    "*.{heex,ex,exs}",
    "{bench,config,lib,scratch,test}/**/*.{heex,ex,exs}",
    "priv/*/seeds.exs"
  ]
]
