defmodule Teiserver.Lobby.LobbyStruct do
  @moduledoc """
  This is the struct used to store data about the lobby itself in memory.
  """

  @enforce_keys ~w(id founder_id engine_version game_name game_hash map_hash map_name ip port nattype lobby_type)a
  defstruct [
    # Static values (and thus enforced)
    id: nil,
    founder_id: nil,
    ip: nil,
    port: nil,
    nattype: nil,
    engine_version: nil,
    game_name: nil,
    game_hash: nil,
    # Normal, Replay
    lobby_type: "normal",

    # Values built from components
    display_name: nil,

    # Membership stuff
    # userid list
    members: [],
    member_count: 0,
    # userid list
    players: [],
    spectator_count: 0,

    # Basic variables
    base_name: nil,
    teaser: "",
    rename_type: nil,
    password: nil,
    locked: nil,
    silence: false,
    map_name: nil,
    map_hash: nil,
    start_areas: %{},
    disabled_units: [],
    # Config.get_site_config_cache("teiserver.Default player limit"),
    max_players: 0,

    # Variables used to record/cache things about the lobby
    started_at: nil,
    match_id: nil,

    # External references
    lobby_policy_id: nil,
    queue_id: nil,
    tournament_id: nil,

    # Consul server stuff
    gatekeeper: "default",
    minimum_rating_to_play: 0,
    maximum_rating_to_play: 1000,
    minimum_rank_to_play: 0,
    maximum_rank_to_play: 1000,
    minimum_uncertainty_to_play: 0,
    maximum_uncertainty_to_play: 1000,
    minimum_skill_to_play: 0,
    maximum_skill_to_play: 1000,
    level_to_spectate: 0,
    locks: [],
    bans: %{},
    timeouts: %{},
    join_queue: [],
    low_priority_join_queue: [],
    approved_users: [],
    host_bosses: [],
    host_preset: nil,
    host_teamsize: 8,
    host_teamcount: 2,
    ring_timestamps: %{},
    # Config.get_site_config_cache("teiserver.Ring flood rate limit count"),
    ring_limit_count: 0,
    # Config.get_site_config_cache("teiserver.Ring flood rate window size"),
    ring_window_size: 0,
    afk_check_list: [],
    afk_check_at: nil,
    last_seen_map: %{},
    # Used to tell if there has been a change to the queue state and should it be broadcast
    last_queue_state: [],
    balance_result: nil,
    showmatch: true,

    # Stuff from the consul that needs to move out of the lobby state itself
    split: nil,
    welcome_message: nil
  ]
end
