defmodule Central.Logging.PageViewLog do
  @moduledoc false
  use CentralWeb, :schema

  schema "page_view_logs" do
    field :path, :string
    field :section, :string
    field :method, :string
    field :ip, :string
    field :load_time, :integer
    field :status, :integer

    belongs_to :user, Central.Account.User

    timestamps()
  end

  @doc false
  def changeset(struct, params) do
    struct
    |> cast(params, [:path, :section, :method, :ip, :load_time, :user_id, :status])
    |> validate_required([:method, :ip, :load_time, :status])
  end

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_, conn, :delete), do: allow?(conn, "logging.page_view.delete")
  def authorize(_, conn, _), do: allow?(conn, "logging.page_view")
end
