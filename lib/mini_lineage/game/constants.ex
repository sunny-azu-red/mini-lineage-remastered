defmodule MiniLineage.Game.Constants do
  @moduledoc "Every tuning knob. Rebalance here, never in the game modules."

  @max_level 80

  @races [
    %{
      id: 0,
      label: "Human",
      plural: "Humans",
      emoji: "🧙",
      enemy_race_id: 1,
      start_adena: 300,
      ambush_chance: 8,
      backstory:
        "The most adaptable of all lineages. A Human Fighter is strong and hardy without leaning too far either way, and a Human Mystic pairs a sharp mind with a steady spirit. They start with a modest inheritance and keep a vigilant eye on the road."
    },
    %{
      id: 1,
      label: "Orc",
      plural: "Orcs",
      emoji: "🧟",
      enemy_race_id: 0,
      start_adena: 250,
      ambush_chance: 16,
      backstory:
        "Towering warriors of immense physical resilience. No Fighter is born with a hardier constitution than an Orc's, nor any Mystic with a stronger spirit, so their wounds close faster than anyone's. Their hands are the clumsiest of the four, and their massive presence makes them easy targets for ambushes."
    },
    %{
      id: 2,
      label: "Elf",
      plural: "Elves",
      emoji: "🧝",
      enemy_race_id: 3,
      start_adena: 450,
      ambush_chance: 4,
      backstory:
        "Swift, wealthy, and favored by nature. An Elven Fighter is the most dexterous of all, striking true and often, and an Elven Mystic thinks faster on their feet than any other. Their frames are the most fragile of the races, but they are hard to surprise and start with significant gold."
    },
    %{
      id: 3,
      label: "Dark Elf",
      plural: "Dark Elves",
      emoji: "🧛",
      enemy_race_id: 2,
      start_adena: 350,
      ambush_chance: 5,
      backstory:
        "Lethal stalkers of the night. A Dark Fighter hits harder than any other, and a Dark Mystic's intellect has no equal, which makes their magic the most dangerous in the realm. Both pay for it with the frailest constitutions of all, and they keep their wits about them on the road."
    }
  ]

  @effects %{
    resting_aura: %{id: "resting", type: :aura, emoji: "💤", label: "Resting", modifiers: []},
    combat_aura: %{id: "combat", type: :aura, emoji: "⚔️", label: "In Combat", modifiers: []},
    # modifiers filled in at runtime with the total regen rate
    regen_aura: %{
      id: "regenerating",
      type: :aura,
      emoji: "🌿",
      label: "Regenerating",
      modifiers: []
    },
    # What is left of a run. Derived rather than applied: `kill/1` clears every effect a character
    # had, so this is not something they carry but something they have become.
    ghost_aura: %{id: "ghost", type: :aura, emoji: "👻", label: "Ghost", modifiers: []},
    newbie_buff: %{
      id: "newbie_blessing",
      type: :buff,
      emoji: "🐣",
      label: "Newbie Blessing",
      duration_ms: 300_000,
      modifiers: [
        %{type: :max_hp, value: 20},
        %{type: :p_def, value: 2},
        %{type: :ambush_risk, value: -4}
      ]
    },
    ambush_debuff: %{
      id: "hexed",
      type: :debuff,
      emoji: "👁️",
      label: "Hexed",
      duration_ms: 60_000,
      modifiers: [%{type: :ambush_risk, value: 4}, %{type: :crit_rate, value: -20}]
    },
    konami_cheat: %{
      id: "konami_cheat",
      type: :debuff,
      emoji: "👾",
      label: "Cheater's Mark",
      modifiers: [
        %{type: :xp_multiplier, op: :mul, value: 4},
        %{type: :adena_multiplier, op: :mul, value: 4},
        %{type: :crit_rate, value: 150},
        %{type: :max_hp, value: 150}
      ]
    },
    smoked_sausage: %{
      id: "satisfied",
      type: :buff,
      group: "food",
      emoji: "🥓",
      label: "Satisfied",
      duration_ms: 90_000,
      modifiers: [%{type: :max_hp, value: 10}]
    },
    hearty_mash: %{
      id: "well_fed",
      type: :buff,
      group: "food",
      emoji: "🍖",
      label: "Well Fed",
      duration_ms: 150_000,
      modifiers: [%{type: :max_hp, value: 30}]
    },
    roasted_pheasant: %{
      id: "gourmet_feast",
      type: :buff,
      group: "food",
      emoji: "👑",
      label: "Gourmet Feast",
      duration_ms: 300_000,
      modifiers: [%{type: :max_hp, value: 60}]
    }
  }

  # Combat math scales purely off the equipped item's `stat`, so items can be appended freely.
  @armors [
    %{id: 0, name: "Peasant's Tunic", emoji: "🧥", stat: 2, cost: 0},
    %{id: 1, name: "Brigandine Leathers", emoji: "🥋", stat: 10, cost: 500},
    %{id: 2, name: "Spirit of the Forest", emoji: "🪵", stat: 22, cost: 8_000},
    %{
      id: 3,
      name: "Knight's Plate",
      emoji: "🛡️",
      stat: 41,
      cost: 30_000,
      modifiers: [%{type: :hp_regen, value: 1}]
    },
    %{
      id: 4,
      name: "Royal Chainmail",
      emoji: "⛓️",
      stat: 64,
      cost: 200_000,
      modifiers: [%{type: :hp_regen, value: 2}]
    },
    %{
      id: 5,
      name: "Eternal Aegis",
      emoji: "💎",
      stat: 88,
      cost: 650_000,
      modifiers: [%{type: :hp_regen, value: 3}]
    }
  ]

  @weapons [
    %{id: 0, name: "Brawler's Fists", emoji: "👊", stat: 7, cost: 0},
    %{id: 1, name: "Elven Needle", emoji: "🗡️", stat: 16, cost: 300},
    %{id: 2, name: "Stormbringer", emoji: "⚡", stat: 28, cost: 5_000},
    %{
      id: 3,
      name: "Echos of Valhalla",
      emoji: "⚔️",
      stat: 45,
      cost: 18_000,
      modifiers: [%{type: :crit_rate, value: 30}]
    },
    %{
      id: 4,
      name: "Calamity Comet",
      emoji: "☄️",
      stat: 62,
      cost: 250_000,
      modifiers: [%{type: :crit_rate, value: 70}]
    },
    %{
      id: 5,
      name: "The Forgotten Blade",
      emoji: "💀",
      stat: 90,
      cost: 900_000,
      modifiers: [%{type: :crit_rate, value: 150}]
    }
  ]

  @foods [
    %{id: 0, name: "Spiced Ale", emoji: "🍺", stat: 4, cost: 7},
    %{id: 1, name: "Forest Apple", emoji: "🍎", stat: 6, cost: 15},
    %{id: 2, name: "Smoked Sausage", emoji: "🌭", stat: 15, cost: 60, effect: :smoked_sausage},
    %{id: 3, name: "Hearty Mash", emoji: "🥔", stat: 35, cost: 250, effect: :hearty_mash},
    %{
      id: 4,
      name: "Roasted Pheasant",
      emoji: "🍗",
      stat: 65,
      cost: 1_200,
      effect: :roasted_pheasant
    }
  ]

  @battle %{
    enemy_count: %{min_mult: 0.3, max_mult: 0.6},
    danger_level: %{scaling: 0.6},
    crit_reward: %{multiplier: 1.9, floor: 1},
    damage_blocked: %{exponent: 0.95, scaling: 0.8},
    xp_gained: %{exponent: 1.5, scaling: 0.8, kill_min: 10, kill_max: 18},
    adena_gained: %{exponent: 2.65, scaling: 0.05, kill_min: 2, kill_max: 4},
    # The bar the losses were tuned against, before HP came from a class and a level.
    hp_lost: %{base_min: 10, base_max: 25, floor: 1, reference_max_hp: 100}
  }

  @zone %{
    combat_zones: ~w(battle suicide death),
    resting_zones:
      ~w(home inn weapons armors class_master symbol_maker character highscores statistics races),
    combat_linger_ms: 5_000
  }

  @character %{
    min_age: 9,
    max_age: 69,
    age_thresholds: %{
      youth: 23,
      adult: 54,
      labels: %{youth: "youth", adult: "adult", elder: "elder"}
    },
    name_min_length: 1,
    name_max_length: 20,
    builds: ["a hardy", "a wiry", "a sturdy", "a fit", "a rugged", "a robust", "a solid"]
  }

  @stat_modifier_labels %{
    max_hp: %{label: "Max HP"},
    max_mp: %{label: "Max MP"},
    hp_regen: %{label: "HP Regen"},
    mp_regen: %{label: "MP Regen"},
    crit_rate: %{label: "Critical"},
    ambush_risk: %{label: "Ambush", percentage?: true},
    p_atk: %{label: "P. Atk."},
    p_def: %{label: "P. Def."},
    xp_multiplier: %{label: "XP", multiplier?: true},
    adena_multiplier: %{label: "Adena", multiplier?: true}
  }

  def max_level, do: @max_level
  # Interlude's EXP is divided by this; at 363 levels 2 and 3 would merge.
  def exp_divisor, do: 300
  def races, do: @races
  def race(id), do: Enum.at(@races, id) || hd(@races)
  def effects, do: @effects
  def effect(key), do: Map.fetch!(@effects, key)

  @effects_by_id Map.new(@effects, fn {_key, effect} -> {effect.id, effect} end)

  @doc "The catalog entry an effect's stored id names, or nil for one it does not have."
  def effect_by_id(id), do: Map.get(@effects_by_id, id)
  def armors, do: @armors
  def weapons, do: @weapons
  def foods, do: @foods
  def armor(id), do: Enum.at(@armors, id) || hd(@armors)
  def weapon(id), do: Enum.at(@weapons, id) || hd(@weapons)
  def battle, do: @battle
  def zone, do: @zone
  def character, do: @character
  def stat_modifier_labels, do: @stat_modifier_labels
  def low_health_threshold, do: 0.25
  def highscores_limit, do: 25

  def konami_sequence,
    do: ~w(arrowup arrowup arrowdown arrowdown arrowleft arrowright arrowleft arrowright b a)
end
