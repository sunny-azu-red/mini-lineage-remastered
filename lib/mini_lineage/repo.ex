defmodule MiniLineage.Repo do
  use Ecto.Repo,
    otp_app: :mini_lineage,
    adapter: Ecto.Adapters.MyXQL
end
