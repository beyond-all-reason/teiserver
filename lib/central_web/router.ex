defmodule TeiserverWeb.Router do
  use CentralWeb, :router

  pipeline :dev_auth do
    plug Bodyguard.Plug.Authorize,
      policy: Central.Dev,
      action: :dev_auth,
      user: {Teiserver.Account.AuthLib, :current_user}
  end

  pipeline :logging_live_auth do
    plug Bodyguard.Plug.Authorize,
      policy: Teiserver.Logging.LiveLib,
      action: :live,
      user: {Teiserver.Account.AuthLib, :current_user}
  end

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug :put_root_layout, {CentralWeb.LayoutView, :root}
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(Teiserver.Account.DefaultsPlug)
    plug(Teiserver.Logging.LoggingPlug)
    plug(Teiserver.Account.AuthPipeline)
    plug(Teiserver.Account.AuthPlug)
    plug(Teiserver.Account.TSAuthPlug)
    plug(Central.General.CachePlug)
    plug(Teiserver.Communication.NotificationPlug)
  end

  pipeline :live_browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug :put_root_layout, {CentralWeb.Layouts, :root}
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(Teiserver.Account.DefaultsPlug)
    plug(Teiserver.Account.AuthPipeline)
    plug(Teiserver.Account.AuthPlug)
    plug(Teiserver.Account.TSAuthPlug)
    plug(Central.General.CachePlug)
    plug(Teiserver.Communication.NotificationPlug)
  end

  # layout: {CentralWeb.LayoutView, :standard_live}

  pipeline :standard_layout do
    plug(:put_layout, {CentralWeb.LayoutView, :standard})
  end

  pipeline :standard_live_layout do
    plug :put_layout, {CentralWeb.LayoutView, :standard_live}
  end

  pipeline :nomenu_layout do
    plug(:put_layout, {CentralWeb.LayoutView, :nomenu})
  end

  pipeline :nomenu_live_layout do
    plug(:put_layout, {CentralWeb.LayoutView, :nomenu_live})
  end

  pipeline :protected do
    plug(Guardian.Plug.EnsureAuthenticated)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :token_api do
    plug(:accepts, ["json"])
    plug(:put_secure_browser_headers)
    plug(Teiserver.Logging.LoggingPlug)
    plug(Teiserver.Account.AuthPipeline)
    plug(Teiserver.Account.AuthPlug)
    plug(Teiserver.Account.TSAuthPlug)
    plug(Central.General.CachePlug)
    plug(Guardian.Plug.EnsureAuthenticated)
  end

  pipeline :protected_api do
    plug(:accepts, ["json"])
    plug(:fetch_session)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(Teiserver.Logging.LoggingPlug)
    plug(Teiserver.Account.AuthPipeline)
    plug(Teiserver.Account.AuthPlug)
    plug(Teiserver.Account.TSAuthPlug)
    plug(Central.General.CachePlug)
    plug(Guardian.Plug.EnsureAuthenticated)
  end

  # Phoenix.Router.route_info(TeiserverWeb.Router, "GET", "/", "myhost")

  scope "/", TeiserverWeb.General do
    pipe_through([:live_browser, :nomenu_live_layout])

    live_session :general_index,
      on_mount: [
        {Teiserver.Account.AuthPlug, :ensure_authenticated},
        {Teiserver.Communication.NotificationPlug, :load_notifications}
      ] do
        live "/", HomeLive.Index, :index
    end
  end

  # scope "/", ApolloWeb do
  #   pipe_through [:browser, :require_authenticated_user]

  #   live_session :require_authenticated_user,
  #     on_mount: [{ApolloWeb.UserAuth, :ensure_authenticated}] do
  #     live "/users/settings", UserSettingsLive, :edit
  #     live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
  #   end
  # end


  # scope "/", ApolloWeb do
  #   pipe_through [:browser, :redirect_if_user_is_authenticated]

  #   live_session :redirect_if_user_is_authenticated,
  #     on_mount: [{ApolloWeb.UserAuth, :redirect_if_user_is_authenticated}] do
  #     live "/users/register", UserRegistrationLive, :new
  #     live "/users/log_in", UserLoginLive, :new
  #     live "/users/reset_password", UserForgotPasswordLive, :new
  #     live "/users/reset_password/:token", UserResetPasswordLive, :edit
  #   end

  #   post "/users/log_in", UserSessionController, :create
  # end

  scope "/", TeiserverWeb.Account, as: :account do
    pipe_through([:browser, :nomenu_layout])

    get("/login", SessionController, :new)
    post("/login", SessionController, :login)
    get("/logout", SessionController, :logout)
    post("/logout", SessionController, :logout)

    get("/forgot_password", SessionController, :forgot_password)
    post("/send_password_reset", SessionController, :send_password_reset)
    get("/password_reset/:value", SessionController, :password_reset_form)
    post("/password_reset/:value", SessionController, :password_reset_post)
    get("/one_time_login/:value", SessionController, :one_time_login)

    get("/initial_setup/:key", SetupController, :setup)
  end

  scope "/logging", TeiserverWeb.Logging, as: :logging do
    pipe_through([:browser, :protected, :standard_layout])

    get("/", GeneralController, :index)

    get("/audit/search", AuditLogController, :index)
    post("/audit/search", AuditLogController, :search)
    resources("/audit", AuditLogController, only: [:index, :show])

    get("/page_views/report", PageViewLogController, :report)
    post("/page_views/report", PageViewLogController, :report)
    get("/page_views/search", PageViewLogController, :index)
    post("/page_views/search", PageViewLogController, :search)
    resources("/page_views", PageViewLogController, only: [:index, :show, :delete])

    # Aggregate
    get("/aggregate_views", AggregateViewLogController, :index)
    get("/aggregate_views/show/:date", AggregateViewLogController, :show)
    get("/aggregate_views/perform", AggregateViewLogController, :perform_form)
    post("/aggregate_views/perform", AggregateViewLogController, :perform_post)

    # Game server logs
    get("/server/now", ServerLogController, :now)
    get("/server/load", ServerLogController, :load)
    get("/server/user_cost", ServerLogController, :user_cost)

    get("/server", ServerLogController, :metric_list)
    get("/server/:unit", ServerLogController, :metric_list)
    get("/server/show/:unit/today", ServerLogController, :metric_show_today)
    get("/server/show/:unit/:date", ServerLogController, :metric_show)

    # Match logs
    get("/match/day_metrics/today", MatchLogController, :day_metrics_today)
    get("/match/day_metrics/show/:date", MatchLogController, :day_metrics_show)
    get("/match/day_metrics/graph", MatchLogController, :day_metrics_graph)
    post("/match/day_metrics/graph", MatchLogController, :day_metrics_graph)
    get("/match/day_metrics", MatchLogController, :day_metrics_list)
    post("/match/day_metrics", MatchLogController, :day_metrics_list)
    get("/match/export_form", MatchLogController, :export_form)
    post("/match/export_post", MatchLogController, :export_post)

    get("/match/month_metrics/today", MatchLogController, :month_metrics_today)
    get("/match/month_metrics/show/:year/:month", MatchLogController, :month_metrics_show)
    get("/match/month_metrics/graph", MatchLogController, :month_metrics_graph)
    post("/match/month_metrics/graph", MatchLogController, :month_metrics_graph)
    get("/match/month_metrics", MatchLogController, :month_metrics_list)
    post("/match/month_metrics", MatchLogController, :month_metrics_list)
  end

  scope "/communication", TeiserverWeb.Communication, as: :communication do
    pipe_through([:browser, :protected, :standard_layout])

    get("/notifications/delete_all", NotificationController, :delete_all)
    get("/notifications/mark_all", NotificationController, :mark_all)
    resources("/notifications", NotificationController, only: [:index, :delete])
  end

  # Live dashboard
  import Phoenix.LiveDashboard.Router

  scope "/logging/live", TeiserverWeb, as: :logging_live do
    pipe_through([:browser, :protected, :standard_layout, :logging_live_auth])

    live_dashboard("/dashboard",
      metrics: TeiserverWeb.Telemetry,
      ecto_repos: [Teiserver.Repo],
      additional_pages: [
        # live_dashboard_additional_pages
      ]
    )
  end

  scope "/", TeiserverWeb.General, as: :ts_general do
    pipe_through([:browser, :nomenu_layout])

    get("/code_of_conduct", GeneralController, :code_of_conduct)
    get("/privacy_policy", GeneralController, :gdpr)
    get("/gdpr", GeneralController, :gdpr)
  end

  # ts_account_X_path
  scope "/teiserver/account", TeiserverWeb.Account, as: :ts_account do
    pipe_through([:browser, :standard_layout, :protected])

    get("/relationships", RelationshipsController, :index)
    post("/relationships/find/", RelationshipsController, :find)
    post("/relationships/create/:action/:target", RelationshipsController, :create)
    put("/relationships/update/:action/:target", RelationshipsController, :update)
    delete("/relationships/delete/:action/:target", RelationshipsController, :delete)

    resources("/preferences", PreferencesController, only: [:index, :edit, :update, :new, :create])

    get("/", GeneralController, :index)
    get("/customisation_form", GeneralController, :customisation_form)
    get("/customisation_select/:role", GeneralController, :customisation_select)

    get("/details", GeneralController, :edit_details)
    put("/update_details", GeneralController, :update_details)

    get("/security", SecurityController, :index)
    get("/security/edit_password", SecurityController, :edit_password)
    put("/security/update_password", SecurityController, :update_password)
    delete("/security/delete_token/:id", SecurityController, :delete_token)
  end

  scope "/teiserver", TeiserverWeb.Account, as: :ts_account do
    pipe_through([:browser, :standard_layout])

    get("/profile/:id", ProfileController, :show)
    get("/profile", ProfileController, :index)
  end

  # ts_clans_X_path
  scope "/teiserver/clans", TeiserverWeb.Clans, as: :ts_clans do
    pipe_through([:browser, :standard_layout, :protected])

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
    put("/leave_clan/:clan_id", ClanController, :leave_clan)
  end

  scope "/teiserver/games", TeiserverWeb.Game, as: :ts_game do
    pipe_through([:browser, :standard_layout, :protected])
    resources("/queues", QueueController)
  end

  scope "/battle", TeiserverWeb.Battle.LobbyLive, as: :ts_battle do
    pipe_through([:browser, :standard_layout, :protected])

    live("/lobbies", Index, :index)
    live("/lobbies/show/:id", Show, :show)
    live("/lobbies/chat/:id", Chat, :chat)
  end

  scope "/battle", TeiserverWeb.Battle, as: :ts_battle do
    pipe_through([:browser, :standard_layout, :protected])

    get("/ratings/leaderboard", RatingsController, :leaderboard)
    get("/ratings/leaderboard/:type", RatingsController, :leaderboard)

    get("/progression", MatchController, :ratings_graph)

    live_session :board_view,
      on_mount: [
        {Teiserver.Account.AuthPlug, :ensure_authenticated},
        {Teiserver.Communication.NotificationPlug, :load_notifications}
      ] do
        live "/ratings", MatchLive.Ratings, :index
        live "/ratings/:rating_type", MatchLive.Ratings, :index

        live "/chat/:id", MatchLive.Chat, :index
        live "/chat/:id/*userids", MatchLive.Chat, :index

        live "/", MatchLive.Index, :index
        live "/:id", MatchLive.Show, :overview
        live "/:id/overview", MatchLive.Show, :overview
        live "/:id/players", MatchLive.Show, :players
        live "/:id/ratings", MatchLive.Show, :ratings
        live "/:id/balance", MatchLive.Show, :balance
    end
  end

  scope "/tournament", TeiserverWeb.TournamentLive, as: :tournament do
    pipe_through([:browser, :standard_layout, :protected])

    live("/lobbies", Index, :index)
    live("/lobbies/show/:id", Show, :show)
  end

  scope "/teiserver/matchmaking", TeiserverWeb.Matchmaking.QueueLive, as: :ts_game do
    pipe_through([:browser, :standard_layout, :protected])

    live("/queues", Index, :index)
    live("/queues/:id", Show, :show)
  end

  scope "/teiserver/account", TeiserverWeb.Account.PartyLive, as: :ts_game do
    pipe_through([:browser, :standard_layout, :protected])

    live("/parties", Index, :index)
    live("/parties/:mode", Index, :index)
    live("/parties/show/:id", Show, :show)
  end

  scope "/telemetry", TeiserverWeb.Telemetry do
    pipe_through([:browser, :standard_layout, :protected])

    get("/", GeneralController, :index)

    # Properties
    get("/properties/export/form", PropertyController, :export_form)
    post("/properties/export/post", PropertyController, :export_post)
    get("/properties/summary", PropertyController, :summary)
    get("/properties/:property_name/detail", PropertyController, :detail)

    # Client events
    get("/client_events/export/form", ClientEventController, :export_form)
    post("/client_events/export/post", ClientEventController, :export_post)
    get("/client_events/summary", ClientEventController, :summary)
    get("/client_events/:event_name/detail", ClientEventController, :detail)

    # Server events
    get("/server_events/export/form", ServerEventController, :export_form)
    post("/server_events/export/post", ServerEventController, :export_post)
    get("/server_events/summary", ServerEventController, :summary)
    get("/server_events/:event_name/detail", ServerEventController, :detail)

    # Match events
    get("/match_events/export/form", MatchEventController, :export_form)
    post("/match_events/export/post", MatchEventController, :export_post)
    get("/match_events/summary", MatchEventController, :summary)
    get("/match_events/:event_name/detail", MatchEventController, :detail)
  end

  scope "/teiserver/reports", TeiserverWeb.Report, as: :ts_reports do
    pipe_through([:browser, :standard_layout, :protected])

    get("/", GeneralController, :index)

    get("/infolog/download/:id", InfologController, :download)
    get("/infolog/search", InfologController, :index)
    post("/infolog/search", InfologController, :search)
    resources("/infolog", InfologController, only: [:index, :show, :delete])

    post("/exports/:id", ExportsController, :download)
    resources("/exports", ExportsController, only: [:index, :show])

    get("/show/:name", ReportController, :show)
    post("/show/:name", ReportController, :show)

    # Ratings
    get("/ratings/balance_tester", RatingController, :balance_tester)
    post("/ratings/balance_tester", RatingController, :balance_tester)

    get("/ratings/distribution_table", RatingController, :distribution_table)
    post("/ratings/distribution_table", RatingController, :distribution_table)
    get("/ratings/distribution_graph", RatingController, :distribution_graph)
    post("/ratings/distribution_graph", RatingController, :distribution_graph)
  end

  # API
  scope "/tachyon", TeiserverWeb.API do
    pipe_through :api
    post "/login", SessionController, :login
    post "/register", SessionController, :register
    post "/request_token", SessionController, :request_token
    get "/request_token", SessionController, :request_token_get
  end

  scope "/teiserver/api", TeiserverWeb.API do
    pipe_through :api
    post "/login", SessionController, :login
    post "/register", SessionController, :register
    post "/request_token", SessionController, :request_token
    get "/request_token", SessionController, :request_token_get
  end

  scope "/teiserver/api/hailstorm", TeiserverWeb.API, as: :ts do
    pipe_through([:api])
    post("/start", HailstormController, :start)
    post("/update_site_config", HailstormController, :update_site_config)
    post("/create_user", HailstormController, :create_user)
    post("/db_update_user", HailstormController, :db_update_user)
    post("/ts_update_user", HailstormController, :ts_update_user)
    post("/update_user_rating", HailstormController, :update_user_rating)
    post("/get_server_state", HailstormController, :get_server_state)
  end

  scope "/teiserver/api/spads", TeiserverWeb.API, as: :ts do
    pipe_through([:api])
    get "/get_rating/:target_id/:type", SpadsController, :get_rating
    get "/get_rating/:caller_id/:target_id/:type", SpadsController, :get_rating

    get "/balance_battle", SpadsController, :balance_battle
    post "/balance_battle", SpadsController, :balance_battle
  end

  scope "/teiserver/api/public", TeiserverWeb.API, as: :ts do
    pipe_through([:api])
    get "/leaderboard/:type", PublicController, :leaderboard
  end

  scope "/teiserver/api", TeiserverWeb.API do
    pipe_through([:token_api])

    post "/battle/create", BattleController, :create
  end

  # ADMIN
  scope "/admin", TeiserverWeb.AdminDashLive, as: :ts do
    pipe_through([:browser, :standard_layout, :protected])

    live("/dashboard", Index, :index)
    live("/dashboard/login_throttle", LoginThrottle, :index)
    live("/dashboard/policy/:id", Policy, :policy)
  end

  scope "/teiserver/admin", TeiserverWeb.ClientLive, as: :ts_admin do
    pipe_through([:browser, :standard_layout, :protected])

    live("/client", Index, :index)
    live("/client/:id", Show, :show)
  end

  scope "/teiserver/admin", TeiserverWeb.PartyLive, as: :ts_admin do
    pipe_through([:browser, :standard_layout, :protected])

    live("/party", Index, :index)
    live("/party/:id", Show, :show)
  end

  scope "/teiserver/admin", TeiserverWeb.AgentLive, as: :ts_admin do
    pipe_through([:browser, :standard_layout, :protected])

    live("/agent", Index, :index)
    # live("/agent/:id", Show, :show)
  end

  scope "/moderation", TeiserverWeb.Moderation do
    pipe_through([:browser, :standard_live_layout])

    live_session :overwatch,
      on_mount: [
        {Teiserver.Account.AuthPlug, :ensure_authenticated},
        {Teiserver.Communication.NotificationPlug, :load_notifications}
      ] do
        live "/overwatch", OverwatchLive.Index, :index
    end
  end

  scope "/moderation", TeiserverWeb.Moderation, as: :moderation do
    pipe_through([:browser, :standard_layout, :protected])

    get("/", GeneralController, :index)

    get("/report/search", ReportController, :search)
    post("/report/search", ReportController, :search)
    get("/report/user/:id", ReportController, :user)
    resources("/report", ReportController, only: [:index, :show, :delete])
    post("/report/:id/respond", ReportController, :respond)
    put("/report/:id/respond", ReportController, :respond)
    put("/report/:id/close", ReportController, :close)
    put("/report/:id/open", ReportController, :open)

    get("/action/search", ActionController, :search)
    post("/action/search", ActionController, :search)
    get("/action/new_with_user", ActionController, :new_with_user)
    put("/action/halt/:id", ActionController, :halt)
    put("/action/re-post/:id", ActionController, :re_post)

    resources("/action", ActionController,
      only: [:index, :show, :new, :create, :edit, :update, :delete]
    )

    get("/proposal/new_with_user", ProposalController, :new_with_user)
    put("/proposal/vote/:proposal_id/:direction", ProposalController, :vote)

    resources("/proposal", ProposalController,
      only: [:index, :show, :new, :create, :edit, :update]
    )

    post("/proposal/:id/conclude", ProposalController, :conclude)

    put("/ban/:id/disable", BanController, :disable)
    put("/ban/:id/enable", BanController, :enable)
    get("/ban/new_with_user", BanController, :new_with_user)
    resources("/ban", BanController, only: [:index, :show, :new, :create, :edit, :update])

    get("/report_form/success", ReportFormController, :success)
    post("/report_form", ReportFormController, :create)
    get("/report_form/:id", ReportFormController, :index)
  end

  scope "/admin", TeiserverWeb.Admin, as: :admin do
    pipe_through([:browser, :standard_layout, :protected])

    resources("/lobby_policies", LobbyPolicyController,
      only: [:index, :new, :create, :show, :edit, :update, :delete]
    )

    resources("/text_callbacks", TextCallbackController,
      only: [:index, :new, :create, :show, :edit, :update, :delete]
    )
  end

  scope "/teiserver/admin", TeiserverWeb.Admin, as: :admin do
    pipe_through([:browser, :standard_layout, :protected])

    # Codes
    resources("/codes", CodeController)
    put("/codes/extend/:id/:hours", CodeController, :extend)

    # Config
    resources("/site", SiteConfigController, only: [:index, :edit, :update, :delete])
  end

  scope "/teiserver/admin", TeiserverWeb.Admin, as: :ts_admin do
    pipe_through([:browser, :standard_layout, :protected])

    get("/", GeneralController, :index)
    get("/metrics", GeneralController, :metrics)

    get("/tools", ToolController, :index)
    get("/tools/falist", ToolController, :falist)
    get("/tools/test_page", ToolController, :test_page)

    post("/clans/create_membership", ClanController, :create_membership)
    delete("/clans/delete_membership/:clan_id/:user_id", ClanController, :delete_membership)
    delete("/clans/delete_invite/:clan_id/:user_id", ClanController, :delete_invite)
    put("/clans/promote/:clan_id/:user_id", ClanController, :promote)
    put("/clans/demote/:clan_id/:user_id", ClanController, :demote)
    resources("/clans", ClanController)

    get("/users/rename_form/:id", UserController, :rename_form)
    put("/users/rename_post/:id", UserController, :rename_post)
    get("/users/reset_password/:id", UserController, :reset_password)
    get("/users/relationships/:id", UserController, :relationships)
    get("/users/action/:id/:action", UserController, :perform_action)
    put("/users/action/:id/:action", UserController, :perform_action)
    get("/users/smurf_search/:id", UserController, :smurf_search)

    put("/users/mark_as_smurf_of/:smurf_id/:origin_id", UserController, :mark_as_smurf_of)
    delete("/users/cancel_smurf_mark/:user_id", UserController, :cancel_smurf_mark)

    get("/users/smurf_merge_form/:from_id/:to_id", UserController, :smurf_merge_form)
    post("/users/smurf_merge_post/:from_id/:to_id", UserController, :smurf_merge_post)
    delete("/users/delete_smurf_key/:id", UserController, :delete_smurf_key)
    get("/users/full_chat/:id", UserController, :full_chat)
    get("/users/full_chat/:id/:page", UserController, :full_chat)
    get("/users/search", UserController, :index)
    post("/users/set_stat", UserController, :set_stat)
    get("/users/data_search", UserController, :data_search)
    post("/users/data_search", UserController, :data_search)
    post("/users/search", UserController, :search)
    get("/users/applying/:id", UserController, :applying)
    get("/users/ratings_form/:id", UserController, :ratings_form)
    post("/users/ratings_post/:id", UserController, :ratings_post)
    get("/users/ratings/:id", UserController, :ratings)
    resources("/user", UserController)

    resources("/badge_types", BadgeTypeController)
    resources("/accolades", AccoladeController, only: [:index, :show, :delete])
    get("/accolades/user/:user_id", AccoladeController, :user_show)

    get("/matches/by_server/:uuid", MatchController, :server_index)
    get("/matches/search", MatchController, :index)
    post("/matches/search", MatchController, :search)
    get("/matches/user/:user_id", MatchController, :user_show)
    resources("/matches", MatchController, only: [:index, :show, :delete])

    resources("/chat", ChatController, only: [:index])
    post("/chat", ChatController, :index)

    resources("/achievements", AchievementController)

    get("/lobbies/:id/server_chat/download", LobbyController, :server_chat_download)
    get("/lobbies/:id/server_chat", LobbyController, :server_chat)
    get("/lobbies/:id/server_chat/:page", LobbyController, :server_chat)
    get("/lobbies/:id/lobby_chat/download", LobbyController, :lobby_chat_download)
    get("/lobbies/:id/lobby_chat", LobbyController, :lobby_chat)
    get("/lobbies/:id/lobby_chat/:page", LobbyController, :lobby_chat)
  end
end
