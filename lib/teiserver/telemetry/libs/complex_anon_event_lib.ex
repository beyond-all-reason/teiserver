defmodule Barserver.Telemetry.ComplexAnonEventLib do
  @moduledoc false
  use BarserverWeb, :library_newform
  alias Barserver.Telemetry
  alias Barserver.Telemetry.{ComplexAnonEvent, ComplexAnonEventQueries}
  alias Phoenix.PubSub

  @broadcast_event_types ~w(game_start:singleplayer:scenario_end)

  @spec colour :: atom
  def colour(), do: :info2

  @spec icon() :: String.t()
  def icon(), do: "fa-sliders-up"

  @spec log_complex_anon_event(String.t(), String.t(), map) ::
          {:error, Ecto.Changeset} | {:ok, ComplexAnonEvent}
  def log_complex_anon_event(hash, event_type_name, value) do
    event_type_id = Telemetry.get_or_add_complex_client_event_type(event_type_name)

    result =
      create_complex_anon_event(%{
        hash: hash,
        event_type_id: event_type_id,
        value: value,
        timestamp: Timex.now()
      })

    case result do
      {:ok, _event} ->
        if Enum.member?(@broadcast_event_types, event_type_name) do
          PubSub.broadcast(
            Barserver.PubSub,
            "telemetry_complex_anon_events",
            %{
              channel: "telemetry_complex_anon_events",
              hash: hash,
              event_type_name: event_type_name,
              event_value: value
            }
          )
        end

        result

      _ ->
        result
    end
  end

  @doc """
  Returns the list of complex_anon_events.

  ## Examples

      iex> list_complex_anon_events()
      [%ComplexAnonEvent{}, ...]

  """
  @spec list_complex_anon_events(list) :: list
  def list_complex_anon_events(args \\ []) do
    args
    |> ComplexAnonEventQueries.query_complex_anon_events()
    |> Repo.all()
  end

  @doc """
  Gets a single complex_anon_event.

  Raises `Ecto.NoResultsError` if the ComplexAnonEvent does not exist.

  ## Examples

      iex> get_complex_anon_event!(123)
      %ComplexAnonEvent{}

      iex> get_complex_anon_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_complex_anon_event!(id), do: Repo.get!(ComplexAnonEvent, id)

  def get_complex_anon_event!(id, args) do
    args = args ++ [id: id]

    args
    |> ComplexAnonEventQueries.query_complex_anon_events()
    |> Repo.one!()
  end

  @doc """
  Creates a complex_anon_event.

  ## Examples

      iex> create_complex_anon_event(%{field: value})
      {:ok, %ComplexAnonEvent{}}

      iex> create_complex_anon_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_complex_anon_event(attrs \\ %{}) do
    %ComplexAnonEvent{}
    |> ComplexAnonEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a complex_anon_event.

  ## Examples

      iex> update_complex_anon_event(complex_anon_event, %{field: new_value})
      {:ok, %ComplexAnonEvent{}}

      iex> update_complex_anon_event(complex_anon_event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_complex_anon_event(%ComplexAnonEvent{} = complex_anon_event, attrs) do
    complex_anon_event
    |> ComplexAnonEvent.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a complex_anon_event.

  ## Examples

      iex> delete_complex_anon_event(complex_anon_event)
      {:ok, %ComplexAnonEvent{}}

      iex> delete_complex_anon_event(complex_anon_event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_complex_anon_event(%ComplexAnonEvent{} = complex_anon_event) do
    Repo.delete(complex_anon_event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking complex_anon_event changes.

  ## Examples

      iex> change_complex_anon_event(complex_anon_event)
      %Ecto.Changeset{data: %ComplexAnonEvent{}}

  """
  def change_complex_anon_event(%ComplexAnonEvent{} = complex_anon_event, attrs \\ %{}) do
    ComplexAnonEvent.changeset(complex_anon_event, attrs)
  end
end
