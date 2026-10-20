defmodule MiniLineageWeb.Kept do
  @moduledoc """
  What the reader chose about how the game looks (a panel's fold, a table's sort, the sound),
  kept by the browser in a cookie of its own and read here, so the first draw is already the
  reader's and nothing moves once the page connects. It is not the session: the browser writes it,
  so it is unsigned, and it is read as anything a reader typed is, an unexpected entry meaning
  nothing kept.

  The value is a query string of `<kind>:<id>=<value>`, as `hooks/kept.js` writes it.
  """

  alias MiniLineageWeb.{Controls, Screens}

  @cookie "_mini_lineage_kept"
  @id ~r/\A[a-z][a-z0-9-]{0,39}\z/
  # Far more panels than the game folds, so an id a client makes up cannot grow the map for ever.
  @most_folds 32

  @doc "The cookie's name, which `hooks/kept.js` writes too."
  def cookie, do: @cookie

  @doc "The `live_session` session: the cookie as the request carried it, read in `mount/3`."
  def session(conn), do: %{"kept" => conn.req_cookies[@cookie]}

  @doc "Every choice the cookie holds that the game can draw; anything else is dropped."
  def read(raw) do
    entries = decode(raw)

    %{
      folds:
        for(
          {"panel:" <> id, value} <- entries,
          panel?(id) and value in ["0", "1"],
          do: {id, value == "1"}
        )
        |> Enum.take(@most_folds)
        |> Map.new(),
      sorts:
        for(
          {"table:" <> table, value} <- entries,
          %{remember: true, keys: keys} <- [Screens.sortable(table)],
          sort = Controls.decode_sort(value, keys),
          sort != nil,
          into: %{},
          do: {table, sort}
        ),
      sound: entries["sound:effects"] != "0"
    }
  end

  @doc "The folds once the reader has folded or opened `id`: unchanged for an id no panel could have."
  def fold(folds, id, open) do
    if panel?(id) and (Map.has_key?(folds, id) or map_size(folds) < @most_folds),
      do: Map.put(folds, id, open),
      else: folds
  end

  defp panel?(id), do: is_binary(id) and Regex.match?(@id, id)

  defp decode(raw) when is_binary(raw) do
    URI.decode_query(raw)
  rescue
    # A percent sign without its two hex digits: an edited cookie, never one `kept.js` wrote.
    ArgumentError -> %{}
  end

  defp decode(_raw), do: %{}
end
