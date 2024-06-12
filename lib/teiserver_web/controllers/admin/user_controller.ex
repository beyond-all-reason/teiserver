defmodule TeiserverWeb.Admin.UserController do
  @moduledoc false
  require Logger
  use TeiserverWeb, :controller

  alias Teiserver.{Account, Chat, Game}
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.Account.User
  alias Teiserver.Account.{UserLib, RoleLib}
  alias Teiserver.Battle.BalanceLib
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1, float_parse: 1]

  plug(AssignPlug,
    site_menu_active: "teiserver_user",
    sub_menu_active: "user"
  )

  plug(Bodyguard.Plug.Authorize,
    policy: Teiserver.Account.Auth,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}
  )

  plug(:add_breadcrumb, name: "Admin", url: "/teiserver/admin")
  plug(:add_breadcrumb, name: "Users", url: "/teiserver/admin/user")

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    users =
      Account.list_users(
        search: [
          basic_search: Map.get(params, "s", "") |> String.trim()
        ],
        order_by: "Newest first",
        limit: 50
      )

    # Sometimes we get a lot of matches so it can be good to put in place exact matches too
    exact_match =
      if Enum.count(users) > 20 && params["s"] do
        Account.list_users(search: [name_lower: params["s"]])
      else
        []
      end

    users = (exact_match ++ users) |> Enum.reject(&(&1 == nil))
    user_stats = for user <- users, do: Account.get_user_stat_data(user.id)

    if Enum.count(users) == 1 do
      conn
      |> redirect(to: Routes.ts_admin_user_path(conn, :show, hd(users).id))
    else
      conn
      |> add_breadcrumb(name: "List users", url: conn.request_path)
      |> assign(:users, Enum.zip(users, user_stats))
      |> assign(:params, search_defaults(conn))
      |> render("index.html")
    end
  end

  @spec search(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def search(conn, %{"search" => params}) do
    params = Map.merge(search_defaults(conn), params)

    id_list =
      if params["previous_names"] != nil and params["previous_names"] != "" do
        Account.list_user_stats(
          search: [
            data_contains: {"previous_names", params["previous_names"]}
          ],
          select: [:user_id]
        )
        |> Enum.map(fn s -> s.user_id end)
      else
        []
      end

    users =
      (Account.list_users(
         search: [
           name_or_email: Map.get(params, "name", "") |> String.trim(),
           bot: params["bot"],
           has_role: params["role"],
           ip: params["ip"],
           lobby_client: params["lobby_client"],
           previous_names: params["previous_names"],
           mod_action: params["mod_action"],
           behaviour_score_gt: params["behaviour_score_min"],
           behaviour_score_lt: params["behaviour_score_max"]
         ],
         limit: params["limit"] || 50,
         order_by: params["order"] || "Name (A-Z)"
       ) ++
         Account.list_users(search: [id_in: id_list]))
      |> Enum.uniq()

    user_stats = for user <- users, do: Account.get_user_stat_data(user.id)

    conn
    |> add_breadcrumb(name: "User search", url: conn.request_path)
    |> assign(:params, params)
    |> assign(:users, Enum.zip(users, user_stats))
    |> render("index.html")
  end

  @spec data_search(Plug.Conn.t(), map) :: Plug.Conn.t()
  def data_search(conn, params) do
    users =
      if params["data_search"] == nil do
        []
      else
        id_list =
          Teiserver.Account.list_user_stats(
            search: [
              data_equal: {"hardware:gpuinfo", params["data_search"]["gpu"]},
              data_equal: {"hardware:cpuinfo", params["data_search"]["cpu"]},
              data_equal: {"hardware:osinfo", params["data_search"]["os"]},
              data_equal: {"hardware:raminfo", params["data_search"]["ram"]},
              data_equal: {"hardware:displaymax", params["data_search"]["screen"]},
              data_equal:
                {params["data_search"]["custom_field"], params["data_search"]["custom_value"]}
            ],
            select: [:user_id],
            limit: :infinity
          )
          |> Stream.map(fn stats -> stats.user_id end)
          |> Enum.to_list()

        Account.list_users(search: [id_in: id_list])
      end

    user_stats = for user <- users, do: Account.get_user_stat_data(user.id)

    conn
    |> add_breadcrumb(name: "Data search", url: conn.request_path)
    |> assign(:params, params["data_search"])
    |> assign(:data_search, true)
    |> assign(:users, Enum.zip(users, user_stats))
    |> render("index.html")
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    user = Account.get_user(id)

    case Teiserver.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        user
        |> UserLib.make_favourite()
        |> insert_recently(conn)

        user_stats = Account.get_user_stat_data(user.id)
        client = Account.get_client_by_id(user.id)

        json_user =
          Map.drop(user, [
            :__struct__,
            :__meta__,
            :user_configs,
            :clan,
            :smurf_of,
            :user_stat,
            :data
          ])

        cache_user = Account.get_user_by_id(user.id)

        extra_cache_keys =
          cache_user
          |> Map.keys()
          |> Enum.reject(fn cache_user_key ->
            Enum.member?(Map.keys(json_user), cache_user_key)
          end)

        conn
        |> assign(:user, user)
        |> assign(:client, client)
        |> assign(:user_stats, user_stats)
        |> assign(:role_data, RoleLib.role_data())
        |> assign(:section_menu_active, "show")
        |> assign(:json_user, json_user)
        |> assign(:cache_user, cache_user)
        |> assign(:extra_cache_keys, extra_cache_keys)
        |> add_breadcrumb(name: "Show: #{user.name}", url: conn.request_path)
        |> render("show.html")

      {false, :restricted_user} ->
        conn
        |> put_flash(:danger, "This is a restricted user")
        |> redirect(to: ~p"/teiserver/admin/user")

      _ ->
        conn
        |> put_flash(:danger, "Unable to access this user")
        |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  @spec new(Plug.Conn.t(), map) :: Plug.Conn.t()
  def new(conn, _params) do
    changeset =
      Account.change_user(%User{
        icon: "fa-solid fa-user",
        colour: "#AA0000"
      })

    conn
    |> assign(:changeset, changeset)
    |> add_breadcrumb(name: "New user", url: conn.request_path)
    |> render("new.html")
  end

  @spec create_form(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create_form(conn, _) do
    if allow?(conn, "Server") do
      conn
      |> render("create_form.html")
    else
      conn
      |> put_flash(:info, "No permission")
      |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  @spec create_post(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create_post(conn, params \\ %{}) do
    if is_nil(params["name"]) or String.trim(params["name"]) == "" do
      conn
      |> put_flash(:danger, "Invalid user name")
      |> redirect(to: ~p"/teiserver/admin/user")
    end

    if allow?(conn, "Server") and Application.get_env(:teiserver, Teiserver)[:test_mode] do
      password =
        if is_nil(params["password"]) or String.trim(params["password"]) == "" do
          "password"
        else
          params["password"]
        end

      email =
        if is_nil(params["email"]) or String.trim(params["email"]) == "" do
          UUID.uuid1()
        else
          params["email"]
        end

      case Teiserver.CacheUser.register_user(params["name"], email, password) do
        :success ->
          conn
          |> put_flash(:info, "User created successfully.")
          |> redirect(to: ~p"/teiserver/admin/user")

        {:failure, str} ->
          conn
          |> put_flash(:error, "Problem creating user: " <> str)
          |> redirect(to: ~p"/teiserver/admin/user")
      end
    else
      conn
      |> put_flash(:danger, "No access.")
      |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"user" => user_params}) do
    user_params =
      Map.merge(user_params, %{
        "password" => "pass",
        "data" => %{
          "rank" => 1,
          "friends" => [],
          "friend_requests" => [],
          "ignored" => [],
          "roles" => ["Verified"],
          "bot" => user_params["bot"] == "true",
          "moderator" => user_params["moderator"] == "true",
          "password_hash" => "X03MO1qnZdYdgyfeuILPmQ=="
        }
      })

    case Account.create_user(user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: ~p"/teiserver/admin/user")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  @spec edit(Plug.Conn.t(), map) :: Plug.Conn.t()
  def edit(conn, %{"id" => id}) do
    user = Account.get_user(id)

    case Teiserver.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        changeset = Account.change_user(user)

        conn
        |> assign(:user, user)
        |> assign(:changeset, changeset)
        |> assign(:management_roles, RoleLib.management_roles())
        |> assign(:moderation_roles, RoleLib.moderation_roles())
        |> assign(:staff_roles, RoleLib.staff_roles())
        |> assign(:community_roles, RoleLib.community_roles())
        |> assign(:privileged_roles, RoleLib.privileged_roles())
        |> assign(:property_roles, RoleLib.property_roles())
        |> assign(:role_styling_map, RoleLib.role_data())
        |> add_breadcrumb(name: "Edit: #{user.name}", url: conn.request_path)
        |> render("edit.html")

      _ ->
        conn
        |> put_flash(:danger, "Unable to access this user")
        |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "user" => user_params}) do
    current_user = conn.assigns.current_user
    user = Account.get_user!(id)

    # We decache now and later to ensure we decache data as it stands too
    Account.decache_user(user.id)

    changeable_roles =
      cond do
        Enum.member?(current_user.roles, "Server") ->
          RoleLib.allowed_role_management("Server")

        Enum.member?(current_user.roles, "Admin") ->
          RoleLib.allowed_role_management("Admin")

        Enum.member?(current_user.roles, "Moderator") ->
          RoleLib.allowed_role_management("Moderator")

        true ->
          []
      end

    # Go through all roles, any we're not allowed to change
    # we leave as they are, any we are we do stuff with
    new_roles =
      RoleLib.all_role_names()
      |> Enum.map(fn role_name ->
        selected =
          if Enum.member?(changeable_roles, role_name) do
            user_params[role_name] == "true"
          else
            Enum.member?(user.roles, role_name)
          end

        if selected do
          role_name
        end
      end)
      |> Enum.reject(&(&1 == nil))
      |> Enum.uniq()

    permissions =
      new_roles
      |> Enum.map(fn role_name ->
        role_def = RoleLib.role_data(role_name)
        [role_name | role_def.contains]
      end)
      |> List.flatten()
      |> Enum.uniq()

    data =
      Map.merge(user.data || %{}, %{
        "bot" => Enum.member?(permissions, "Bot"),
        "moderator" => Enum.member?(permissions, "Moderator"),
        "verified" => user_params["verified"] == "true",
        "roles" => new_roles
      })

    user_params =
      Map.merge(user_params, %{
        "data" => data,
        "permissions" => permissions,
        "roles" => new_roles
      })

    case Teiserver.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        change_result =
          cond do
            allow?(conn, "Server") ->
              Account.server_update_user(user, user_params)

            allow?(conn, "Admin") ->
              Account.server_limited_update_user(user, user_params)

            allow?(conn, "Moderator") ->
              Account.server_limited_update_user(user, user_params)
          end

        case change_result do
          {:ok, user} ->
            Account.decache_user(user.id)

            conn
            |> put_flash(:info, "User updated successfully.")
            # |> redirect(to: ~p"/teiserver/admin/user")
            |> redirect(to: ~p"/teiserver/admin/user/#{user.id}")

          {:error, %Ecto.Changeset{} = changeset} ->
            render(conn, "edit.html", user: user, changeset: changeset)
        end

      _ ->
        conn
        |> put_flash(:danger, "Unable to access this user")
        |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  @spec reset_password(Plug.Conn.t(), map) :: Plug.Conn.t()
  def reset_password(conn, %{"id" => id}) do
    user = Account.get_user!(id)

    case Teiserver.Account.UserLib.has_access(user, conn) do
      {false, :not_found} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: ~p"/teiserver/admin/user")

      {false, :no_access} ->
        conn
        |> put_flash(:danger, "Unable to find that user")
        |> redirect(to: ~p"/teiserver/admin/user")

      {true, _} ->
        case Teiserver.Account.Emails.send_password_reset(user) do
          :ok ->
            conn
            |> put_flash(:success, "Password reset email sent to user")
            |> redirect(to: ~p"/teiserver/admin/user/#{user}")

          {:error, error} ->
            Logger.error(
              "Failed to send password reset email to user at #{user.email}: #{inspect(error)}"
            )

            conn
            |> put_flash(:error, "Oops, something went wrong resetting the password")
            |> redirect(to: ~p"/teiserver/admin/user/#{user}")
        end
    end
  end

  @spec ratings(Plug.Conn.t(), map) :: Plug.Conn.t()
  def ratings(conn, %{"id" => id} = params) do
    user = Account.get_user(id)

    case Teiserver.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        filter = params["filter"]
        filter_type_id = MatchRatingLib.rating_type_name_lookup()[filter]
        limit = (params["limit"] || "50") |> int_parse

        ratings =
          Account.list_ratings(
            search: [
              user_id: user.id
            ],
            preload: [:rating_type]
          )
          |> Map.new(fn rating ->
            {rating.rating_type.name, rating}
          end)

        logs =
          Game.list_rating_logs(
            search: [
              user_id: user.id,
              rating_type_id: filter_type_id
            ],
            order_by: "Newest first",
            limit: limit,
            preload: [:match, :match_membership]
          )

        games = Enum.count(logs) |> max(1)
        wins = Enum.count(logs, fn l -> l.match_membership.win end)

        stats =
          if Enum.empty?(logs) do
            %{first_log: nil}
          else
            %{
              games: games,
              winrate: wins / games,
              first_log: logs |> Enum.reverse() |> hd
            }
          end

        conn
        |> assign(:filter, filter || "rating-all")
        |> assign(:user, user)
        |> assign(:ratings, ratings)
        |> assign(:logs, logs)
        |> assign(:rating_type_list, MatchRatingLib.rating_type_list())
        |> assign(:rating_type_id_lookup, MatchRatingLib.rating_type_id_lookup())
        |> assign(:stats, stats)
        |> add_breadcrumb(name: "Ratings: #{user.name}", url: conn.request_path)
        |> render("ratings.html")

      _ ->
        conn
        |> put_flash(:danger, "Unable to access this user")
        |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  @spec ratings_form(Plug.Conn.t(), map) :: Plug.Conn.t()
  def ratings_form(conn, %{"id" => id}) do
    user = Account.get_user(id)

    case Teiserver.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        ratings =
          Account.list_ratings(
            search: [
              user_id: user.id
            ],
            preload: [:rating_type]
          )
          |> Map.new(fn rating ->
            {rating.rating_type.name, rating}
          end)

        conn
        |> assign(:user, user)
        |> assign(:ratings, ratings)
        |> assign(:default_rating, BalanceLib.default_rating())
        |> assign(:rating_type_list, MatchRatingLib.rating_type_list())
        |> add_breadcrumb(name: "Ratings form: #{user.name}", url: conn.request_path)
        |> render("ratings_form.html")

      _ ->
        conn
        |> put_flash(:danger, "Unable to access this user")
        |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  @spec ratings_post(Plug.Conn.t(), map) :: Plug.Conn.t()
  def ratings_post(conn, %{"id" => id} = params) do
    user = Account.get_user(id)

    case Teiserver.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        changes =
          MatchRatingLib.rating_type_list()
          |> Enum.map(fn r -> {r, params[r]} end)
          |> Enum.reject(fn {_r, changes} ->
            changes["skill"] == changes["old_skill"] and
              changes["uncertainty"] == changes["old_uncertainty"]
          end)
          |> Enum.map(fn {rating_type, changes} ->
            rating_type_id = MatchRatingLib.rating_type_name_lookup()[rating_type]

            existing_rating = Account.get_rating(user.id, rating_type_id)
            user_rating = existing_rating || BalanceLib.default_rating()
            new_skill = changes["skill"] |> float_parse
            new_uncertainty = changes["uncertainty"] |> float_parse
            new_rating_value = BalanceLib.calculate_rating_value(new_skill, new_uncertainty)

            new_leaderboard_rating =
              BalanceLib.calculate_leaderboard_rating(new_skill, new_uncertainty)

            {:ok, new_rating} =
              case Account.get_rating(user.id, rating_type_id) do
                nil ->
                  Account.create_rating(%{
                    user_id: user.id,
                    rating_type_id: rating_type_id,
                    rating_value: new_rating_value,
                    skill: new_skill,
                    uncertainty: new_uncertainty,
                    leaderboard_rating: new_leaderboard_rating,
                    last_updated: Timex.now()
                  })

                existing ->
                  Account.update_rating(existing, %{
                    rating_value: new_rating_value,
                    skill: new_skill,
                    uncertainty: new_uncertainty,
                    leaderboard_rating: new_leaderboard_rating,
                    last_updated: Timex.now()
                  })
              end

            log_params = %{
              user_id: user.id,
              rating_type_id: rating_type_id,
              match_id: nil,
              inserted_at: Timex.now(),
              value: %{
                reason: "Manual adjustment",
                rating_value: new_rating_value,
                skill: new_skill,
                uncertainty: new_uncertainty,
                rating_value_change: new_rating_value - user_rating.rating_value,
                skill_change: new_skill - user_rating.skill,
                uncertainty_change: new_uncertainty - user_rating.uncertainty
              }
            }

            {:ok, log} = Game.create_rating_log(log_params)

            {new_rating, log}
          end)

        log_ids =
          changes
          |> Enum.map(fn {_, log} -> log.id end)

        add_audit_log(conn, "Teiserver:Changed user rating", %{
          user_id: user.id,
          log_ids: log_ids
        })

        conn
        |> put_flash(:success, "Ratings updated")
        |> redirect(to: Routes.ts_admin_user_path(conn, :ratings_form, user))

      _ ->
        conn
        |> put_flash(:danger, "Unable to access this user")
        |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  @spec perform_action(Plug.Conn.t(), map) :: Plug.Conn.t()
  def perform_action(conn, %{"id" => id, "action" => action}) do
    user = Account.get_user!(id)

    case Teiserver.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        result =
          case action do
            "recache" ->
              Teiserver.Moderation.RefreshUserRestrictionsTask.refresh_user(user.id)
              Teiserver.CacheUser.recache_user(user.id)
              {:ok, ""}

            "reset_flood_protection" ->
              ConCache.put(:teiserver_login_count, user.id, 0)
              {:ok, ""}
          end

        case result do
          {:ok, tab} ->
            conn
            |> put_flash(:info, "Action performed.")
            |> redirect(to: Routes.ts_admin_user_path(conn, :applying, user) <> "?tab=#{tab}")
        end

      _ ->
        conn
        |> put_flash(:danger, "Unable to access this user")
        |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  @spec smurf_search(Plug.Conn.t(), map) :: Plug.Conn.t()
  def smurf_search(conn, %{"id" => id}) do
    user = Account.get_user!(id)

    case Teiserver.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        all_user_keys =
          Account.list_smurf_keys(
            search: [
              user_id: user.id
            ],
            limit: :infinity,
            preload: [:type],
            order_by: "Newest first"
          )

        key_count_by_type_name =
          all_user_keys
          |> Enum.group_by(fn k -> k.type.name end, fn _ -> 1 end)
          |> Enum.map(fn {k, vs} -> {k, Enum.count(vs)} end)
          |> Enum.sort(&<=/2)

        user_key_lookup =
          all_user_keys
          |> Map.new(fn k -> {k.value, k} end)

        matching_keys = Account.smurf_search(user)

        key_types =
          matching_keys
          |> Enum.map(fn {{type, _value}, _} -> type end)
          |> Enum.uniq()
          |> Enum.sort()

        users =
          matching_keys
          |> Enum.map(fn {{_type, _value}, matches} ->
            matches
            |> Enum.map(fn m -> m.user end)
          end)
          |> List.flatten()
          |> Map.new(fn user -> {user.id, user} end)
          |> Enum.map(fn {_, user} -> user end)
          |> Enum.sort_by(
            fn user ->
              user.data["last_login"]
            end,
            &>=/2
          )

        # Next we want to know the date of the key we matched against for that user
        key_lookup =
          matching_keys
          |> Enum.map(fn {{matched_type, _matched_value}, matches} ->
            matches
            |> Enum.map(fn match ->
              {{matched_type, match.user_id}, match}
            end)
          end)
          |> List.flatten()
          |> Enum.sort_by(fn {_k, v} -> v.last_updated end, &<=/2)
          |> Map.new()

        stats_map =
          users
          |> Map.new(fn %{id: id} ->
            {id, Account.get_user_stat_data(id)}
          end)

        stats = Account.get_user_stat_data(user.id)

        conn
        |> add_breadcrumb(name: "List of possible smurf accounts", url: conn.request_path)
        |> assign(:all_user_keys, all_user_keys)
        |> assign(:key_count_by_type_name, key_count_by_type_name)
        |> assign(:user, user)
        |> assign(:stats, stats)
        |> assign(:params, search_defaults(conn))
        |> assign(:key_types, key_types)
        |> assign(:users, users)
        |> assign(:key_lookup, key_lookup)
        |> assign(:user_key_lookup, user_key_lookup)
        |> assign(:stats_map, stats_map)
        |> render("smurf_list.html")

      _ ->
        conn
        |> put_flash(:danger, "Unable to access this user")
        |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  @spec create_smurf_key(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create_smurf_key(conn, %{"userid" => userid, "key" => key, "value" => value}) do
    case Account.create_smurf_key(userid, key, value) do
      {:ok, _smurf_key} ->
        conn
        |> put_flash(:info, "Key added successfully.")
        |> redirect(to: ~p"/teiserver/admin/users/smurf_search/#{userid}")

      {:error, %Ecto.Changeset{} = _changeset} ->
        conn
        |> put_flash(:info, "Unable to add that key")
        |> redirect(to: ~p"/teiserver/admin/users/smurf_search/#{userid}")
    end
  end

  @spec delete_smurf_key(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete_smurf_key(conn, %{"id" => id}) do
    key = Account.get_smurf_key(id)

    if key do
      Account.delete_smurf_key(key)

      conn
      |> put_flash(:success, "Key deleted")
      |> redirect(to: Routes.ts_admin_user_path(conn, :smurf_search, key.user_id))
    else
      conn
      |> put_flash(:info, "Unable to find that key")
      |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  @spec mark_as_smurf_of(Plug.Conn.t(), map) :: Plug.Conn.t()
  def mark_as_smurf_of(conn, %{"smurf_id" => smurf_id, "origin_id" => origin_id}) do
    smurf_user = Account.get_user!(smurf_id)
    origin_user = Account.get_user!(origin_id)

    access = {
      Teiserver.Account.UserLib.has_access(smurf_user, conn),
      Teiserver.Account.UserLib.has_access(origin_user, conn)
    }

    case access do
      {{true, _}, {true, _}} ->
        # If the origin user has a smurf_id somehow then we just point to that
        origin_id = origin_user.smurf_of_id || origin_user.id
        {:ok, _} = Account.script_update_user(smurf_user, %{"smurf_of_id" => origin_id})

        Account.recache_user(smurf_user.id)

        add_audit_log(conn, "Moderation:Mark as smurf", %{
          smurf_userid: smurf_user.id,
          origin_id: origin_user.id
        })

        # Now we update stats for the origin
        smurf_count =
          Account.list_users(
            search: [
              smurf_of: origin_user.id
            ],
            select: [:id]
          )
          |> Enum.count()

        # And give the origin the smurfer role
        Teiserver.CacheUser.add_roles(origin_user.id, ["Smurfer"])
        Account.update_user_stat(origin_user.id, %{"smurf_count" => smurf_count})

        Teiserver.Client.disconnect(smurf_user.id, "Marked as smurf")

        conn
        |> put_flash(:success, "Applied the changes")
        |> redirect(to: ~p"/teiserver/admin/user/#{smurf_user.id}")

      _ ->
        conn
        |> put_flash(:danger, "Unable to access at least one of these users")
        |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  @spec cancel_smurf_mark(Plug.Conn.t(), map) :: Plug.Conn.t()
  def cancel_smurf_mark(conn, %{"user_id" => id}) do
    user = Account.get_user!(id)
    origin_user_id = user.smurf_of_id

    case Teiserver.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        case Account.script_update_user(user, %{"smurf_of_id" => nil}) do
          {:ok, user} ->
            add_audit_log(conn, "Moderation:Cancel smurf mark", %{
              smurf_userid: user.id,
              origin_id: user.smurf_of_id
            })

            # Now we update stats for the origin
            smurf_count =
              Account.list_users(
                search: [
                  smurf_of: origin_user_id
                ],
                select: [:id]
              )
              |> Enum.count()

            # And give the origin the smurfer role
            if smurf_count == 0 do
              Teiserver.CacheUser.remove_roles(origin_user_id, ["Smurfer"])
            end

            Account.update_user_stat(origin_user_id, %{"smurf_count" => smurf_count})

            conn
            |> put_flash(:info, "Smurf link broken.")
            |> redirect(to: ~p"/teiserver/admin/user/#{user.id}")

          {:error, %Ecto.Changeset{} = changeset} ->
            render(conn, "edit.html", user: user, changeset: changeset)
        end

      _ ->
        conn
        |> put_flash(:danger, "Unable to access this user")
        |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  @spec smurf_merge_form(Plug.Conn.t(), map) :: Plug.Conn.t()
  def smurf_merge_form(conn, %{"from_id" => from_id, "to_id" => to_id}) do
    from_user = Account.get_user!(from_id)
    to_user = Account.get_user!(to_id)

    access = {
      Teiserver.Account.UserLib.has_access(from_user, conn),
      Teiserver.Account.UserLib.has_access(to_user, conn)
    }

    case access do
      {{true, _}, {true, _}} ->
        conn
        |> add_breadcrumb(name: "Smurf merge form", url: conn.request_path)
        |> assign(:from_user, from_user)
        |> assign(:to_user, to_user)
        |> render("smurf_merge_form.html")

      _ ->
        conn
        |> put_flash(:danger, "Unable to access at least one of these users")
        |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  @spec smurf_merge_post(Plug.Conn.t(), map) :: Plug.Conn.t()
  def smurf_merge_post(conn, %{"from_id" => from_id, "to_id" => to_id, "merge" => merge}) do
    from_user = Account.get_user!(from_id)
    to_user = Account.get_user!(to_id)

    access = {
      Teiserver.Account.UserLib.has_access(from_user, conn),
      Teiserver.Account.UserLib.has_access(to_user, conn)
    }

    case access do
      {{true, _}, {true, _}} ->
        Teiserver.Account.SmurfMergeTask.perform(from_user.id, to_user.id, merge)

        fields =
          merge
          |> Enum.filter(fn {_k, v} -> v == "true" end)
          |> Enum.map(fn {k, _} -> k end)

        add_audit_log(conn, "Teiserver:Smurf merge", %{
          fields: fields,
          from_id: from_user.id,
          to_id: to_user.id
        })

        conn
        |> put_flash(:success, "Applied the changes")
        |> redirect(to: ~p"/teiserver/admin/user/#{to_user.id}")

      _ ->
        conn
        |> put_flash(:danger, "Unable to access at least one of these users")
        |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  @spec full_chat(Plug.Conn.t(), map) :: Plug.Conn.t()
  def full_chat(conn, %{"id" => id} = params) do
    page =
      Map.get(params, "page", 0)
      |> int_parse
      |> max(0)

    user = Account.get_user!(id)

    mode =
      case params["mode"] do
        "room" -> "room"
        _ -> "lobby"
      end

    messages =
      case mode do
        "lobby" ->
          Chat.list_lobby_messages(
            search: [
              user_id: user.id
            ],
            limit: 250,
            offset: page * 250,
            order_by: "Newest first"
          )

        "room" ->
          Chat.list_room_messages(
            search: [
              user_id: user.id
            ],
            limit: 250,
            offset: page * 250,
            order_by: "Newest first"
          )
      end

    last_page = Enum.count(messages) < 250

    conn
    |> assign(:last_page, last_page)
    |> assign(:page, page)
    |> assign(:user, user)
    |> assign(:mode, mode)
    |> assign(:messages, messages)
    |> add_breadcrumb(name: "Show: #{user.name}", url: ~p"/teiserver/admin/user/#{id}")
    |> add_breadcrumb(name: "Chat logs", url: conn.request_path)
    |> render("full_chat.html")
  end

  @spec relationships(Plug.Conn.t(), map) :: Plug.Conn.t()
  def relationships(conn, %{"id" => id}) do
    user = Account.get_user!(id)

    user_ids =
      (user.data["friends"] ++ user.data["friend_requests"] ++ user.data["ignored"])
      |> Enum.uniq()

    lookup =
      Account.list_users(search: [id_in: user_ids])
      |> Map.new(fn u -> {u.id, u} end)

    conn
    |> assign(:user, user)
    |> assign(:lookup, lookup)
    |> add_breadcrumb(name: "Show: #{user.name}", url: ~p"/teiserver/admin/user/#{id}")
    |> add_breadcrumb(name: "Relationships", url: conn.request_path)
    |> render("relationships.html")
  end

  @spec set_stat(Plug.Conn.t(), map) :: Plug.Conn.t()
  def set_stat(conn, %{"userid" => userid, "key" => key, "value" => value}) do
    user = Account.get_user!(userid)

    if value == "" do
      Account.delete_user_stat_keys(int_parse(userid), [key])
    else
      Account.update_user_stat(user.id, %{key => value})
    end

    Teiserver.Moderation.RefreshUserRestrictionsTask.refresh_user(user.id)
    Teiserver.CacheUser.recache_user(user.id)

    # Now we update stats for the origin
    smurf_count =
      Account.list_users(
        search: [
          smurf_of: user.id
        ],
        select: [:id]
      )
      |> Enum.count()

    Teiserver.Account.update_user_stat(user.id, %{"smurf_count" => smurf_count})

    conn
    |> put_flash(:success, "stat #{key} updated")
    |> redirect(to: ~p"/teiserver/admin/user/#{user.id}" <> "#details_tab")
  end

  @spec rename_form(Plug.Conn.t(), map) :: Plug.Conn.t()
  def rename_form(conn, %{"id" => id}) do
    user = Account.get_user(id)

    case Teiserver.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        conn
        |> assign(:user, user)
        |> add_breadcrumb(name: "Rename: #{user.name}", url: conn.request_path)
        |> render("rename_form.html")

      _ ->
        conn
        |> put_flash(:danger, "Unable to access this user")
        |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  @spec rename_post(Plug.Conn.t(), map) :: Plug.Conn.t()
  def rename_post(conn, %{"id" => id, "new_name" => new_name}) do
    user = Account.get_user(id)

    case Teiserver.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        admin_action = Teiserver.Account.AuthLib.allow?(conn, "admin.dev")

        case Teiserver.CacheUser.rename_user(user.id, new_name, admin_action) do
          :success ->
            add_audit_log(conn, "Teiserver:Changed user name", %{
              user_id: user.id,
              from: user.name,
              to: new_name
            })

            conn
            |> put_flash(:success, "User renamed")
            |> redirect(to: ~p"/teiserver/admin/user/#{user.id}")

          {:error, reason} ->
            conn
            |> assign(:user, user)
            |> put_flash(:danger, "Error with rename: #{reason}")
            |> add_breadcrumb(name: "Rename: #{user.name}", url: conn.request_path)
            |> render("rename_form.html")
        end

      _ ->
        conn
        |> put_flash(:danger, "Unable to access this user")
        |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  @spec applying(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def applying(conn, %{"id" => id} = params) do
    # Gives stuff time to happen
    :timer.sleep(500)

    tab =
      if params["tab"] do
        "##{params["tab"]}"
      else
        ""
      end

    conn
    |> redirect(to: ~p"/teiserver/admin/user/#{id}" <> tab)
  end

  @spec search_defaults(Plug.Conn.t()) :: Map.t()
  defp search_defaults(_conn) do
    %{
      "limit" => 50
    }
  end

  @spec gdpr_clean(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def gdpr_clean(conn, %{"id" => id}) do
    user = Account.get_user_by_id(id)

    case Teiserver.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        new_user =
          Map.merge(user, %{
            name: Ecto.UUID.generate(),
            email: "#{user.id}@#{user.id}",
            password: UserLib.make_bot_password(),
            country: "??"
          })

        Account.update_cache_user(user.id, new_user)

        Account.delete_user_stat_keys(user.id, [
          "country",
          "last_ip"
        ])

        conn
        |> put_flash(:success, "User GDPR cleaned")
        |> redirect(to: ~p"/teiserver/admin/user/#{user.id}")

      _ ->
        conn
        |> put_flash(:danger, "Unable to access this user")
        |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  @spec delete_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete_user(conn, %{"id" => id}) do
    if not Application.get_env(:teiserver, Teiserver)[:test_mode] do
      conn
      |> put_flash(:danger, "not in testmode")
      |> redirect(to: ~p"/teiserver/admin/user")
    end

    user = Account.get_user_by_id(id)

    case Teiserver.Account.UserLib.has_access(user, conn) do
      {true, _} ->
        case Teiserver.Admin.DeleteUserTask.delete_users([id]) do
          :ok ->
            conn
            |> put_flash(:success, "User deleted")
            |> redirect(to: ~p"/teiserver/admin/user/")
        end

      _ ->
        conn
        |> put_flash(:danger, "Unable to access this user")
        |> redirect(to: ~p"/teiserver/admin/user")
    end
  end

  def delete_user(conn, %{}) do
    # catch case, when no id is provided
    conn
    |> put_flash(:danger, "No user_id provided")
    |> redirect(to: ~p"/teiserver/admin/user")
  end
end
