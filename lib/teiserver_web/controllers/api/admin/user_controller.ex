defmodule TeiserverWeb.API.Admin.UserController do
  use TeiserverWeb, :controller
  alias Teiserver.{Account, OAuth}

  plug Teiserver.OAuth.Plug.EnsureAuthenticated, scopes: ["admin.user"]

  @stat_fields ["mu", "sigma", "play_time", "spec_time", "lobby_time"]

  # POST /teiserver/api/admin/users
  def create(conn, params) do
    params =
      Map.merge(
        %{
          "permissions" => [],
          "roles" => [],
          "restrictions" => [],
          "shadowbanned" => false,
          "data" => Account.User.default_data()
        },
        params
      )

    case Account.script_create_user(params) do
      {:ok, user} ->
        with :ok <- update_user_stats(user.id, params),
             {:ok, tokens} <- issue_tokens(user, params) do
          json(conn, %{user: user_to_map(user), credentials: tokens})
        else
          {:error, reason} -> conn |> put_status(400) |> json(%{error: reason})
        end

      {:error, changeset} ->
        conn |> put_status(400) |> json(%{error: format_changeset_errors(changeset)})
    end
  end

  # GET /teiserver/api/admin/users/:email
  def show(conn, %{"email" => email}) do
    case Account.get_user_by_email(email) do
      nil ->
        conn |> put_status(404) |> json(%{error: "User not found"})

      user ->
        with {:ok, tokens} <- issue_tokens(user, %{}) do
          json(conn, %{user: user_to_map(user), credentials: tokens})
        else
          {:error, reason} -> conn |> put_status(400) |> json(%{error: reason})
        end
    end
  end

  # Private helpers

  defp update_user_stats(user_id, params) do
    stat_fields = Map.take(params, @stat_fields)
    if stat_fields != %{}, do: Account.update_user_stat(user_id, stat_fields)
    :ok
  end

  defp issue_tokens(user, params) do
    case OAuth.get_application_by_uid("user_admin") do
      app when not is_nil(app) ->
        case OAuth.create_token(user, app,
               expires_in: params["token_expires_in"] || 86_400,
               scopes: app.scopes
             ) do
          {:ok, token} ->
            credentials = %{access_token: token.value}

            if token.refresh_token,
              do: Map.put(credentials, :refresh_token, token.refresh_token.value),
              else: credentials

            {:ok, credentials}

          err ->
            err
        end

      nil ->
        {:error,
         "user_admin OAuth application not found. Please run 'mix teiserver.tachyon_setup' to create it."}
    end
  end

  defp user_to_map(user) do
    Map.take(
      user,
      ~w(id name email icon colour roles permissions restrictions shadowbanned last_login last_played)a
    )
    |> Map.merge(%{
      inserted_at: Map.get(user, :inserted_at),
      updated_at: Map.get(user, :updated_at)
    })
  end

  defp format_changeset_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end
end
