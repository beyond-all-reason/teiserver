defmodule Teiserver.Moderation.ReportGroupLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  # alias Teiserver.Moderation
  alias Teiserver.Moderation.{ReportGroup, ReportGroupQueries}
  # alias Phoenix.PubSub

  @spec colour :: atom
  def colour(), do: :warning

  @spec icon() :: String.t()
  def icon(), do: "fa-house-flag"

  @spec make_favourite(ReportGroup.t()) :: map()
  def make_favourite(report_group) do
    %{
      type_colour: Teiserver.Moderation.colour(),
      type_icon: Teiserver.Moderation.icon(),
      item_id: report_group.id,
      item_type: "moderation_report_group",
      item_colour: colour(),
      item_icon: icon(),
      item_label: "#{report_group.target.name}",
      url: "/moderation/overwatch/report_group/#{report_group.id}"
    }
  end

  @doc """
  Returns the list of report_groups.

  ## Examples

      iex> list_report_groups()
      [%ReportGroup{}, ...]

  """
  @spec list_report_groups(list) :: list
  def list_report_groups(args \\ []) do
    args
    |> ReportGroupQueries.query_report_groups()
    |> Repo.all()
  end

  @spec count_report_groups(list) :: integer()
  def count_report_groups(args \\ []) do
    args
    |> ReportGroupQueries.query_report_groups()
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Gets a single report_group.

  Raises `Ecto.NoResultsError` if the ReportGroup does not exist.

  ## Examples

      iex> get_report_group!(123)
      %ReportGroup{}

      iex> get_report_group!(456)
      ** (Ecto.NoResultsError)

  """
  def get_report_group!(id), do: Repo.get!(ReportGroup, id)

  def get_report_group!(id, args) do
    args = args ++ [id: id]

    args
    |> ReportGroupQueries.query_report_groups()
    |> Repo.one!()
  end

  @spec get_report_group(non_neg_integer(), T.match_id()) :: ReportGroup.t() | nil
  def get_report_group(id, args) when is_list(args) do
    args = args ++ [id: id]

    args
    |> ReportGroupQueries.query_report_groups()
    |> Repo.one()
  end

  def get_report_group(match_id) do
    ReportGroupQueries.query_report_groups(
      where: [
        match_id: match_id
      ]
    )
    |> Repo.one()
  end

  @doc """
  Creates a report_group.

  ## Examples

      iex> create_report_group(%{field: value})
      {:ok, %ReportGroup{}}

      iex> create_report_group(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_report_group(attrs \\ %{}) do
    %ReportGroup{}
    |> ReportGroup.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a report_group.

  ## Examples
      iex> update_report_group(report_group, %{field: new_value})
      {:ok, %ReportGroup{}}

      iex> update_report_group(report_group, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_report_group(%ReportGroup{} = report_group, attrs) do
    report_group
    |> ReportGroup.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a report_group.

  ## Examples

      iex> delete_report_group(report_group)
      {:ok, %ReportGroup{}}

      iex> delete_report_group(report_group)
      {:error, %Ecto.Changeset{}}

  """
  def delete_report_group(%ReportGroup{} = report_group) do
    Repo.delete(report_group)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking report_group changes.

  ## Examples

      iex> change_report_group(report_group)
      %Ecto.Changeset{data: %ReportGroup{}}

  """
  def change_report_group(%ReportGroup{} = report_group, attrs \\ %{}) do
    ReportGroup.changeset(report_group, attrs)
  end

  @spec get_or_make_report_group(T.match_id()) :: ReportGroup.t()
  def get_or_make_report_group(match_id) when is_integer(match_id) do
    case get_report_group(match_id) do
      nil ->
        {:ok, rg} = create_report_group(%{match_id: match_id})
        rg

      r ->
        r
    end
  end

  #  def get_or_make_report_group(target_id, nil) do
  #    report_group =
  #      get_report_group(nil,
  #        where: [
  #          target_id: target_id,
  #          match_id: false,
  #          closed: false
  #        ]
  #      )
  #
  #    case report_group do
  #      nil ->
  #        {:ok, rg} = create_report_group(%{target_id: target_id})
  #        rg
  #
  #      _ ->
  #        report_group
  #    end
  #  end
end
