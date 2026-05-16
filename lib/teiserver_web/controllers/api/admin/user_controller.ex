defmodule TeiserverWeb.API.Admin.UserController do
  alias Teiserver.Account
  alias Teiserver.Account.RoleLib
  alias Teiserver.OAuth
  use TeiserverWeb, :controller

  plug Teiserver.OAuth.Plug.EnsureAuthenticated, scopes: ["admin.user"]

  @stat_fields ["mu", "sigma", "play_time", "spec_time", "lobby_time"]

  # Roles that may be assigned to users created or refreshed through this API.
  # `admin.user` is intended for load-testing tooling, so callers must not be
  # able to mint staff/moderation/management accounts. Any role outside this
  # allowlist is silently dropped from create requests and blocks
  # refresh_token requests against pre-existing users.
  @api_allowed_roles ~w(
    Verified
    Trusted
    BAR+
    Bot
  )

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
    :privileged_target => 403,
    :default => 400
  }

  @error_messages %{
    :user_not_found => "User not found",
    :app_not_found => @app_not_found_error,
    :invalid_scope => "Invalid scope for OAuth application",
    :privileged_target =>
      "Target user has privileged roles; admin.user scope cannot mint tokens for staff accounts"
  }

  def create(conn, params) do
    params =
      @default_params
      |> Map.merge(params)
      |> sanitize_roles_and_permissions()

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
         :ok <- ensure_unprivileged(user),
         {:ok, app} <- get_generic_lobby_app(),
         {:ok, token} <- create_user_token(user, app) do
      json(conn, build_user_response(user, token))
    else
      error -> handle_error(conn, error)
    end
  end

  # Drop any caller-supplied role outside the allowlist and recompute
  # permissions from the surviving roles. Caller-supplied permission
  # strings are discarded entirely.
  defp sanitize_roles_and_permissions(params) do
    roles =
      params
      |> Map.get("roles", [])
      |> List.wrap()
      |> Enum.filter(&(&1 in @api_allowed_roles))
      |> Enum.uniq()

    permissions = RoleLib.calculate_permissions(roles)

    params
    |> Map.put("roles", roles)
    |> Map.put("permissions", permissions)
  end

  defp ensure_unprivileged(%{roles: roles}) when is_list(roles) do
    if Enum.all?(roles, &(&1 in @api_allowed_roles)) do
      :ok
    else
      {:error, :privileged_target}
    end
  end

  defp ensure_unprivileged(_user), do: :ok

  # Private helpers

  defp update_user_stats(user_id, params) do
    stat_fields = Map.take(params, @stat_fields)

    with {:ok, _stats} <- update_stats_if_needed(user_id, stat_fields) do
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

  defp get_generic_lobby_app do
    case OAuth.get_application_by_uid("generic_lobby") do
      nil -> {:error, :app_not_found}
      app -> {:ok, app}
    end
  end

  defp get_user_by_email(email) do
    case Account.get_user_by_email(email) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
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
    # credo:disable-for-lines:2 Credo.Check.Refactor.MapJoin
    |> Enum.map(fn {field, {message, _opts}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end
end
