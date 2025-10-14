defmodule Teiserver.Moderation do
  @moduledoc false
  import Ecto.Query, warn: false
  alias Teiserver.Repo
  # require Logger

  alias Phoenix.PubSub
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Helper.QueryHelpers

  alias Teiserver.{Account}
  import Teiserver.Logging.Helpers, only: [add_audit_log: 4]

  alias Teiserver.Moderation.{Report, ReportLib}

  @spec icon :: String.t()
  defdelegate icon(), to: ReportLib

  @spec colour :: atom
  defdelegate colour(), to: ReportLib

  def overwatch_icon(), do: "eye"

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
      inserted_after: Timex.shift(Timex.now(), days: -ReportLib.get_outstanding_report_max_days())
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
    |> broadcast_create_report
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
    |> broadcast_update_report
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

  def create_report_group_and_report(report_params) do
    report_group = get_or_make_report_group(report_params.match_id)

    report_params =
      Map.merge(report_params, %{
        report_group_id: report_group.id
      })

    case create_report(report_params) do
      {:ok, report} ->
        {:ok, report_group} =
          Teiserver.Moderation.update_report_group(report_group, %{
            report_count: report_group.report_count + 1
          })

        {:ok, report_group, report}

      result ->
        result
    end
  end

  alias Teiserver.Moderation.ReportGroupLib

  @spec list_report_groups() :: [ComplexServerEventType.t()]
  defdelegate list_report_groups(), to: ReportGroupLib

  @spec list_report_groups(list) :: [ComplexServerEventType.t()]
  defdelegate list_report_groups(args), to: ReportGroupLib

  @spec count_report_groups(list) :: integer()
  defdelegate count_report_groups(args), to: ReportGroupLib

  @spec get_report_group!(non_neg_integer) :: ComplexServerEventType.t()
  defdelegate get_report_group!(id), to: ReportGroupLib

  @spec get_report_group!(non_neg_integer, list) :: ComplexServerEventType.t()
  defdelegate get_report_group!(id, args), to: ReportGroupLib

  @spec create_report_group() :: {:ok, ComplexServerEventType.t()} | {:error, Ecto.Changeset}
  defdelegate create_report_group(), to: ReportGroupLib

  @spec create_report_group(map) :: {:ok, ComplexServerEventType.t()} | {:error, Ecto.Changeset}
  defdelegate create_report_group(attrs), to: ReportGroupLib

  @spec update_report_group(ComplexServerEventType.t(), map) ::
          {:ok, ComplexServerEventType.t()} | {:error, Ecto.Changeset}
  defdelegate update_report_group(report_group, attrs), to: ReportGroupLib

  @spec delete_report_group(ComplexServerEventType) ::
          {:ok, ComplexServerEventType} | {:error, Ecto.Changeset}
  defdelegate delete_report_group(report_group), to: ReportGroupLib

  @spec change_report_group(ComplexServerEventType) :: Ecto.Changeset
  defdelegate change_report_group(report_group), to: ReportGroupLib

  @spec change_report_group(ComplexServerEventType, map) :: Ecto.Changeset
  defdelegate change_report_group(report_group, attrs), to: ReportGroupLib

  @spec get_or_make_report_group(T.match_id() | nil) :: ReportGroup.t()
  defdelegate get_or_make_report_group(match_id), to: ReportGroupLib

  @spec open_report_group(ReportGroup.t()) :: :ok
  defdelegate open_report_group(report_group), to: ReportGroupLib

  @spec close_report_group(ReportGroup.t()) :: :ok
  defdelegate close_report_group(report_group), to: ReportGroupLib

  alias Teiserver.Moderation.{Response, ResponseLib}

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
    |> broadcast_create_response
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
    |> broadcast_update_response
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

  alias Teiserver.Moderation.{Action, ActionLib}

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
  @spec get_action(Integer.t() | List.t()) :: Action.t()
  @spec get_action(Integer.t(), List.t()) :: Action.t()
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

  alias Teiserver.Moderation.{Proposal, ProposalLib}

  @spec proposal_query(List.t()) :: Ecto.Query.t()
  def proposal_query(args) do
    proposal_query(nil, args)
  end

  @spec proposal_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def proposal_query(id, args) do
    ProposalLib.query_proposals()
    |> ProposalLib.search(%{id: id})
    |> ProposalLib.search(args[:search])
    |> ProposalLib.preload(args[:preload])
    |> ProposalLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of proposals.

  ## Examples

      iex> list_proposals()
      [%Proposal{}, ...]

  """
  @spec list_proposals(List.t()) :: List.t()
  def list_proposals(args \\ []) do
    proposal_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single proposal.

  Raises `Ecto.NoResultsError` if the Proposal does not exist.

  ## Examples

      iex> get_proposal!(123)
      %Proposal{}

      iex> get_proposal!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_proposal!(Integer.t() | List.t()) :: Proposal.t()
  @spec get_proposal!(Integer.t(), List.t()) :: Proposal.t()
  def get_proposal!(id) when not is_list(id) do
    proposal_query(id, [])
    |> Repo.one!()
  end

  def get_proposal!(args) do
    proposal_query(nil, args)
    |> Repo.one!()
  end

  def get_proposal!(id, args) do
    proposal_query(id, args)
    |> Repo.one!()
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single proposal.

  # Returns `nil` if the Proposal does not exist.

  # ## Examples

  #     iex> get_proposal(123)
  #     %Proposal{}

  #     iex> get_proposal(456)
  #     nil

  # """
  # def get_proposal(id, args \\ []) when not is_list(id) do
  #   proposal_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a proposal.

  ## Examples

      iex> create_proposal(%{field: value})
      {:ok, %Proposal{}}

      iex> create_proposal(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_proposal(map()) :: {:ok, Proposal.t()} | {:error, Ecto.Changeset.t()}
  def create_proposal(attrs \\ %{}) do
    %Proposal{}
    |> Proposal.changeset(attrs)
    |> Repo.insert()
    |> broadcast_create_proposal
  end

  def broadcast_create_proposal({:ok, proposal}) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "global_moderation",
      %{
        channel: "global_moderation",
        event: :new_proposal,
        proposal: proposal
      }
    )

    {:ok, proposal}
  end

  def broadcast_create_proposal(v), do: v

  @doc """
  Updates a proposal.

  ## Examples

      iex> update_proposal(proposal, %{field: new_value})
      {:ok, %Proposal{}}

      iex> update_proposal(proposal, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_proposal(Proposal.t(), map()) ::
          {:ok, Proposal.t()} | {:error, Ecto.Changeset.t()}
  def update_proposal(%Proposal{} = proposal, attrs) do
    proposal
    |> Proposal.changeset(attrs)
    |> Repo.update()
    |> broadcast_update_proposal
  end

  def broadcast_update_proposal({:ok, proposal}) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "global_moderation",
      %{
        channel: "global_moderation",
        event: :updated_proposal,
        proposal: proposal
      }
    )

    {:ok, proposal}
  end

  def broadcast_update_proposal(v), do: v

  @doc """
  Deletes a Proposal.

  ## Examples

      iex> delete_proposal(proposal)
      {:ok, %Proposal{}}

      iex> delete_proposal(proposal)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_proposal(Proposal.t()) :: {:ok, Proposal.t()} | {:error, Ecto.Changeset.t()}
  def delete_proposal(%Proposal{} = proposal) do
    Repo.delete(proposal)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking proposal changes.

  ## Examples

      iex> change_proposal(proposal)
      %Ecto.Changeset{source: %Proposal{}}

  """
  @spec change_proposal(Proposal.t()) :: Ecto.Changeset.t()
  def change_proposal(%Proposal{} = proposal) do
    Proposal.changeset(proposal, %{})
  end

  alias Teiserver.Moderation.{ProposalVote, ProposalVoteLib}

  @doc """
  Gets a single proposal_vote.

  Raises `Ecto.NoResultsError` if the ProposalVote does not exist.

  ## Examples

      iex> get_proposal_vote(123)
      %ProposalVote{}

      iex> get_proposal_vote(456)
      nil

  """
  @spec get_proposal_vote(T.userid(), integer()) :: ProposalVote.t() | nil
  def get_proposal_vote(user_id, proposal_id) do
    ProposalVoteLib.query_proposal_votes()
    |> ProposalVoteLib.search(user_id: user_id, proposal_id: proposal_id)
    |> Repo.one()
  end

  def create_proposal_vote(attrs \\ %{}) do
    %ProposalVote{}
    |> ProposalVote.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a proposal_vote.

  ## Examples

      iex> update_proposal_vote(proposal_vote, %{field: new_value})
      {:ok, %ProposalVote{}}

      iex> update_proposal_vote(proposal_vote, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_proposal_vote(%ProposalVote{} = proposal_vote, attrs) do
    proposal_vote
    |> ProposalVote.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ProposalVote.

  ## Examples

      iex> delete_proposal_vote(proposal_vote)
      {:ok, %ProposalVote{}}

      iex> delete_proposal_vote(proposal_vote)
      {:error, %Ecto.Changeset{}}

  """
  def delete_proposal_vote(%ProposalVote{} = proposal_vote) do
    Repo.delete(proposal_vote)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking proposal_vote changes.

  ## Examples

      iex> change_proposal_vote(proposal_vote)
      %Ecto.Changeset{source: %ProposalVote{}}

  """
  def change_proposal_vote(%ProposalVote{} = proposal_vote) do
    ProposalVote.changeset(proposal_vote, %{})
  end

  alias Teiserver.Moderation.{Ban, BanLib}

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
    |> broadcast_create_ban
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
    unbridge_user(Account.get_user_by_id(userid), message, flagged_word_count, location)
  end

  def unbridge_user(nil, _, _, _), do: :no_user

  def unbridge_user(user, message, flagged_word_count, location) do
    if not Teiserver.CacheUser.is_restricted?(user, ["Bridging"]) do
      {:ok, _action} =
        create_action(%{
          target_id: user.id,
          reason: "Automod detected flagged words in '#{message}'",
          restrictions: ["Bridging"],
          score_modifier: 100,
          hidden: true,
          expires: Timex.now() |> Timex.shift(years: 1200)
        })

      Teiserver.Moderation.RefreshUserRestrictionsTask.refresh_user(user.id)

      client = Account.get_client_by_id(user.id) || %{ip: "no client"}

      add_audit_log(user.id, client.ip, "Moderation:De-bridged user", %{
        message: message,
        flagged_word_count: flagged_word_count,
        location: location
      })
    end
  end
end
