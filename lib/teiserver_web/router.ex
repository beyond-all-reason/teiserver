defmodule TeiserverWeb.Router do
  defmacro __using__(_opts \\ []) do
    quote do
      import unquote(__MODULE__)
    end
  end

  defmacro teiserver_routes() do
    quote do
      scope "/", TeiserverWeb.Lobby, as: :ts_lobby do
        pipe_through([:browser, :blank_layout])

        get("/gdpr", GeneralController, :gdpr)
        get("/privacy_policy", GeneralController, :gdpr)
      end

      scope "/teiserver", TeiserverWeb.Lobby, as: :ts_lobby do
        pipe_through([:browser, :admin_layout, :protected])

        get("/", GeneralController, :index)
      end

      # ts_account_X_path
      scope "/teiserver/account", TeiserverWeb.Account, as: :ts_account do
        pipe_through([:browser, :admin_layout, :protected])

        get("/relationships", RelationshipsController, :index)
        post("/relationships/find/", RelationshipsController, :find)
        post("/relationships/create/:action/:target", RelationshipsController, :create)
        put("/relationships/update/:action/:target", RelationshipsController, :update)
        delete("/relationships/delete/:action/:target", RelationshipsController, :delete)

        resources("/preferences", PreferencesController,
          only: [:index, :edit, :update, :new, :create]
        )

        get("/", GeneralController, :index)
      end

      # ts_clans_X_path
      scope "/teiserver/clans", TeiserverWeb.Clans, as: :ts_clans do
        pipe_through([:browser, :admin_layout, :protected])

        get("/", ClanController, :index)
        get("/:name", ClanController, :show)

        get("/set_default/:id", ClanController, :set_default)
        post("/create_invite", ClanController, :create_invite)
        delete("/delete_invite/:clan_id/:user_id", ClanController, :delete_invite)
        put("/respond_to_invite/:clan_id/:response", ClanController, :respond_to_invite)
        delete("/delete_membership/:clan_id/:user_id", ClanController, :delete_membership)
        put("/promote/:clan_id/:user_id", ClanController, :promote)
        put("/demote/:clan_id/:user_id", ClanController, :demote)
      end

      scope "/teiserver/games", TeiserverWeb.Game, as: :ts_game do
        resources("/tournaments", TournamentController)
      end

      scope "/teiserver/battle", TeiserverWeb.Battle, as: :ts_battle do
        pipe_through([:browser, :admin_layout, :protected])

        get("/", GeneralController, :index)
      end

      scope "/teiserver/battle", TeiserverWeb.Battle, as: :ts do
        pipe_through([:browser, :admin_layout, :protected])

        resources("/logs", BattleLogController, only: [:index, :show, :delete])
      end

      scope "/teiserver/battle", TeiserverWeb.Battle.BattleLobbyLive, as: :ts do
        pipe_through([:browser, :admin_layout, :protected])

        live("/lobbies", Index, :index)
        live("/lobbies/:id", Show, :show)
      end


      # API
      scope "/teiserver/api", TeiserverWeb.API do
        pipe_through :api
        post "/login", SessionController, :login
      end

      scope "/teiserver/api", TeiserverWeb.API do
        pipe_through([:token_api])
        post "/battle/create", BattleController, :create
      end

      # ADMIN
      scope "/teiserver/admin", TeiserverWeb.ClientLive, as: :ts_admin do
        pipe_through([:browser, :admin_layout, :protected])

        live("/client", Index, :index)
        live("/client/:id", Show, :show)
      end

      scope "/teiserver/admin_live", TeiserverWeb.MatchmakingLive, as: :ts_admin do
        pipe_through([:browser, :admin_layout, :protected])

        live("/queues", Index, :index)
        live("/queues/:id", Show, :show)
      end

      scope "/teiserver/admin", TeiserverWeb.AgentLive, as: :ts_admin do
        pipe_through([:browser, :admin_layout, :protected])

        live("/agent", Index, :index)
        # live("/agent/:id", Show, :show)
      end

      scope "/teiserver/admin", TeiserverWeb.Admin, as: :ts_admin do
        pipe_through([:browser, :admin_layout, :protected])

        get("/", GeneralController, :index)
        get("/metrics", GeneralController, :metrics)

        get("/tools", ToolController, :index)
        get("/tools/convert", ToolController, :convert_form)
        post("/tools/convert_post", ToolController, :convert_post)

        get("/tools/day_metrics/today", ToolController, :day_metrics_today)
        get("/tools/day_metrics/show/:date", ToolController, :day_metrics_show)
        get("/tools/day_metrics/export/:date", ToolController, :day_metrics_export)
        get("/tools/day_metrics", ToolController, :day_metrics_list)
        post("/tools/day_metrics", ToolController, :day_metrics_list)

        post("/clans/create_membership", ClanController, :create_membership)
        delete("/clans/delete_membership/:clan_id/:user_id", ClanController, :delete_membership)
        delete("/clans/delete_invite/:clan_id/:user_id", ClanController, :delete_invite)
        put("/clans/promote/:clan_id/:user_id", ClanController, :promote)
        put("/clans/demote/:clan_id/:user_id", ClanController, :demote)
        resources("/clans", ClanController)

        resources("/parties", PartyController)

        resources("/queues", QueueController)

        # resources("/tournaments", TournamentController)

        post("/user/reset_password/:id", UserController, :reset_password)
        get("/user/action/:id/:action", UserController, :perform_action)
        put("/user/action/:id/:action", UserController, :perform_action)
        get("/user/reports/:id/respond", UserController, :respond_form)
        put("/user/reports/:id/respond", UserController, :respond_post)
        get("/users/search", UserController, :index)
        post("/users/search", UserController, :search)
        resources("/user", UserController)
      end
    end
  end
end
