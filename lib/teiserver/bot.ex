defmodule Teiserver.Bot do
  alias Teiserver.Bot.Bot
  alias Teiserver.BotQueries
  alias Teiserver.Repo

  @type id :: Teiserver.Bot.Bot.id()

  def create_bot(attrs \\ %{}) do
    %Bot{}
    |> Bot.changeset(attrs)
    |> Repo.insert()
  end

  def change_bot(%Bot{} = bot, attrs \\ %{}) do
    Bot.changeset(bot, attrs)
  end

  def update_bot(%Bot{} = bot, attrs) do
    bot |> change_bot(attrs) |> Repo.update()
  end

  @spec delete(Bot.t()) :: :ok | {:error, term()}
  def delete(%Bot{} = bot) do
    case Repo.delete(bot) do
      {:ok, _} -> :ok
      {:error, err} -> {:error, err}
    end
  end

  defdelegate get_by_id(id), to: BotQueries
end
