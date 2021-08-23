defmodule TeiserverWeb.Router do
  defmacro __using__(_opts \\ []) do
    quote do
      import unquote(__MODULE__)
    end
  end

  defmacro teiserver_routes() do
    quote do
      scope "/", TeiserverWeb.General, as: :ts_general do
        pipe_through([:browser, :blank_layout])

        get("/gdpr", GeneralController, :gdpr)
        get("/privacy_policy", GeneralController, :gdpr)
      end

      scope "/teiserver", TeiserverWeb.General, as: :ts_general do
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
        put("/update/:clan_id", ClanController, :update)

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

      scope "/teiserver/battle", TeiserverWeb.Battle, as: :ts_battle do
        pipe_through([:browser, :admin_layout, :protected])

        resources("/matches", MatchController, only: [:index, :show, :delete])
      end

      scope "/teiserver/battle", TeiserverWeb.Battle.LobbyLive, as: :ts_battle do
        pipe_through([:browser, :admin_layout, :protected])

        live("/lobbies", Index, :index)
        live("/lobbies/:id", Show, :show)
      end

      # REPORTING
      scope "/teiserver/reports", TeiserverWeb.Report, as: :ts_reports do
        pipe_through([:browser, :admin_layout, :protected])

        get("/", GeneralController, :index)

        get("/day_metrics/today", MetricController, :day_metrics_today)
        get("/day_metrics/show/:date", MetricController, :day_metrics_show)
        get("/day_metrics/export/:date", MetricController, :day_metrics_export)
        get("/day_metrics/graph", MetricController, :day_metrics_graph)
        post("/day_metrics/graph", MetricController, :day_metrics_graph)
        get("/day_metrics", MetricController, :day_metrics_list)
        post("/day_metrics", MetricController, :day_metrics_list)

        get("/client_events/export/form", ClientEventController, :export_form)
        post("/client_events/export/post", ClientEventController, :export_post)
        get("/client_events/summary", ClientEventController, :summary)
        get("/client_events/property/:property_name/detail", ClientEventController, :property_detail)
        get("/client_events/event/:event_name/detail", ClientEventController, :event_detail)

        get("/show/:name", ReportController, :show)
        post("/show/:name", ReportController, :show)
      end

      # ts_engine_X_path
      scope "/teiserver/engine", TeiserverWeb.Engine, as: :ts_engine do
        pipe_through([:browser, :admin_layout, :protected])

        resources("/unit", UnitController)
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

        post("/clans/create_membership", ClanController, :create_membership)
        delete("/clans/delete_membership/:clan_id/:user_id", ClanController, :delete_membership)
        delete("/clans/delete_invite/:clan_id/:user_id", ClanController, :delete_invite)
        put("/clans/promote/:clan_id/:user_id", ClanController, :promote)
        put("/clans/demote/:clan_id/:user_id", ClanController, :demote)
        resources("/clans", ClanController)

        resources("/parties", PartyController)

        resources("/queues", QueueController)

        # resources("/tournaments", TournamentController)

        get("/users/reset_password/:id", UserController, :reset_password)
        get("/users/action/:id/:action", UserController, :perform_action)
        put("/users/action/:id/:action", UserController, :perform_action)
        get("/users/reports/:id/respond", UserController, :respond_form)
        put("/users/reports/:id/respond", UserController, :respond_post)
        get("/users/smurf_search/:id", UserController, :smurf_search)
        get("/users/search", UserController, :index)
        post("/users/search", UserController, :search)
        resources("/user", UserController)
      end
    end
  end
end
