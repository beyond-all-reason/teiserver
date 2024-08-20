defmodule Teiserver.Coordinator.WelcomeHelper do
  alias Teiserver.Battle.BalanceLib
  alias Teiserver.Lobby.LobbyRestrictions

  # Gets welcome text when given consul_server state
  # Includes rating restrictions text and custom balance algorithm info
  def get_welcome_message(state) do
    welcome_message =
      if state.welcome_message do
        String.split(state.welcome_message, "$$")
      end

    restrictions = LobbyRestrictions.get_lobby_restrictions_welcome_text(state)

    custom_balance_welcome_message = get_custom_balance_welcome(state.balance_algorithm)

    combine_welcome_message(
      welcome_message,
      restrictions,
      custom_balance_welcome_message
    )
  end

  def combine_welcome_message(welcome_text, restrictions_text, custom_balance_text) do
    [
      welcome_text,
      restrictions_text,
      custom_balance_text
    ]
    |> Enum.filter(fn s -> s != nil and s != [] end)
    |> Enum.intersperse("")
    |> List.flatten()
  end

  # Custom welcome message when using non-default balance
  def get_custom_balance_welcome(balance_algorithm) do
    default_algo = BalanceLib.get_default_algorithm()

    cond do
      balance_algorithm == default_algo ->
        nil

      true ->
        [
          "This lobby is using balance algorithm:",
          balance_algorithm,
          "",
          "Use \"$explain\" after balancing to view logs."
        ]
    end
  end
end
