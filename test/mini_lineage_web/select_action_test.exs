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

  defp grouped(assigns) do
    ~H"""
    <.select_action
      id="f"
      event="go"
      name="item"
      picked={@picked}
      placeholder="Back"
      options={[
        %{value: "use:a", label: "A", group: "Use", action: "Use"},
        %{value: "use:b", label: "B", group: "Use", action: "Use"},
        %{value: "drop:a", label: "A", group: "Drop", action: "Drop", variant: :danger}
      ]}
      default_label="Return"
    />
    """
  end

  test "neighbours sharing a group share an optgroup, and exactly one option is selected" do
    html = rendered_to_string(grouped(%{picked: "use:b"}))
    tree = LazyHTML.from_fragment(html)

    assert tree |> LazyHTML.query(~s(optgroup[label="Use"] option)) |> Enum.count() == 2
    assert tree |> LazyHTML.query(~s(optgroup[label="Drop"] option)) |> Enum.count() == 1
    assert tree |> LazyHTML.query("option[selected]") |> LazyHTML.attribute("value") == ["use:b"]
  end

  test "the picked option's action and variant are the button's" do
    button = &(grouped(%{picked: &1}) |> rendered_to_string() |> LazyHTML.from_fragment())

    assert button.(nil) |> LazyHTML.query("button.btn-secondary") |> LazyHTML.text() =~ "Return"
    assert button.("use:a") |> LazyHTML.query("button") |> LazyHTML.text() =~ "Use"
    refute button.("use:a") |> LazyHTML.query("button.btn-danger") |> Enum.any?()
    assert button.("drop:a") |> LazyHTML.query("button.btn-danger") |> LazyHTML.text() =~ "Drop"
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
