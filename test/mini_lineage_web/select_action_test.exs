defmodule MiniLineageWeb.SelectActionTest do
  @moduledoc """
  Every dropdown is `select_action`, whose field never shadows a property of its form, which would
  make the patch move the form on every render and shut an open list. The walkthrough holds each one
  open across a regen tick.
  """
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import MiniLineageWeb.Controls

  defp choice(assigns) do
    ~H"""
    <.select_action
      id="f"
      event="go"
      name={@name}
      options={[%{value: "a", label: "A"}]}
      default_label="Go"
      active_label="Go"
    />
    """
  end

  test "a field named after a form property is refused" do
    for name <- ~w(id name action) do
      assert_raise ArgumentError, fn -> rendered_to_string(choice(%{name: name})) end
    end
  end

  test "any other name renders" do
    assert rendered_to_string(choice(%{name: "item"})) =~ ~s(name="item")
  end

  # Character creation is three fields one Start button sends together, not a choice and its action,
  # and `phx-update="ignore"` keeps every patch off them.
  test "no select is written by hand but character creation's" do
    hand_written =
      for path <- Path.wildcard("lib/mini_lineage_web/**/*.{ex,heex}"),
          path != "lib/mini_lineage_web/components/controls.ex",
          [_, name] <- Regex.scan(~r/<select\b[^>]*\bname="([^"]+)"/, File.read!(path)),
          do: name

    assert Enum.sort(hand_written) == ["path", "race_id"]
  end
end
