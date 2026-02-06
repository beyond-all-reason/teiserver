defmodule Teiserver.OAuth.Tasks.GenToken do
  @moduledoc """
  Generates a token for the given user. This is for a convenience task to ease
  the development of anything requiring OAuth tokens like tachyon protocol.
  """

  alias Teiserver.OAuth.{ApplicationQueries, Token, TokenHash}

  @spec create_token(String.t(), String.t() | nil) :: {:ok, Token.t()} | {:error, term()}
  def create_token(username_or_email, app_uid \\ nil) do
    with {:ok, user} <- get_user(username_or_email),
         {:ok, app} <- get_app(app_uid) do
      {selector, hashed_verifier, full_token} = TokenHash.generate_token()

      token_attr = %{
        selector: selector,
        hashed_verifier: hashed_verifier,
        owner_id: user.id,
        application_id: app.id,
        scopes: app.scopes,
        expires_at: Timex.add(DateTime.utc_now(), Timex.Duration.from_days(1)),
        type: :access,
        refresh_token: nil
      }

      with {:ok, token} <- %Token{} |> Token.changeset(token_attr) |> Teiserver.Repo.insert() do
        {:ok, %{token | value: full_token}}
      end
    else
      {:error, msg} -> {:error, msg}
    end
  end

  defp get_user(username_or_email) do
    user =
      if String.contains?(username_or_email, "@") do
        Teiserver.Account.UserCacheLib.get_user_by_email(username_or_email)
      else
        Teiserver.Account.UserCacheLib.get_user_by_name(username_or_email)
      end

    if is_nil(user) do
      {:error, "No user found for username or email #{username_or_email}"}
    else
      {:ok, user}
    end
  end

  defp get_app(app_uid) do
    apps =
      ApplicationQueries.list_applications()
      |> Enum.filter(fn app -> is_nil(app_uid) or app.uid == app_uid end)

    case apps do
      [app] ->
        {:ok, app}

      [] ->
        {:error, "no oauth application found, need to create one first"}

      apps ->
        uids = Enum.map(apps, & &1.uid)
        {:error, "more than one oauth application found #{inspect(uids)}"}
    end
  end
end
