defmodule Teiserver.Moderation do
  @moduledoc false

  alias Phoenix.PubSub
  alias Teiserver.Account
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Moderation.Action
  alias Teiserver.Moderation.ActionLib
  alias Teiserver.Moderation.Ban
  alias Teiserver.Moderation.BanLib
  alias Teiserver.Moderation.BannedDomain
  alias Teiserver.Moderation.BannedIP
  alias Teiserver.Moderation.BannedPhrase
  alias Teiserver.Moderation.LoadBannedDomainsTask
  alias Teiserver.Moderation.LoadBannedIPsTask
  alias Teiserver.Moderation.LoadBannedPhrasesTask
  alias Teiserver.Moderation.RefreshUserRestrictionsTask
  alias Teiserver.Moderation.Report
  alias Teiserver.Moderation.ReportLib
  alias Teiserver.Moderation.Response
  alias Teiserver.Moderation.ResponseLib
  alias Teiserver.Repo

  import Ecto.Query, warn: false
  import Teiserver.Logging.Helpers, only: [add_audit_log: 4]

  @spec icon :: String.t()
  defdelegate icon(), to: ReportLib

  @spec colour :: atom
  defdelegate colour(), to: ReportLib

  def overwatch_icon, do: "eye"

  @spec report_query(List.t()) :: Ecto.Query.t()
  def report_query(args) do
    report_query(nil, args)
  end

  @spec report_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def report_query(id, args) do
    ReportLib.query_reports()
    |> ReportLib.search(%{id: id})
    |> ReportLib.search(args[:search])
    |> ReportLib.preload(args[:preload])
    |> ReportLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of reports.

  ## Examples

      iex> list_reports()
      [%Report{}, ...]

  """
  @spec list_reports(List.t()) :: List.t()
  def list_reports(args \\ []) do
    report_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> QueryHelpers.offset_query(args[:offset])
    |> Repo.all()
  end

  @doc """
  Returns the count of reports.

  ## Examples

      iex> count_reports()
      42

  """
  @spec count_reports(List.t()) :: integer()
  def count_reports(args \\ []) do
    report_query(args)
    |> Repo.aggregate(:count, :id)
  end

  @doc """

  """
  @spec list_outstanding_reports_against_user(T.userid()) :: List.t()
  @spec list_outstanding_reports_against_user(T.userid(), List.t()) :: List.t()
  def list_outstanding_reports_against_user(userid, args \\ []) do
    search = [
      target_id: userid,
      no_result: true,
      closed: false,
      inserted_after:
        DateTime.shift(DateTime.utc_now(), day: -ReportLib.get_outstanding_report_max_days())
    ]

    args = Keyword.put(args, :search, search)

    report_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single report.

  Raises `Ecto.NoResultsError` if the Report does not exist.

  ## Examples

      iex> get_report!(123)
      %Report{}

      iex> get_report!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_report!(Integer.t() | List.t()) :: Report.t()
  @spec get_report!(Integer.t(), List.t()) :: Report.t()
  def get_report!(id) when not is_list(id) do
    report_query(id, [])
    |> Repo.one!()
  end

  def get_report!(args) do
    report_query(nil, args)
    |> Repo.one!()
  end

  def get_report!(id, args) do
    report_query(id, args)
    |> Repo.one!()
  end

  @doc """
  Gets a single report.

  Returns `nil` if the Report does not exist.

  ## Examples

      iex> get_report(123)
      %Report{}

      iex> get_report(456)
      nil

  """
  def get_report(id, args \\ []) when not is_list(id) do
    report_query(id, args)
    |> Repo.one()
  end

  @doc """
  Creates a report.

  ## Examples

      iex> create_report(%{field: value})
      {:ok, %Report{}}

      iex> create_report(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_report(map()) :: {:ok, Report.t()} | {:error, Ecto.Changeset.t()}
  def create_report(attrs \\ %{}) do
    %Report{}
    |> Report.changeset(attrs)
    |> Repo.insert()
    |> broadcast_create_report()
  end

  def broadcast_create_report({:ok, report}) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "global_moderation",
      %{
        channel: "global_moderation",
        event: :new_report,
        report: report
      }
    )

    {:ok, report}
  end

  def broadcast_create_report(v), do: v

  @doc """
  Updates a report.

  ## Examples

      iex> update_report(report, %{field: new_value})
      {:ok, %Report{}}

      iex> update_report(report, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_report(Report.t(), map()) :: {:ok, Report.t()} | {:error, Ecto.Changeset.t()}
  def update_report(%Report{} = report, attrs) do
    report
    |> Report.changeset(attrs)
    |> Repo.update()
    |> broadcast_update_report()
  end

  def broadcast_update_report({:ok, report}) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "global_moderation",
      %{
        channel: "global_moderation",
        event: :updated_report,
        report: report
      }
    )

    {:ok, report}
  end

  def broadcast_update_report(v), do: v

  @doc """
  Deletes a Report.

  ## Examples

      iex> delete_report(report)
      {:ok, %Report{}}

      iex> delete_report(report)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_report(Report.t()) :: {:ok, Report.t()} | {:error, Ecto.Changeset.t()}
  def delete_report(%Report{} = report) do
    Repo.delete(report)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking report changes.

  ## Examples

      iex> change_report(report)
      %Ecto.Changeset{source: %Report{}}

  """
  @spec change_report(Report.t()) :: Ecto.Changeset.t()
  def change_report(%Report{} = report) do
    Report.changeset(report, %{})
  end

  @spec response_query(List.t()) :: Ecto.Query.t()
  def response_query(args) do
    response_query(nil, args)
  end

  @spec response_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def response_query(id, args) do
    ResponseLib.query_responses()
    |> ResponseLib.search(%{id: id})
    |> ResponseLib.search(args[:search])
    |> ResponseLib.preload(args[:preload])
    |> ResponseLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of responses.

  ## Examples

      iex> list_responses()
      [%Response{}, ...]

  """
  @spec list_responses(List.t()) :: List.t()
  def list_responses(args \\ []) do
    response_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single response.

  Raises `Ecto.NoResultsError` if the Response does not exist.

  ## Examples

      iex> get_response!(123)
      %Response{}

      iex> get_response!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_response!(non_neg_integer(), T.userid()) :: Response.t()
  def get_response!(report_id, user_id) do
    response_query(
      search: [
        report_id: report_id,
        user_id: user_id
      ]
    )
    |> Repo.one!()
  end

  @doc """
  Gets a single response.

  Returns `nil` if the Response does not exist.

  ## Examples

      iex> get_response(123)
      %Response{}

     iex> get_response(456)
      nil

  """
  @spec get_response(non_neg_integer(), T.userid()) :: Response.t() | nil
  def get_response(report_id, user_id) do
    response_query(
      search: [
        report_id: report_id,
        user_id: user_id
      ]
    )
    |> Repo.one()
  end

  @doc """
  Creates a response.

  ## Examples

      iex> create_response(%{field: value})
      {:ok, %Response{}}

      iex> create_response(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_response(map()) :: {:ok, Response.t()} | {:error, Ecto.Changeset.t()}
  def create_response(attrs \\ %{}) do
    %Response{}
    |> Response.changeset(attrs)
    |> Repo.insert()
    |> broadcast_create_response()
  end

  def broadcast_create_response({:ok, response}) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "global_moderation",
      %{
        channel: "global_moderation",
        event: :new_response,
        response: response
      }
    )

    {:ok, response}
  end

  def broadcast_create_response(v), do: v

  @doc """
  Updates a response.

  ## Examples

      iex> update_response(response, %{field: new_value})
      {:ok, %Response{}}

      iex> update_response(response, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_response(Response.t(), map()) ::
          {:ok, Response.t()} | {:error, Ecto.Changeset.t()}
  def update_response(%Response{} = response, attrs) do
    response
    |> Response.changeset(attrs)
    |> Repo.update()
    |> broadcast_update_response()
  end

  def broadcast_update_response({:ok, response}) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "global_moderation",
      %{
        channel: "global_moderation",
        event: :updated_response,
        response: response
      }
    )

    {:ok, response}
  end

  def broadcast_update_response(v), do: v

  @doc """
  Deletes a Response.

  ## Examples

      iex> delete_response(response)
      {:ok, %Response{}}

      iex> delete_response(response)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_response(Response.t()) :: {:ok, Response.t()} | {:error, Ecto.Changeset.t()}
  def delete_response(%Response{} = response) do
    Repo.delete(response)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking response changes.

  ## Examples

      iex> change_response(response)
      %Ecto.Changeset{source: %Response{}}

  """
  @spec change_response(Response.t()) :: Ecto.Changeset.t()
  def change_response(%Response{} = response) do
    Response.changeset(response, %{})
  end

  @spec action_query(List.t()) :: Ecto.Query.t()
  def action_query(args) do
    action_query(nil, args)
  end

  @spec action_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def action_query(id, args) do
    ActionLib.query_actions()
    |> ActionLib.search(%{id: id})
    |> ActionLib.search(args[:search])
    |> ActionLib.preload(args[:preload])
    |> ActionLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of actions.

  ## Examples

      iex> list_actions()
      [%Action{}, ...]

  """
  @spec list_actions(List.t()) :: List.t()
  def list_actions(args \\ []) do
    action_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> QueryHelpers.offset_query(args[:offset])
    |> Repo.all()
  end

  @doc """
  Returns the count of actions.

  ## Examples

      iex> count_actions()
      42

  """
  @spec count_actions(List.t()) :: integer()
  def count_actions(args \\ []) do
    action_query(args)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Gets a single action.

  Raises `Ecto.NoResultsError` if the Action does not exist.

  ## Examples

      iex> get_action!(123)
      %Action{}

      iex> get_action!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_action!(Integer.t() | List.t()) :: Action.t()
  @spec get_action!(Integer.t(), List.t()) :: Action.t()
  def get_action!(id) when not is_list(id) do
    action_query(id, [])
    |> Repo.one!()
  end

  def get_action!(args) do
    action_query(nil, args)
    |> Repo.one!()
  end

  def get_action!(id, args) do
    action_query(id, args)
    |> Repo.one!()
  end

  @doc """
  Gets a single action.

  Returns `nil` if the Action does not exist.

  ## Examples

      iex> get_action(123)
      %Action{}

      iex> get_action(456)
      nil

  """
  @spec get_action(Integer.t() | List.t()) :: Action.t() | nil
  @spec get_action(Integer.t(), List.t()) :: Action.t() | nil
  def get_action(id) when not is_list(id) do
    action_query(id, [])
    |> Repo.one()
  end

  def get_action(args) do
    action_query(nil, args)
    |> Repo.one()
  end

  def get_action(id, args) do
    action_query(id, args)
    |> Repo.one()
  end

  @doc """
  Creates a action.

  ## Examples

      iex> create_action(%{field: value})
      {:ok, %Action{}}

      iex> create_action(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_action(map()) :: {:ok, Action.t()} | {:error, Ecto.Changeset.t()}
  def create_action(attrs \\ %{}) do
    %Action{}
    |> Action.changeset(attrs)
    |> Repo.insert()
    |> broadcast_create_action()
  end

  def broadcast_create_action({:ok, action}) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "global_moderation",
      %{
        channel: "global_moderation",
        event: :new_action,
        action: action
      }
    )

    {:ok, action}
  end

  def broadcast_create_action(v), do: v

  @doc """
  Updates a action.

  ## Examples

      iex> update_action(action, %{field: new_value})
      {:ok, %Action{}}

      iex> update_action(action, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_action(Action.t(), map()) :: {:ok, Action.t()} | {:error, Ecto.Changeset.t()}
  def update_action(%Action{} = action, attrs) do
    action
    |> Action.changeset(attrs)
    |> Repo.update()
    |> broadcast_update_action()
  end

  def broadcast_update_action({:ok, action}) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "global_moderation",
      %{
        channel: "global_moderation",
        event: :updated_action,
        action: action
      }
    )

    {:ok, action}
  end

  def broadcast_update_action(v), do: v

  @doc """
  Deletes a Action.

  ## Examples

      iex> delete_action(action)
      {:ok, %Action{}}

      iex> delete_action(action)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_action(Action.t()) :: {:ok, Action.t()} | {:error, Ecto.Changeset.t()}
  def delete_action(%Action{} = action) do
    Repo.delete(action)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking action changes.

  ## Examples

      iex> change_action(action)
      %Ecto.Changeset{source: %Action{}}

  """
  @spec change_action(Action.t()) :: Ecto.Changeset.t()
  def change_action(%Action{} = action) do
    Action.changeset(action, %{})
  end

  @spec ban_query(List.t()) :: Ecto.Query.t()
  def ban_query(args) do
    ban_query(nil, args)
  end

  @spec ban_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def ban_query(id, args) do
    BanLib.query_bans()
    |> BanLib.search(%{id: id})
    |> BanLib.search(args[:search])
    |> BanLib.preload(args[:preload])
    |> BanLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of bans.

  ## Examples

      iex> list_bans()
      [%Ban{}, ...]

  """
  @spec list_bans(List.t()) :: List.t()
  def list_bans(args \\ []) do
    ban_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> QueryHelpers.offset_query(args[:offset])
    |> Repo.all()
  end

  @doc """
  Returns the count of bans.

  ## Examples

      iex> count_bans()
      42

  """
  @spec count_bans(List.t()) :: integer()
  def count_bans(args \\ []) do
    ban_query(args)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Gets a single ban.

  Raises `Ecto.NoResultsError` if the Ban does not exist.

  ## Examples

      iex> get_ban!(123)
      %Ban{}

      iex> get_ban!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_ban!(Integer.t() | List.t()) :: Ban.t()
  @spec get_ban!(Integer.t(), List.t()) :: Ban.t()
  def get_ban!(id) when not is_list(id) do
    ban_query(id, [])
    |> Repo.one!()
  end

  def get_ban!(args) do
    ban_query(nil, args)
    |> Repo.one!()
  end

  def get_ban!(id, args) do
    ban_query(id, args)
    |> Repo.one!()
  end

  @doc """
  Gets a single ban.

  Returns `nil` if the Ban does not exist.

  ## Examples

      iex> get_ban(123)
      %Ban{}

      iex> get_ban(456)
      nil

  """
  def get_ban(id, args \\ []) when not is_list(id) do
    ban_query(id, args)
    |> Repo.one()
  end

  @doc """
  Creates a ban.

  ## Examples

      iex> create_ban(%{field: value})
      {:ok, %Ban{}}

      iex> create_ban(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_ban(map()) :: {:ok, Ban.t()} | {:error, Ecto.Changeset.t()}
  def create_ban(attrs \\ %{}) do
    %Ban{}
    |> Ban.changeset(attrs)
    |> Repo.insert()
    |> broadcast_create_ban()
  end

  def broadcast_create_ban({:ok, ban}) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "global_moderation",
      %{
        channel: "global_moderation",
        event: :new_ban,
        ban: ban
      }
    )

    {:ok, ban}
  end

  def broadcast_create_ban(v), do: v

  @doc """
  Updates a ban.

  ## Examples

      iex> update_ban(ban, %{field: new_value})
      {:ok, %Ban{}}

      iex> update_ban(ban, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_ban(Ban.t(), map()) :: {:ok, Ban.t()} | {:error, Ecto.Changeset.t()}
  def update_ban(%Ban{} = ban, attrs) do
    ban
    |> Ban.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Ban.

  ## Examples

      iex> delete_ban(ban)
      {:ok, %Ban{}}

      iex> delete_ban(ban)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_ban(Ban.t()) :: {:ok, Ban.t()} | {:error, Ecto.Changeset.t()}
  def delete_ban(%Ban{} = ban) do
    Repo.delete(ban)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ban changes.

  ## Examples

      iex> change_ban(ban)
      %Ecto.Changeset{source: %Ban{}}

  """
  @spec change_ban(Ban.t()) :: Ecto.Changeset.t()
  def change_ban(%Ban{} = ban) do
    Ban.changeset(ban, %{})
  end

  # Others
  @spec unbridge_user(nil | T.user() | T.userid(), String.t(), non_neg_integer(), String.t()) ::
          any
  def unbridge_user(userid, message, flagged_word_count, location) when is_integer(userid) do
    unbridge_user(Account.get_user(userid), message, flagged_word_count, location)
  end

  def unbridge_user(nil, _message, _flagged_word_count, _location), do: :no_user

  def unbridge_user(user, message, flagged_word_count, location) do
    if not Account.restricted?(user, ["Bridging"]) do
      {:ok, _action} =
        create_action(%{
          target_id: user.id,
          reason: "Automod detected flagged words in '#{message}'",
          restrictions: ["Bridging"],
          score_modifier: 100,
          hidden: true,
          expires: DateTime.shift(DateTime.utc_now(), year: 1200)
        })

      RefreshUserRestrictionsTask.refresh_user(user.id)

      client = Account.get_client_by_id(user.id) || %{ip: "no client"}

      add_audit_log(user.id, client.ip, "Moderation:De-bridged user", %{
        message: message,
        flagged_word_count: flagged_word_count,
        location: location
      })
    end
  end

  @doc """
  Returns the list of banned_domains.

  ## Examples

      iex> list_banned_domains()
      [%BannedDomain{}, ...]

  """
  def list_banned_domains do
    Repo.all(BannedDomain)
  end

  @spec list_banned_domains_cache :: [String.t()]
  def list_banned_domains_cache do
    Teiserver.cache_get(:application_metadata_cache, "banned_domains", [])
  end

  @spec banned_domain?(String.t()) :: boolean()
  def banned_domain?(email) do
    case String.split(email, "@") do
      [_start, domain] ->
        Enum.member?(list_banned_domains_cache(), domain)

      _no_email ->
        false
    end
  end

  @doc """
  Gets a single banned_domain.

  Raises `Ecto.NoResultsError` if the Banned domain does not exist.

  ## Examples

      iex> get_banned_domain!(123)
      %BannedDomain{}

      iex> get_banned_domain!(456)
      ** (Ecto.NoResultsError)

  """
  def get_banned_domain!(id), do: Repo.get!(BannedDomain, id)

  @doc """
  Creates a banned_domain.

  ## Examples

      iex> create_banned_domain(%{field: value})
      {:ok, %BannedDomain{}}

      iex> create_banned_domain(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_banned_domain(attrs \\ %{}) do
    %BannedDomain{}
    |> BannedDomain.changeset(attrs)
    |> Repo.insert()
    |> LoadBannedDomainsTask.cache_if_ok()
  end

  @doc """
  Updates a banned_domain.

  ## Examples

      iex> update_banned_domain(banned_domain, %{field: new_value})
      {:ok, %BannedDomain{}}

      iex> update_banned_domain(banned_domain, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_banned_domain(%BannedDomain{} = banned_domain, attrs) do
    banned_domain
    |> BannedDomain.changeset(attrs)
    |> Repo.update()
    |> LoadBannedDomainsTask.cache_if_ok()
  end

  @doc """
  Deletes a banned_domain.

  ## Examples

      iex> delete_banned_domain(banned_domain)
      {:ok, %BannedDomain{}}

      iex> delete_banned_domain(banned_domain)
      {:error, %Ecto.Changeset{}}

  """
  def delete_banned_domain(%BannedDomain{} = banned_domain) do
    Repo.delete(banned_domain)
    |> LoadBannedDomainsTask.cache_if_ok()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking banned_domain changes.

  ## Examples

      iex> change_banned_domain(banned_domain)
      %Ecto.Changeset{data: %BannedDomain{}}

  """
  def change_banned_domain(%BannedDomain{} = banned_domain, attrs \\ %{}) do
    BannedDomain.changeset(banned_domain, attrs)
  end

  @doc """
  Returns the list of banned_ips.

  ## Examples

      iex> list_banned_ips()
      [%BannedIP{}, ...]

  """
  def list_banned_ips do
    Repo.all(BannedIP)
  end

  @doc """
  Returns the list of banned_ips as IP objects

  ## Examples

      iex> list_banned_ip_ranges()
      [%BannedIP{}, ...]

  """
  def list_banned_ip_ranges do
    list_banned_ips_cache()
    |> Enum.map(fn x ->
      BannedIP.cidr_to_subnet(x.cidr)
    end)
    |> Enum.into([])
  end

  @spec list_banned_ips_cache :: [BannedIP.t()]
  def list_banned_ips_cache do
    Teiserver.cache_get(:application_metadata_cache, "banned_ip_ranges", [])
  end

  @doc """
  Gets a single banned_ip.

  Raises `Ecto.NoResultsError` if the Banned ip does not exist.

  ## Examples

      iex> get_banned_ip!(123)
      %BannedIP{}

      iex> get_banned_ip!(456)
      ** (Ecto.NoResultsError)

  """
  def get_banned_ip!(id), do: Repo.get!(BannedIP, id)

  @doc """
  Creates a banned_ip.

  ## Examples

      iex> create_banned_ip(%{field: value})
      {:ok, %BannedIP{}}

      iex> create_banned_ip(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_banned_ip(attrs \\ %{}) do
    %BannedIP{}
    |> BannedIP.changeset(attrs)
    |> Repo.insert()
    |> LoadBannedIPsTask.cache_if_ok()
  end

  @doc """
  Updates a banned_ip.

  ## Examples

      iex> update_banned_ip(banned_ip, %{field: new_value})
      {:ok, %BannedIP{}}

      iex> update_banned_ip(banned_ip, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_banned_ip(%BannedIP{} = banned_ip, attrs) do
    banned_ip
    |> BannedIP.changeset(attrs)
    |> Repo.update()
    |> LoadBannedIPsTask.cache_if_ok()
  end

  @doc """
  Deletes a banned_ip.

  ## Examples

      iex> delete_banned_ip(banned_ip)
      {:ok, %BannedIP{}}

      iex> delete_banned_ip(banned_ip)
      {:error, %Ecto.Changeset{}}

  """
  def delete_banned_ip(%BannedIP{} = banned_ip) do
    Repo.delete(banned_ip)
    |> LoadBannedIPsTask.cache_if_ok()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking banned_ip changes.

  ## Examples

      iex> change_banned_ip(banned_ip)
      %Ecto.Changeset{data: %BannedIP{}}

  """
  def change_banned_ip(%BannedIP{} = banned_ip, attrs \\ %{}) do
    BannedIP.changeset(banned_ip, attrs)
  end

  @spec banned_ip?(String.t() | nil) :: boolean()
  def banned_ip?(nil), do: false

  def banned_ip?(ip) do
    case IP.from_string(ip) do
      {:ok, ip} ->
        list_banned_ips_cache()
        |> Enum.any?(fn x -> ip in x end)

      {:error, :einval} ->
        false
    end
  end

  @doc """
  Returns the list of banned_phrases.

  ## Examples

      iex> list_banned_phrases()
      [%BannedPhrase{}, ...]

  """
  def list_banned_phrases do
    Repo.all(BannedPhrase)
  end

  @spec list_banned_phrases_cache() :: [BannedPhrase.t()]
  def list_banned_phrases_cache do
    Teiserver.cache_get(:application_metadata_cache, "banned_phrases", [])
  end

  @doc """
  Gets a single banned_phrase.

  Raises `Ecto.NoResultsError` if the Banned phrase does not exist.

  ## Examples

      iex> get_banned_phrase!(123)
      %BannedPhrase{}

      iex> get_banned_phrase!(456)
      ** (Ecto.NoResultsError)

  """
  def get_banned_phrase!(id), do: Repo.get!(BannedPhrase, id)

  @doc """
  Creates a banned_phrase.

  ## Examples

      iex> create_banned_phrase(%{field: value})
      {:ok, %BannedPhrase{}}

      iex> create_banned_phrase(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_banned_phrase(attrs \\ %{}) do
    %BannedPhrase{}
    |> BannedPhrase.changeset(attrs)
    |> Repo.insert()
    |> LoadBannedPhrasesTask.cache_if_ok()
  end

  @doc """
  Updates a banned_phrase.

  ## Examples

      iex> update_banned_phrase(banned_phrase, %{field: new_value})
      {:ok, %BannedPhrase{}}

      iex> update_banned_phrase(banned_phrase, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_banned_phrase(%BannedPhrase{} = banned_phrase, attrs) do
    banned_phrase
    |> BannedPhrase.changeset(attrs)
    |> Repo.update()
    |> LoadBannedPhrasesTask.cache_if_ok()
  end

  @doc """
  Deletes a banned_phrase.

  ## Examples

      iex> delete_banned_phrase(banned_phrase)
      {:ok, %BannedPhrase{}}

      iex> delete_banned_phrase(banned_phrase)
      {:error, %Ecto.Changeset{}}

  """
  def delete_banned_phrase(%BannedPhrase{} = banned_phrase) do
    Repo.delete(banned_phrase)
    |> LoadBannedPhrasesTask.cache_if_ok()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking banned_phrase changes.

  ## Examples

      iex> change_banned_phrase(banned_phrase)
      %Ecto.Changeset{data: %BannedPhrase{}}

  """
  def change_banned_phrase(%BannedPhrase{} = banned_phrase, attrs \\ %{}) do
    BannedPhrase.changeset(banned_phrase, attrs)
  end

  # VPNs
  @spec list_vpn_cache :: [String.t()]
  def list_vpn_cache do
    Teiserver.cache_get(:application_metadata_cache, "blocked_vpn_ranges", [])
  end

  @spec vpn_ip?(String.t() | nil) :: boolean()
  def vpn_ip?(nil), do: false

  def vpn_ip?(ip) do
    case IP.from_string(ip) do
      {:ok, ip} ->
        list_vpn_cache()
        |> Enum.any?(fn x -> ip in x end)

      {:error, :einval} ->
        false
    end
  end
end
