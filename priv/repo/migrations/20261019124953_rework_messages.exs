defmodule Teiserver.Repo.Migrations.ReworkMessages do
  use Ecto.Migration

  def change do
    rename table(:teiserver_room_messages), to: table(:spring_room_messages)
    rename table(:direct_messages), to: table(:spring_direct_messages)
    rename table(:teiserver_lobby_messages), to: table(:spring_lobby_messages)

    for name <- ~w(pkey from_id_index to_id_index) do
      execute(
        "ALTER INDEX direct_messages_#{name} RENAME TO spring_direct_messages_#{name}",
        "ALTER INDEX spring_direct_messages_#{name} RENAME TO direct_messages_#{name}"
      )
    end

    execute(
      "ALTER SEQUENCE direct_messages_id_seq RENAME TO spring_direct_messages_id_seq",
      "ALTER SEQUENCE spring_direct_messages_id_seq RENAME TO direct_messages_id_seq"
    )

    alter table(:spring_direct_messages) do
      remove :delivered, :boolean
    end

    drop_if_exists table(:teiserver_party_messages)

    create table(:party_messages, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :content, :text, null: false
      add :party_id, :uuid, null: false
      add :inserted_at, :utc_datetime, null: false
      add :user_id, references(:account_users, on_delete: :delete_all), null: false
    end

    create index(:party_messages, [:party_id])
    create index(:party_messages, [:user_id])
    create index(:party_messages, [:inserted_at])

    create table(:battle_messages, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :content, :text, null: false
      add :destination, :text, null: false
      add :inserted_at, :utc_datetime, null: false
      add :match_id, references(:teiserver_battle_matches, on_delete: :delete_all), null: false
      add :from_id, references(:account_users, on_delete: :delete_all), null: false
      add :to_id, references(:account_users, on_delete: :delete_all)
    end

    create index(:battle_messages, [:match_id])
    create index(:battle_messages, [:from_id])
    create index(:battle_messages, [:to_id])
    create index(:battle_messages, [:inserted_at])

    create table(:lobby_messages, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :content, :text, null: false
      add :lobby_id, :uuid, null: false
      add :inserted_at, :utc_datetime, null: false
      add :user_id, references(:account_users, on_delete: :delete_all), null: false
      add :match_id, references(:teiserver_battle_matches, on_delete: :nilify_all)
    end

    create index(:lobby_messages, [:lobby_id])
    create index(:lobby_messages, [:user_id])
    create index(:lobby_messages, [:match_id])
    create index(:lobby_messages, [:inserted_at])

    create table(:direct_messages, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :content, :text, null: false
      add :inserted_at, :utc_datetime, null: false
      add :from_id, references(:account_users, on_delete: :delete_all), null: false
      add :to_id, references(:account_users, on_delete: :delete_all), null: false
    end

    create index(:direct_messages, [:from_id])
    create index(:direct_messages, [:to_id])
    create index(:direct_messages, [:inserted_at])
  end
end
