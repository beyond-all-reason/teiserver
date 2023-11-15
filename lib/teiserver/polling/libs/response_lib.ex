defmodule Teiserver.Polling.ResponseLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Polling.{Response, ResponseQueries}
  alias Phoenix.PubSub

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-reply"

  @spec colours :: atom
  def colours, do: :success

  @doc """
  Returns the list of responses.

  ## Examples

      iex> list_responses()
      [%Response{}, ...]

  """
  @spec list_responses(list) :: [Response]
  def list_responses(args \\ []) do
    args
    |> ResponseQueries.query_responses()
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
  @spec get_response!(non_neg_integer()) :: Response.t
  def get_response!(response_id) do
    [id: response_id]
    |> ResponseQueries.query_responses()
    |> Repo.one!()
  end

  @spec get_response!(non_neg_integer(), list) :: Response.t
  def get_response!(response_id, args) do
    ([id: response_id] ++ args)
    |> ResponseQueries.query_responses()
    |> Repo.one!()
  end

  @spec get_response(non_neg_integer()) :: Response.t | nil
  def get_response(response_id) do
    [id: response_id]
    |> ResponseQueries.query_responses()
    |> Repo.one()
  end

  @spec get_response(non_neg_integer(), list) :: Response.t | nil
  def get_response(response_id, args) do
    ([id: response_id] ++ args)
    |> ResponseQueries.query_responses()
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
  def create_response(attrs \\ %{}) do
    %Response{}
    |> Response.changeset(attrs)
    |> Repo.insert()
    |> broadcast_create_response
  end

  defp broadcast_create_response({:ok, %Response{} = response}) do
    spawn(fn ->
      # We sleep this because sometimes the message is seen fast enough the database doesn't
      # show as having the new data (row lock maybe?)
      :timer.sleep(1000)
      PubSub.broadcast(
        Teiserver.PubSub,
        "polling_responses",
        %{
          channel: "polling_responses",
          event: :response_created,
          response: response
        }
      )
    end)

    {:ok, response}
  end

  defp broadcast_create_response(value), do: value

  @doc """
  Updates a response.

  ## Examples

      iex> update_response(response, %{field: new_value})
      {:ok, %Response{}}

      iex> update_response(response, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_response(%Response{} = response, attrs) do
    response
    |> Response.changeset(attrs)
    |> Repo.update()
    |> broadcast_update_response
  end

  defp broadcast_update_response({:ok, %Response{} = response}) do
    spawn(fn ->
      # We sleep this because sometimes the message is seen fast enough the database doesn't
      # show as having the new data (row lock maybe?)
      :timer.sleep(1000)
      PubSub.broadcast(
        Teiserver.PubSub,
        "polling_responses",
        %{
          channel: "polling_responses",
          event: :response_updated,
          response: response
        }
      )
    end)

    {:ok, response}
  end

  defp broadcast_update_response(value), do: value

  @doc """
  Deletes a response.

  ## Examples

      iex> delete_response(response)
      {:ok, %Response{}}

      iex> delete_response(response)
      {:error, %Ecto.Changeset{}}

  """
  def delete_response(%Response{} = response) do
    Repo.delete(response)
    |> broadcast_delete_response
  end

  defp broadcast_delete_response({:ok, %Response{} = response}) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "polling_responses",
      %{
        channel: "polling_responses",
        event: :response_deleted,
        response: response
      }
    )

    {:ok, response}
  end

  defp broadcast_delete_response(value), do: value

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking response changes.

  ## Examples

      iex> change_response(response)
      %Ecto.Changeset{data: %Response{}}

  """
  def change_response(%Response{} = response, attrs \\ %{}) do
    Response.changeset(response, attrs)
  end
end
