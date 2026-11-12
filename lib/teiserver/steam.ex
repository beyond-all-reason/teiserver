defmodule Teiserver.Steam do
  @moduledoc """
  Everything Steam related

  Handles requests to Steam Web API
  https://partner.steamgames.com/doc/webapi
  """

  alias Req.Response

  require Logger

  @base_url "https://partner.steam-api.com"

  @spec enabled?() :: boolean()
  def enabled? do
    api_key() != nil
  end

  @doc """
  https://partner.steamgames.com/doc/webapi/ISteamUserAuth#AuthenticateUserTicket
  """
  def authenticate_ticket(ticket) do
    params =
      [key: api_key(), appid: app_id(), ticket: ticket, identity: identity()]

    with {:ok, body} <- get("/ISteamUserAuth/AuthenticateUserTicket/v1/", params) do
      handle_authenticate_response(body)
    end
  end

  @doc """
  Example response
  {
    "response": {
      "params": {
        "result": "OK",
        "steamid": "12345678910111213",
        "ownersteamid": "12345678910111213",
        "vacbanned": false,
        "publisherbanned": false
      }
    }
  }
  """
  @spec handle_authenticate_response(term()) ::
          {:ok, pos_integer()} | {:error, atom()}
  def handle_authenticate_response(%{"response" => %{"params" => params}}) do
    with "OK" <- params["result"],
         true <- params["publisherbanned"] == false,
         {steam_id, ""} <- params["steamid"] |> to_string() |> Integer.parse() do
      {:ok, steam_id}
    else
      false -> {:error, :publisher_banned}
      _other -> {:error, :invalid_ticket}
    end
  end

  def handle_authenticate_response(%{"response" => %{"error" => error}}) do
    Logger.info("Steam ticket authentication failed: #{inspect(error)}")
    {:error, :invalid_ticket}
  end

  def handle_authenticate_response(body) do
    Logger.error("Steam ticket authentication failed: #{inspect(body)}")
    {:error, :steam_error}
  end

  @doc """
  https://partner.steamgames.com/doc/webapi/ISteamUser#CheckAppOwnership
  """
  def check_app_ownership(steam_id) do
    params = [key: api_key(), steamid: steam_id, appid: app_id()]

    with {:ok, body} <- get("/ISteamUser/CheckAppOwnership/v4/", params) do
      handle_ownership_response(body, steam_id)
    end
  end

  @doc """
  Example response
  {
    "appownership": {
      "ownsapp": true,
      "permanent": false,
      "timestamp": "2026-11-05T03:16:09Z",
      "timeexpires": "never",
      "ownersteamid": "12345678910111213",
      "sitelicense": false,
      "timedtrial": false,
      "usercanceled": false,
      "result": "OK"
    }
  }
  """
  def handle_ownership_response(%{"appownership" => ownership}, steam_id),
    do: handle_ownership_response(ownership, steam_id)

  def handle_ownership_response(%{"ownsapp" => true} = _ownership, _steam_id), do: :ok

  def handle_ownership_response(%{"ownsapp" => false}, _steam_id), do: {:error, :not_owned}

  def handle_ownership_response(body, _steam_id) do
    Logger.error("Steam ownership check failed: #{inspect(body)}")
    {:error, :steam_error}
  end

  @doc """
  https://partner.steamgames.com/doc/webapi/ISteamUser#GetPlayerSummaries
  """
  @spec get_persona_name(pos_integer()) :: {:ok, String.t()} | {:error, :steam_error}
  def get_persona_name(steam_id) do
    params = [key: api_key(), steamids: steam_id]

    with {:ok, body} <- get("/ISteamUser/GetPlayerSummaries/v2/", params) do
      handle_player_summaries_response(body)
    end
  end

  @doc """
  Example response
  {
    "response":{
      "players":[
        {
            "steamid":"77561198355051011",
            "communityvisibilitystate":1,
            "profilestate":1,
            "personaname":"Mister Manager",
            "lastlogoff":1556305001,
            "profileurl":"https://steamcommunity.com/profiles/77561198355051011/",
            "avatar":"https://steamcdn-a.akamaihd.net/steamcommunity/public/images/avatars/32/32f70a383a437d03af91d2f01a0776adf75201b5.jpg",
            "avatarmedium":"https://steamcdn-a.akamaihd.net/steamcommunity/public/images/avatars/32/32f70a383a437d03af91d2f01a0776adf75201b5_medium.jpg",
            "avatarfull":"https://steamcdn-a.akamaihd.net/steamcommunity/public/images/avatars/32/32f70a383a437d03af91d2f01a0776adf75201b5_full.jpg",
        },
        {
            "steamid":"77561197978236369",
            "communityvisibilitystate":3,
            "profilestate":1,
            "personaname":"Olive The Dog",
            "lastlogoff":1556239336,
            "profileurl":"https://steamcommunity.com/id/olive_the_dog/",
            "avatar":"https://steamcdn-a.akamaihd.net/steamcommunity/public/images/avatars/41/555d2fbb879593c0565ce0489428a09c019feffa.jpg",
            "avatarmedium":"https://steamcdn-a.akamaihd.net/steamcommunity/public/images/avatars/41/555d2fbb879593c0565ce0489428a09c019feffa_medium.jpg",
            "avatarfull":"https://steamcdn-a.akamaihd.net/steamcommunity/public/images/avatars/41/555d2fbb879593c0565ce0489428a09c019feffa_full.jpg",
        }
      ]
    }
  }
  """
  def handle_player_summaries_response(%{
        "response" => %{"players" => [%{"personaname" => name} | _rest]}
      })
      when is_binary(name) do
    {:ok, name}
  end

  def handle_player_summaries_response(body) do
    Logger.warning("Steam player summaries failed: #{inspect(body)}")
    {:error, :steam_error}
  end

  defp get(path, params) do
    case Req.get(@base_url <> path, params: params) do
      {:ok, %Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Response{status: status, body: body}} ->
        Logger.warning("Steam API #{path} returned status #{status}: #{inspect(body)}")
        {:error, :steam_error}

      {:error, reason} ->
        Logger.warning("Steam API #{path} request failed: #{inspect(reason)}")
        {:error, :steam_error}
    end
  end

  defp api_key, do: Application.get_env(:teiserver, __MODULE__)[:api_key]

  defp app_id, do: Application.get_env(:teiserver, __MODULE__)[:app_id]

  defp identity, do: Application.get_env(:teiserver, __MODULE__)[:identity]
end
