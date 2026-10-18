defmodule MiniLineage.ServerRatesTest do
  @moduledoc """
  Rules §22's rates as a server sets them: `runtime.exs` reads `EXP_RATE`, `SP_RATE` and
  `ADENA_RATE` in every environment, and `Rules.rate/1` answers with whatever is configured.
  """
  # Sets OS variables and the application's environment.
  use ExUnit.Case, async: false

  alias MiniLineage.Game.Rules

  @names ~w(EXP_RATE SP_RATE ADENA_RATE)
  # What :prod refuses to boot without, beside the rates.
  @prod ~w(PHX_HOST SECRET_KEY_BASE DB_DATABASE)

  setup do
    saved = Map.new(@names ++ @prod ++ ["ENV_FILE"], &{&1, System.get_env(&1)})
    rates = Application.fetch_env!(:mini_lineage, :rates)
    # A file that isn't there, so the runtime config reads no real .env into the environment.
    System.put_env(
      "ENV_FILE",
      Path.join(System.tmp_dir!(), "no-such-env-#{System.unique_integer()}")
    )

    Enum.each(@names, &System.delete_env/1)
    Enum.each(@prod, &System.put_env(&1, "x"))

    on_exit(fn ->
      Application.put_env(:mini_lineage, :rates, rates)

      for {name, value} <- saved do
        if value, do: System.put_env(name, value), else: System.delete_env(name)
      end
    end)
  end

  defp runtime_rates(env) do
    "config/runtime.exs" |> Config.Reader.read!(env: env) |> get_in([:mini_lineage, :rates])
  end

  test "a server takes the rates its environment names and leaves the others at retail's" do
    System.put_env("EXP_RATE", "10")
    System.put_env("SP_RATE", "")
    assert runtime_rates(:dev) == [exp: 10]
    assert runtime_rates(:prod) == [exp: 10]
  end

  test "and sets none when it names none" do
    assert runtime_rates(:dev) == nil
  end

  test "and so do the suites and the bench, from .env.test" do
    System.put_env("ADENA_RATE", "20")
    assert runtime_rates(:test) == [adena: 20]
    assert runtime_rates(:e2e) == [adena: 20]
  end

  test "a rate that is not a whole number above 0 stops the boot" do
    for bad <- ["0", "-2", "1.5", "five"] do
      System.put_env("ADENA_RATE", bad)

      assert_raise RuntimeError, ~r/ADENA_RATE is "#{Regex.escape(bad)}"/, fn ->
        runtime_rates(:prod)
      end
    end
  end

  test "the game pays at the configured rate" do
    Application.put_env(:mini_lineage, :rates, exp: 10, sp: 1, adena: 3)
    assert Enum.map([:exp, :sp, :adena], &Rules.rate/1) == [10, 1, 3]
  end
end
