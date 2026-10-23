defmodule MiniLineage.Characters.ItemsStoreTest do
  @moduledoc """
  Rules §23's inventory where it is kept: its own table, written in the same transaction as the
  character whenever the items moved, and read back in the order they were picked up.
  """
  use MiniLineage.DataCase, async: false

  alias MiniLineage.Characters
  alias MiniLineage.Characters.{Item, Store}
  alias MiniLineage.Game.Actions

  setup do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    Characters.mutate(session, &Actions.start(&1, 0, "fighter", "Packer"))
    %{session: session, id: Characters.character_id(session)}
  end

  defp item(name, equipped \\ false, count \\ 1),
    do: %{id: Store.new_item_id(), name: name, equipped: equipped, count: count}

  defp carry(session, items),
    do: Characters.mutate(session, &{%{&1 | items: items}, :ok})

  defp rows(id),
    do: Repo.all(from i in Item, where: i.character_id == ^id, select: {i.name, i.equipped})

  test "items are written the moment they change, and come back in order after a restart", %{
    session: session,
    id: id
  } do
    sword = item("Broadsword", true)
    shirt = item("Wooden Breastplate")
    carry(session, [sword, shirt])

    assert Enum.sort(rows(id)) == [{"Broadsword", true}, {"Wooden Breastplate", false}]

    Characters.forget_process(session)
    assert Characters.snapshot(session).items == [sword, shirt]
  end

  test "a stack keeps its count in its row, and a change to it is written", %{session: session} do
    potions = item("Lesser Healing Potion", false, 12)
    carry(session, [potions])
    carry(session, [%{potions | count: 11}])

    Characters.forget_process(session)
    assert Characters.snapshot(session).items == [%{potions | count: 11}]
  end

  test "an equip changes the row, and an item let go of is gone", %{session: session, id: id} do
    sword = item("Broadsword")
    shirt = item("Wooden Breastplate")
    carry(session, [sword, shirt])
    carry(session, [%{sword | equipped: true}])

    assert rows(id) == [{"Broadsword", true}]
  end

  test "a save that moved no item writes none", %{session: session, id: id} do
    carry(session, [item("Broadsword")])
    # Marked behind the process's back, where a needless rewrite would put it back.
    Repo.update_all(from(i in Item, where: i.character_id == ^id), set: [equipped: true])

    Characters.mutate(session, &{%{&1 | adena: 1}, :ok})

    assert rows(id) == [{"Broadsword", true}]
  end
end
