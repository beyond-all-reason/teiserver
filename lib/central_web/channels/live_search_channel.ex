defmodule CentralWeb.LiveSearch.Channel do
  use Phoenix.Channel

  alias Central.Account

  def join("live_search:endpoints:" <> _uid, _params, socket) do
    {:ok, socket}
  end

  # Guests
  def handle_in(subject, params, %{topic: "live_search:endpoints:" <> _} = socket) do
    uid = params["uid"]

    case subject do
      "search" ->
        results = handle_search(socket, params["dataset"], params["search_term"])

        CentralWeb.Endpoint.broadcast(
          "live_search:endpoints:#{uid}",
          "live_search results",
          %{results: results}
        )

        # {:reply, {:ok, %{results: result}}, socket}
        {:reply, :ok, socket}
    end
  end

  defp handle_search(_socket, dataset, search_term) do
    case dataset do
      "account_user" ->
        Account.list_users(search: [simple_search: search_term], order: "Name (A-Z)")
        |> Account.user_as_json()

      "account_group" ->
        Account.list_groups(search: [simple_search: search_term], order: "Name (A-Z)")
        |> Account.group_as_json()
    end
  end
end
