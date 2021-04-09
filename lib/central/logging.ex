defmodule Central.Logging do
  @moduledoc """
  The Logging context.
  """

  @spec icon() :: String.t()
  def icon(), do: "fas fa-bars"

  import Ecto.Query, warn: false
  alias Central.Helpers.QueryHelpers
  alias Central.Repo

  alias Central.Logging.AuditLog
  alias Central.Logging.AuditLogLib

  defp audit_log_query(args) do
    audit_log_query(nil, args)
  end

  defp audit_log_query(id, args) do
    AuditLogLib.query_audit_logs()
    |> AuditLogLib.search(%{id: id})
    |> AuditLogLib.search(args[:search])
    |> AuditLogLib.preload(args[:joins])
    |> AuditLogLib.order_by(args[:order])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of logging_logs.

  ## Examples

      iex> list_logging_logs()
      [%AuditLog{}, ...]

  """
  def list_audit_logs(args \\ []) do
    audit_log_query(args)
    |> QueryHelpers.limit_query(50)
    |> Repo.all()
  end

  @doc """
  Gets a single log.

  Raises `Ecto.NoResultsError` if the AuditLog does not exist.

  ## Examples

      iex> get_log!(123)
      %AuditLog{}

      iex> get_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_audit_log!(id) when not is_list(id) do
    audit_log_query(id, [])
    |> Repo.one!()
  end

  def get_audit_log!(args) do
    audit_log_query(nil, args)
    |> Repo.one!()
  end

  def get_audit_log!(id, args) do
    audit_log_query(id, args)
    |> Repo.one!()
  end

  @doc """
  Creates a log.

  ## Examples

      iex> create_log(%{field: value})
      {:ok, %AuditLog{}}

      iex> create_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_audit_log(attrs \\ %{}) do
    %AuditLog{}
    |> AuditLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a log.

  ## Examples

      iex> update_log(log, %{field: new_value})
      {:ok, %AuditLog{}}

      iex> update_log(log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_audit_log(%AuditLog{} = log, attrs) do
    log
    |> AuditLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a AuditLog.

  ## Examples

      iex> delete_log(log)
      {:ok, %AuditLog{}}

      iex> delete_log(log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_audit_log(%AuditLog{} = log) do
    Repo.delete(log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking log changes.

  ## Examples

      iex> change_log(log)
      %Ecto.Changeset{source: %AuditLog{}}

  """
  def change_audit_log(%AuditLog{} = log) do
    AuditLog.changeset(log, %{})
  end

  alias Central.Logging.ErrorLog
  alias Central.Logging.ErrorLogQueries

  @doc """
  Returns the list of logging_logs.

  ## Examples

      iex> list_logging_logs()
      [%ErrorLog{}, ...]

  """
  def list_error_logs(args \\ []) do
    ErrorLogQueries.get_error_logs()
    |> ErrorLogQueries.search(args[:search])
    |> ErrorLogQueries.preload(args[:joins])
    |> ErrorLogQueries.order(args[:order])
    |> QueryHelpers.limit_query(50)
    |> Repo.all()
  end

  @doc """
  Gets a single log.

  Raises `Ecto.NoResultsError` if the ErrorLog does not exist.

  ## Examples

      iex> get_log!(123)
      %ErrorLog{}

      iex> get_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_error_log!(id, args \\ []) do
    ErrorLogQueries.get_error_logs()
    |> ErrorLogQueries.search(%{id: id})
    |> ErrorLogQueries.search(args[:search])
    |> ErrorLogQueries.preload(args[:joins])
    |> Repo.one!()
  end

  @doc """
  Creates a log.

  ## Examples

      iex> create_log(%{field: value})
      {:ok, %ErrorLog{}}

      iex> create_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_error_log(attrs \\ %{}) do
    %ErrorLog{}
    |> ErrorLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a log.

  ## Examples

      iex> update_log(log, %{field: new_value})
      {:ok, %ErrorLog{}}

      iex> update_log(log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_error_log(%ErrorLog{} = log, attrs) do
    log
    |> ErrorLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ErrorLog.

  ## Examples

      iex> delete_log(log)
      {:ok, %ErrorLog{}}

      iex> delete_log(log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_error_log(%ErrorLog{} = log) do
    Repo.delete(log)
  end

  def delete_all_error_logs() do
    ErrorLogQueries.get_error_logs()
    |> Repo.delete_all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking log changes.

  ## Examples

      iex> change_log(log)
      %Ecto.Changeset{source: %ErrorLog{}}

  """
  def change_error_log(%ErrorLog{} = log) do
    ErrorLog.changeset(log, %{})
  end

  alias Central.Logging.PageViewLog
  alias Central.Logging.PageViewLogLib

  @doc """
  Returns the list of page_view_logs.

  ## Examples

      iex> list_page_view_logs()
      [%PageViewLog{}, ...]

  """
  def list_page_view_logs(args \\ []) do
    PageViewLogLib.get_page_view_logs()
    |> PageViewLogLib.search(args[:search])
    |> PageViewLogLib.preload(args[:joins])
    |> PageViewLogLib.order(args[:order])
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single page_view_log.

  Raises `Ecto.NoResultsError` if the PageViewLog does not exist.

  ## Examples

      iex> get_page_view_log!(123)
      %PageViewLog{}

      iex> get_page_view_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_page_view_log!(id), do: Repo.get!(PageViewLog, id)

  def get_page_view_log!(id, args) do
    PageViewLogLib.get_page_view_logs()
    |> PageViewLogLib.search(%{id: id})
    |> PageViewLogLib.search(args[:search])
    |> PageViewLogLib.preload(args[:joins])
    |> Repo.one!()
  end

  @doc """
  Creates a page_view_log.

  ## Examples

      iex> create_page_view_log(%{field: value})
      {:ok, %PageViewLog{}}

      iex> create_page_view_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_page_view_log(attrs \\ %{}) do
    %PageViewLog{}
    |> PageViewLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a page_view_log.

  ## Examples

      iex> update_page_view_log(page_view_log, %{field: new_value})
      {:ok, %PageViewLog{}}

      iex> update_page_view_log(page_view_log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_page_view_log(%PageViewLog{} = page_view_log, attrs) do
    page_view_log
    |> PageViewLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a PageViewLog.

  ## Examples

      iex> delete_page_view_log(page_view_log)
      {:ok, %PageViewLog{}}

      iex> delete_page_view_log(page_view_log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_page_view_log(%PageViewLog{} = page_view_log) do
    Repo.delete(page_view_log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking page_view_log changes.

  ## Examples

      iex> change_page_view_log(page_view_log)
      %Ecto.Changeset{source: %PageViewLog{}}

  """
  def change_page_view_log(%PageViewLog{} = page_view_log) do
    PageViewLog.changeset(page_view_log, %{})
  end

  # alias Central.Logging.AggregateViewLog
  alias Central.Logging.AggregateViewLogLib

  @doc """
  Returns the list of logging_logs.

  ## Examples

      iex> list_logging_logs()
      [%AggregateViewLog{}, ...]

  """
  def list_aggregate_view_logs(args \\ []) do
    AggregateViewLogLib.get_logs()
    |> AggregateViewLogLib.search(args[:search])
    # |> AggregateViewLogLib.preload(args[:joins])
    |> AggregateViewLogLib.order(args[:order])
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  def get_last_aggregate_date() do
    AggregateViewLogLib.get_last_aggregate_date()
  end

  def get_first_page_view_log_date() do
    AggregateViewLogLib.get_first_page_view_log_date()
  end

  def get_aggregate_view_log!(date, args \\ []) do
    AggregateViewLogLib.get_logs()
    |> AggregateViewLogLib.search(date: date)
    |> AggregateViewLogLib.search(args[:search])
    # |> AggregateViewLogLib.preload(args[:joins])
    |> AggregateViewLogLib.order(args[:order])
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.one!()
  end
end
