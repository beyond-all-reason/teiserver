defmodule Teiserver.TachyonLobby.Events.AddBot do
  @moduledoc """
  Adding a bot to the lobby. The bot already has its id and its team
  """

  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:bot]
  defstruct [:bot]

  @type t() :: %__MODULE__{
          bot: LT.Bot.t()
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.AddBot do
  alias Teiserver.TachyonLobby.Events.AddBot
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%AddBot{bot: bot}, %LT.Aggregate{} = agg) do
    data =
      agg.data
      |> put_in([Access.key!(:players), bot.id], bot)
      |> Map.update!(:bot_idx_counter, &(&1 + 1))

    changes =
      agg.changes
      |> Map.put_new(:players, %{})
      |> put_in([:players, bot.id], bot)

    %{agg | data: data, changes: changes}
    |> LT.Aggregate.add_log("bot_add", %{
      user_id: bot.host_user_id,
      details: %{
        bot_id: bot.id,
        name: bot.name,
        short_name: bot.short_name,
        version: bot.version,
        ally_team: elem(bot.team, 0)
      }
    })
  end
end
