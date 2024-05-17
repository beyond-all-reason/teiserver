defmodule TeiserverWeb.Router do
  use TeiserverWeb, :router

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
    plug :put_root_layout, {TeiserverWeb.Layouts, :root}
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(Teiserver.Account.DefaultsPlug)
    plug(Teiserver.Logging.LoggingPlug)
    plug(Teiserver.Account.AuthPipeline)
    plug(Teiserver.Account.AuthPlug)
    plug(Teiserver.Plugs.CachePlug)
  end

  pipeline :live_browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug :put_root_layout, {TeiserverWeb.Layouts, :root}
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(Teiserver.Account.DefaultsPlug)
    plug(Teiserver.Account.AuthPipeline)
    plug(Teiserver.Account.AuthPlug)
    plug(Teiserver.Plugs.CachePlug)
  end

  pipeline :app_layout do
    plug(:put_layout, {TeiserverWeb.Layouts, :app})
  end

  pipeline :nomenu_layout do
    plug(:put_layout, {TeiserverWeb.Layouts, :root})
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
    plug(Teiserver.Plugs.CachePlug)
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
    plug(Teiserver.Plugs.CachePlug)
    plug(Guardian.Plug.EnsureAuthenticated)
  end

  scope "/", TeiserverWeb.General do
    pipe_through([:live_browser, :nomenu_layout])

    live_session :general_index,
      on_mount: [
        {Teiserver.Account.AuthPlug, :ensure_authenticated}
      ] do
      live "/", HomeLive.Index, :index
    end
  end

  scope "/microblog", TeiserverWeb.Microblog do
    pipe_through([:live_browser, :app_layout])

    live_session :microblog_root,
      on_mount: [
        {Teiserver.Account.AuthPlug, :mount_current_user}
      ] do
      live "/", BlogLive.Index, :index
      live "/all", BlogLive.Index, :all
      live "/show/:post_id", BlogLive.Show, :index
    end

    live_session :microblog_user,
      on_mount: [
        {Teiserver.Account.AuthPlug, :ensure_authenticated}
      ] do
      live "/preferences", BlogLive.Preferences, :index
    end

    live_session :microblog_admin,
      on_mount: [
        {Teiserver.Account.AuthPlug, :ensure_authenticated},
        {Teiserver.Account.AuthPlug, {:authorise, "Contributor"}}
      ] do
      live "/admin/posts", Admin.PostLive.Index, :index
      live "/admin/posts/:id", Admin.PostLive.Show, :show

      live "/admin/tags", Admin.TagLive.Index, :index
      live "/admin/tags/:id", Admin.TagLive.Show, :show
    end
  end

  scope "/microblog", TeiserverWeb.Microblog do
    get "/rss", RssController, :index
    get "/rss/html", RssController, :html_mode
  end

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
    pipe_through([:browser, :protected, :app_layout])

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

  # Live dashboard
  import Phoenix.LiveDashboard.Router

  scope "/logging/live", TeiserverWeb, as: :logging_live do
    pipe_through([:browser, :protected, :app_layout, :logging_live_auth])

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

  scope "/account", TeiserverWeb.Account do
    pipe_through([:live_browser, :app_layout, :protected])

    live_session :relationships,
      on_mount: [
        {Teiserver.Account.AuthPlug, :ensure_authenticated}
      ] do
      live "/relationship", RelationshipLive.Index, :friend
      live "/relationship/friend", RelationshipLive.Index, :friend
      live "/relationship/follow", RelationshipLive.Index, :follow
      live "/relationship/avoid", RelationshipLive.Index, :avoid
      live "/relationship/search", RelationshipLive.Index, :search
    end

    live_session :account_settings,
      on_mount: [
        {Teiserver.Account.AuthPlug, :ensure_authenticated}
      ] do
      live "/settings", SettingsLive.Index, :index
      live "/settings/:key", SettingsLive.Index, :selected
    end
  end

  scope "/profile", TeiserverWeb.Account do
    pipe_through([:browser, :app_layout])

    live_session :profiles,
      on_mount: [
        {Teiserver.Account.AuthPlug, :mount_current_user}
      ] do
      live "/", ProfileLive.Self, :index
      live "/name/:username", ProfileLive.Username, :index

      live "/:userid", ProfileLive.Overview, :overview
      live "/:userid/overview", ProfileLive.Overview, :overview
      live "/:userid/accolades", ProfileLive.Accolades, :accolades
      live "/:userid/matches", ProfileLive.Matches, :matches
      live "/:userid/playtime", ProfileLive.Playtime, :playtime
      live "/:userid/achievements", ProfileLive.Achievements, :achievements
      live "/:userid/appearance", ProfileLive.Appearance, :appearance
      live "/:userid/relationships", ProfileLive.Relationships, :relationships
      live "/:userid/contributor", ProfileLive.Contributor, :contributor
    end
  end

  scope "/teiserver/account", TeiserverWeb.Account, as: :ts_account do
    pipe_through([:browser, :app_layout, :protected])

    get("/details", GeneralController, :edit_details)
    put("/update_details", GeneralController, :update_details)

    get("/security", SecurityController, :index)
    get("/security/edit_password", SecurityController, :edit_password)
    put("/security/update_password", SecurityController, :update_password)
    delete("/security/delete_token/:id", SecurityController, :delete_token)
  end

  scope "/teiserver/games", TeiserverWeb.Game, as: :ts_game do
    pipe_through([:browser, :app_layout, :protected])
    resources("/queues", QueueController)
  end

  scope "/battle", TeiserverWeb.Battle.LobbyLive, as: :ts_battle do
    pipe_through([:browser, :app_layout, :protected])

    live("/lobbies", Index, :index)
    live("/lobbies/show/:id", Show, :show)
    live("/lobbies/chat/:id", Chat, :chat)
  end

  scope "/battle", TeiserverWeb.Battle, as: :ts_battle do
    pipe_through([:browser, :app_layout, :protected])

    get("/ratings/leaderboard", RatingsController, :leaderboard)
    get("/ratings/leaderboard/:type", RatingsController, :leaderboard)

    get("/progression", MatchController, :ratings_graph)

    live_session :board_view,
      on_mount: [
        {Teiserver.Account.AuthPlug, :ensure_authenticated}
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
    pipe_through([:browser, :app_layout, :protected])

    live("/lobbies", Index, :index)
    live("/lobbies/show/:id", Show, :show)
  end

  scope "/teiserver/matchmaking", TeiserverWeb.Matchmaking.QueueLive, as: :ts_game do
    pipe_through([:browser, :app_layout, :protected])

    live("/queues", Index, :index)
    live("/queues/:id", Show, :show)
  end

  scope "/teiserver/account", TeiserverWeb.Account.PartyLive, as: :ts_game do
    pipe_through([:browser, :app_layout, :protected])

    live("/parties", Index, :index)
    live("/parties/:mode", Index, :index)
    live("/parties/show/:id", Show, :show)
  end

  scope "/telemetry", TeiserverWeb.Telemetry do
    pipe_through([:browser, :app_layout, :protected])

    get("/", GeneralController, :index)

    # Properties
    get("/properties/export/form", PropertyController, :export_form)
    post("/properties/export/post", PropertyController, :export_post)
    get("/properties/summary", PropertyController, :summary)
    get("/properties/:property_name/detail", PropertyController, :detail)

    # Client events
    get("/simple_client_events/export/form", SimpleClientEventController, :export_form)
    post("/simple_client_events/export/post", SimpleClientEventController, :export_post)
    get("/simple_client_events/summary", SimpleClientEventController, :summary)
    get("/simple_client_events/:event_name/detail", SimpleClientEventController, :detail)

    get("/complex_client_events/export/form", ComplexClientEventController, :export_form)
    post("/complex_client_events/export/post", ComplexClientEventController, :export_post)
    get("/complex_client_events/summary", ComplexClientEventController, :summary)
    get("/complex_client_events/:event_name/detail", ComplexClientEventController, :detail)

    # Server events
    get("/simple_server_events/export/form", SimpleServerEventController, :export_form)
    post("/simple_server_events/export/post", SimpleServerEventController, :export_post)
    get("/simple_server_events/summary", SimpleServerEventController, :summary)
    get("/simple_server_events/:event_name/detail", SimpleServerEventController, :detail)

    get("/complex_server_events/export/form", ComplexServerEventController, :export_form)
    post("/complex_server_events/export/post", ComplexServerEventController, :export_post)
    get("/complex_server_events/summary", ComplexServerEventController, :summary)
    get("/complex_server_events/:event_name/detail", ComplexServerEventController, :detail)

    # Match events
    get("/simple_match_events/export/form", SimpleMatchEventController, :export_form)
    post("/simple_match_events/export/post", SimpleMatchEventController, :export_post)
    get("/simple_match_events/summary", SimpleMatchEventController, :summary)
    get("/simple_match_events/:event_name/detail", SimpleMatchEventController, :detail)

    get("/complex_match_events/export/form", ComplexMatchEventController, :export_form)
    post("/complex_match_events/export/post", ComplexMatchEventController, :export_post)
    get("/complex_match_events/summary", ComplexMatchEventController, :summary)
    get("/complex_match_events/:event_name/detail", ComplexMatchEventController, :detail)

    # Lobby events
    get("/simple_lobby_events/export/form", SimpleLobbyEventController, :export_form)
    post("/simple_lobby_events/export/post", SimpleLobbyEventController, :export_post)
    get("/simple_lobby_events/summary", SimpleLobbyEventController, :summary)
    get("/simple_lobby_events/:event_name/detail", SimpleLobbyEventController, :detail)

    get("/complex_lobby_events/export/form", ComplexLobbyEventController, :export_form)
    post("/complex_lobby_events/export/post", ComplexLobbyEventController, :export_post)
    get("/complex_lobby_events/summary", ComplexLobbyEventController, :summary)
    get("/complex_lobby_events/:event_name/detail", ComplexLobbyEventController, :detail)

    # Infologs
    get("/infolog/download/:id", InfologController, :download)
    get("/infolog/search", InfologController, :index)
    post("/infolog/search", InfologController, :search)
    resources("/infolog", InfologController, only: [:index, :show, :delete])
  end

  scope "/teiserver/reports", TeiserverWeb.Report, as: :ts_reports do
    pipe_through([:browser, :app_layout, :protected])

    get("/", GeneralController, :index)

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
    pipe_through([:browser, :app_layout, :protected])

    live("/dashboard", Index, :index)
    live("/dashboard/login_throttle", LoginThrottle, :index)
    live("/dashboard/policy/:id", Policy, :policy)
  end

  scope "/teiserver/admin", TeiserverWeb.ClientLive, as: :ts_admin do
    pipe_through([:browser, :app_layout, :protected])

    live("/client", Index, :index)
    live("/client/:id", Show, :show)
  end

  scope "/teiserver/admin", TeiserverWeb.PartyLive, as: :ts_admin do
    pipe_through([:browser, :app_layout, :protected])

    live("/party", Index, :index)
    live("/party/:id", Show, :show)
  end

  scope "/moderation", TeiserverWeb.Moderation do
    pipe_through([:browser, :app_layout])

    live_session :overwatch,
      on_mount: [
        {Teiserver.Account.AuthPlug, :ensure_authenticated},
        {Teiserver.Account.AuthPlug, {:authorise, "Overwatch"}}
      ] do
      live "/overwatch", OverwatchLive.Index, :index
      live "/overwatch/target/:target_id", OverwatchLive.User, :user
      live "/overwatch/report_group/:id", OverwatchLive.ReportGroupDetail, :index
    end

    live_session :report_user,
      on_mount: [
        {Teiserver.Account.AuthPlug, :mount_current_user}
      ] do
      live "/report_user", ReportUserLive.Index, :index
      live "/report_user/:id", ReportUserLive.Index, :selected
    end
  end

  scope "/moderation", TeiserverWeb.Moderation, as: :moderation do
    pipe_through([:browser, :app_layout, :protected])

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
  end

  scope "/admin", TeiserverWeb.Admin, as: :admin do
    pipe_through([:browser, :app_layout, :protected])

    resources("/lobby_policies", LobbyPolicyController,
      only: [:index, :new, :create, :show, :edit, :update, :delete]
    )

    resources("/text_callbacks", TextCallbackController,
      only: [:index, :new, :create, :show, :edit, :update, :delete]
    )

    resources("/discord_channels", DiscordChannelController,
      only: [:index, :new, :create, :show, :edit, :update, :delete]
    )

    # User stuff
    put("/users/gdpr_clean/:id", UserController, :gdpr_clean)
    get("/users/delete_user/:id", UserController, :delete_user)
    put("/users/delete_user/:id", UserController, :delete_user)
  end

  scope "/teiserver/admin", TeiserverWeb.Admin, as: :admin do
    pipe_through([:browser, :app_layout, :protected])

    # Codes
    resources("/codes", CodeController)
    put("/codes/extend/:id/:hours", CodeController, :extend)

    # Config
    resources("/site", SiteConfigController, only: [:index, :edit, :update, :delete])
  end

  scope "/chat", TeiserverWeb.Communication do
    pipe_through([:live_browser, :protected])

    live_session :chat_liveview,
      on_mount: [
        {Teiserver.Account.AuthPlug, :ensure_authenticated}
      ] do
      live "/", ChatLive.Index, :index
      live "/room", ChatLive.Room, :index
      live "/room/:room_name", ChatLive.Room, :index
    end
  end

  scope "/admin", TeiserverWeb.Admin do
    pipe_through([:live_browser, :protected])

    live_session :live_test_page_view,
      on_mount: [
        {Teiserver.Account.AuthPlug, :ensure_authenticated}
      ] do
      live "/test_page", TestPageLive.Index, :index
      live "/test_page/:tab", TestPageLive.Index, :index
    end

    live_session :admin_chat_liveview,
      on_mount: [
        {Teiserver.Account.AuthPlug, :ensure_authenticated},
        {Teiserver.Account.AuthPlug, {:authorise, "Moderator"}}
      ] do
      live "/chat", ChatLive.Index, :index
    end
  end

  scope "/teiserver/admin", TeiserverWeb.Admin, as: :ts_admin do
    pipe_through([:browser, :app_layout, :protected])

    get("/", GeneralController, :index)
    get("/metrics", GeneralController, :metrics)

    get("/tools", ToolController, :index)
    get("/tools/falist", ToolController, :falist)
    get("/tools/test_page", ToolController, :test_page)

    get("/users/create_form", UserController, :create_form)
    put("/users/create_post", UserController, :create_post)
    get("/users/rename_form/:id", UserController, :rename_form)
    put("/users/rename_post/:id", UserController, :rename_post)
    get("/users/reset_password/:id", UserController, :reset_password)
    get("/users/relationships/:id", UserController, :relationships)
    get("/users/action/:id/:action", UserController, :perform_action)
    put("/users/action/:id/:action", UserController, :perform_action)
    get("/users/smurf_search/:id", UserController, :smurf_search)
    post("/users/create_smurf_key/:userid", UserController, :create_smurf_key)

    put("/users/mark_as_smurf_of/:smurf_id/:origin_id", UserController, :mark_as_smurf_of)
    delete("/users/cancel_smurf_mark/:user_id", UserController, :cancel_smurf_mark)

    get("/users/smurf_merge_form/:from_id/:to_id", UserController, :smurf_merge_form)
    post("/users/smurf_merge_post/:from_id/:to_id", UserController, :smurf_merge_post)
    delete("/users/delete_smurf_key/:id", UserController, :delete_smurf_key)
    # get("/users/full_chat/:id", UserController, :full_chat)
    # get("/users/full_chat/:id/:page", UserController, :full_chat)
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

    # resources("/chat", ChatController, only: [:index])
    # post("/chat", ChatController, :index)

    resources("/achievements", AchievementController)

    get("/lobbies/:id/server_chat/download", LobbyController, :server_chat_download)
    get("/lobbies/:id/server_chat", LobbyController, :server_chat)
    get("/lobbies/:id/server_chat/:page", LobbyController, :server_chat)
    get("/lobbies/:id/lobby_chat/download", LobbyController, :lobby_chat_download)
    get("/lobbies/:id/lobby_chat", LobbyController, :lobby_chat)
    get("/lobbies/:id/lobby_chat/:page", LobbyController, :lobby_chat)
  end
end
