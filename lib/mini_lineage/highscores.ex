defmodule MiniLineage.Highscores do
  @moduledoc "The public leaderboard. Relational, because it is genuinely queried by column."
  import Ecto.Query

  alias MiniLineage.Game.Constants
  alias MiniLineage.Repo

  defmodule Entry do
    @moduledoc false
    use Ecto.Schema

    schema "highscores" do
      field :name, :string
      field :total_xp, :integer
      field :race_id, :integer
      field :adena, :integer
      field :level, :integer
      field :created, :naive_datetime
    end
  end

  def insert(%{name: name, experience: experience, race_id: race_id, adena: adena, level: level}) do
    Repo.insert!(%Entry{
      name: name,
      total_xp: experience,
      race_id: race_id,
      adena: adena,
      level: level,
      created: NaiveDateTime.utc_now(:second)
    })

    :ok
  end

  @doc "Top entries by experience then adena, optionally filtered to one race."
  def list(race_id \\ nil) do
    Entry
    |> then(&if race_id, do: where(&1, [e], e.race_id == ^race_id), else: &1)
    |> order_by([e], desc: e.total_xp, desc: e.adena)
    |> limit(^Constants.highscores_limit())
    |> Repo.all()
  end
end
