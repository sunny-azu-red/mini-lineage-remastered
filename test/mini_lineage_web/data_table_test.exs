defmodule MiniLineageWeb.DataTableTest do
  @moduledoc """
  A table's sort is the server's: a header cycles it up, down and off, the rows arrive in its
  order, and only a table that remembers carries the hook keeping it, read back against its keys.
  """
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import MiniLineageWeb.Controls

  defp table(assigns) do
    ~H"""
    <.data_table id="t" sort={@sort} remember={@remember}>
      <:col class="name" sort="name">Name</:col>
      <:col>Plain</:col>
      <tbody></tbody>
    </.data_table>
    """
  end

  defp doc(sort, remember),
    do: LazyHTML.from_fragment(rendered_to_string(table(%{sort: sort, remember: remember})))

  defp read(doc, selector, name), do: doc |> LazyHTML.query(selector) |> LazyHTML.attribute(name)

  test "a sorted column says which way, and a column without a key is only a label" do
    doc = doc({"name", :desc}, false)

    assert read(doc, "th", "aria-sort") == ["descending"]
    assert read(doc, "th button.sort", "phx-value-key") == ["name"]
    assert read(doc, "th button.sort", "phx-value-table") == ["t"]
    assert doc |> LazyHTML.query("th:nth-child(2) button") |> Enum.count() == 0
  end

  test "only a table that remembers carries the hook, with its sort, empty when it has none" do
    assert read(doc({"name", :asc}, true), "thead", "phx-hook") == ["Table"]
    assert read(doc({"name", :asc}, true), "thead", "data-table") == ["t"]
    assert read(doc({"name", :asc}, true), "thead", "data-sort") == ["name:asc"]
    assert read(doc(nil, true), "thead", "data-sort") == [""]

    assert read(doc({"name", :asc}, false), "thead", "phx-hook") == []
    assert read(doc({"name", :asc}, false), "thead", "data-sort") == []
  end

  test "a header goes up, then down, then back to the order the rows arrived in" do
    assert next_sort(nil, "sp") == {"sp", :asc}
    assert next_sort({"sp", :asc}, "sp") == {"sp", :desc}
    assert next_sort({"sp", :desc}, "sp") == nil
    assert next_sort({"skill", :desc}, "sp") == {"sp", :asc}
  end

  test "rows keep their order where the column ties" do
    rows = [%{n: 2, id: :a}, %{n: 1, id: :b}, %{n: 2, id: :c}]
    key = fn row, "n" -> row.n end

    assert Enum.map(sort_rows(rows, {"n", :asc}, key), & &1.id) == [:b, :a, :c]
    assert Enum.map(sort_rows(rows, {"n", :desc}, key), & &1.id) == [:a, :c, :b]
    assert sort_rows(rows, nil, key) == rows
  end

  test "a kept sort is read back only as one of the table's own keys and directions" do
    assert decode_sort("sp:desc", ~w(skill sp)) == {"sp", :desc}
    assert decode_sort("level:asc", ~w(skill sp)) == nil
    assert decode_sort("sp:sideways", ~w(skill sp)) == nil
    assert decode_sort("sp", ~w(skill sp)) == nil
    assert decode_sort(%{"sp" => "asc"}, ~w(skill sp)) == nil
  end
end
