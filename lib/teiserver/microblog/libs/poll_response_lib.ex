defmodule Teiserver.Microblog.PollResponseLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Microblog.{PollResponse, PollResponseQueries}
  alias Phoenix.PubSub

  @doc """
  Returns the list of poll_responses.

  ## Examples

      iex> list_poll_responses()
      [%PollResponse{}, ...]

  """
  @spec list_poll_responses(list) :: [PollResponse]
  def list_poll_responses(args \\ []) do
    args
    |> PollResponseQueries.query_poll_responses()
    |> Repo.all()
  end

  @spec get_poll_response(Teiserver.user_id(), Teiserver.Microblog.Post.id()) ::
          PollResponse.t() | nil
  def get_poll_response(user_id, post_id) do
    PollResponseQueries.query_poll_responses(
      where: [
        user_id: user_id,
        post_id: post_id
      ],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Creates a poll_response.

  ## Examples

      iex> create_poll_response(%{field: value})
      {:ok, %PollResponse{}}

      iex> create_poll_response(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_poll_response(attrs \\ %{}) do
    %PollResponse{}
    |> PollResponse.changeset(attrs)
    |> Repo.insert()
    |> broadcast_create_poll_response
  end

  defp broadcast_create_poll_response({:ok, %PollResponse{} = poll_response}) do
    spawn(fn ->
      # We sleep this because sometimes the message is seen fast enough the database doesn't
      # show as having the new data (row lock maybe?)
      :timer.sleep(1000)

      PubSub.broadcast(
        Teiserver.PubSub,
        "microblog_poll_responses",
        %{
          channel: "microblog_poll_responses",
          event: :poll_response_created,
          poll_response: poll_response
        }
      )
    end)

    {:ok, poll_response}
  end

  defp broadcast_create_poll_response(value), do: value

  @doc """
  Updates a poll_response.

  ## Examples

      iex> update_poll_response(poll_response, %{field: new_value})
      {:ok, %PollResponse{}}

      iex> update_poll_response(poll_response, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_poll_response(%PollResponse{} = poll_response, attrs) do
    poll_response
    |> PollResponse.changeset(attrs)
    |> Repo.update()
    |> broadcast_update_poll_response
  end

  defp broadcast_update_poll_response({:ok, %PollResponse{} = poll_response}) do
    spawn(fn ->
      # We sleep this because sometimes the message is seen fast enough the database doesn't
      # show as having the new data (row lock maybe?)
      :timer.sleep(1000)

      PubSub.broadcast(
        Teiserver.PubSub,
        "microblog_poll_responses",
        %{
          channel: "microblog_poll_responses",
          event: :poll_response_updated,
          poll_response: poll_response
        }
      )
    end)

    {:ok, poll_response}
  end

  defp broadcast_update_poll_response(value), do: value

  @doc """
  Deletes a poll_response.

  ## Examples

      iex> delete_poll_response(poll_response)
      {:ok, %PollResponse{}}

      iex> delete_poll_response(poll_response)
      {:error, %Ecto.Changeset{}}

  """
  def delete_poll_response(%PollResponse{} = poll_response) do
    Repo.delete(poll_response)
    |> broadcast_delete_poll_response
  end

  defp broadcast_delete_poll_response({:ok, %PollResponse{} = poll_response}) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "microblog_poll_responses",
      %{
        channel: "microblog_poll_responses",
        event: :poll_response_deleted,
        poll_response: poll_response
      }
    )

    {:ok, poll_response}
  end

  defp broadcast_delete_poll_response(value), do: value

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking poll_response changes.

  ## Examples

      iex> change_poll_response(poll_response)
      %Ecto.Changeset{data: %PollResponse{}}

  """
  def change_poll_response(%PollResponse{} = poll_response, attrs \\ %{}) do
    PollResponse.changeset(poll_response, attrs)
  end
end
