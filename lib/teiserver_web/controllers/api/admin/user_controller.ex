defmodule TeiserverWeb.API.Admin.UserController do
  use TeiserverWeb, :controller
  alias Teiserver.{Account, OAuth}

  plug Teiserver.OAuth.Plug.EnsureAuthenticated, scopes: ["tachyon.lobby"]

  @stat_fields ["mu", "sigma", "play_time", "spec_time", "lobby_time"]
  @default_params %{
    "permissions" => [],
    "roles" => [],
    "restrictions" => [],
    "shadowbanned" => false,
    "data" => Account.User.default_data()
  }
  @app_not_found_error "generic_lobby OAuth application not found. Please run 'mix teiserver.tachyon_setup' to create it."

  @error_status_codes %{
    :user_not_found => 404,
    :app_not_found => 400,
    :invalid_scope => 400,
    :default => 400
  }

  @error_messages %{
    :user_not_found => "User not found",
    :app_not_found => @app_not_found_error,
    :invalid_scope => "Invalid scope for OAuth application"
  }

  def create(conn, params) do
    params = Map.merge(@default_params, params)

    with {:ok, user} <- Account.script_create_user(params),
         :ok <- update_user_stats(user.id, params),
         {:ok, app} <- get_generic_lobby_app(),
         {:ok, token} <- create_user_token(user, app) do
      json(conn, build_user_response(user, token))
    else
      error -> handle_error(conn, error)
    end
  end

  def refresh_token(conn, %{"email" => email}) do
    with {:ok, user} <- get_user_by_email(email),
         {:ok, app} <- get_generic_lobby_app(),
         {:ok, token} <- create_user_token(user, app) do
      json(conn, build_user_response(user, token))
    else
      error -> handle_error(conn, error)
    end
  end

  # Private helpers

  defp update_user_stats(user_id, params) do
    stat_fields = Map.take(params, @stat_fields)

    with {:ok, _} <- update_stats_if_needed(user_id, stat_fields) do
      :ok
    end
  end

  defp update_stats_if_needed(user_id, stat_fields) do
    if map_size(stat_fields) > 0 do
      Account.update_user_stat(user_id, stat_fields)
    else
      {:ok, nil}
    end
  end

  defp get_generic_lobby_app() do
    with app when not is_nil(app) <- OAuth.get_application_by_uid("generic_lobby") do
      {:ok, app}
    else
      nil -> {:error, :app_not_found}
    end
  end

  defp get_user_by_email(email) do
    with user when not is_nil(user) <- Account.get_user_by_email(email) do
      {:ok, user}
    else
      nil -> {:error, :user_not_found}
    end
  end

  defp create_user_token(user, app) do
    OAuth.create_token(
      user,
      %{
        id: app.id,
        scopes: app.scopes
      },
      create_refresh: true,
      scopes: app.scopes
    )
  end

  defp build_user_response(user, token) do
    credentials = %{
      access_token: token.value,
      refresh_token: token.refresh_token.value
    }

    user_data =
      Map.take(
        user,
        ~w(id name email icon colour roles permissions restrictions shadowbanned last_login last_played)a
      )

    timestamps = %{
      inserted_at: Map.get(user, :inserted_at),
      updated_at: Map.get(user, :updated_at)
    }

    %{user: Map.merge(user_data, timestamps), credentials: credentials}
  end

  defp handle_error(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn |> put_status(400) |> json(%{error: format_changeset_errors(changeset)})
  end

  defp handle_error(conn, {:error, reason}) do
    status = Map.get(@error_status_codes, reason, @error_status_codes[:default])
    message = Map.get(@error_messages, reason, "Operation failed: #{inspect(reason)}")
    conn |> put_status(status) |> json(%{error: message})
  end

  defp format_changeset_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end
end
