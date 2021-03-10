defmodule Central.Communication.ChatRoom do
  use CentralWeb, :schema

  schema "communication_chat_rooms" do
    field :name, :string
    field :description, :string

    field :colour, :string
    field :icon, :string

    field :current_content, :integer, default: 0
    field :public, :boolean
    field :rules, :map

    has_many :content, Central.Communication.ChatContent

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings([:name])

    struct
    |> cast(params, [:name, :colour, :icon, :public, :rules, :current_content])
    |> validate_required([:name, :colour, :icon, :public, :rules, :current_content])
  end
end
