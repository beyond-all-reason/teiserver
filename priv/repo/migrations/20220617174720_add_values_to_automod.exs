defmodule Central.Repo.Migrations.AddValuesToAutomod do
  use Ecto.Migration

  def change do
    alter table(:teiserver_automod_actions) do
      add :values, {:array, :string}
    end
    execute "UPDATE teiserver_automod_actions SET values = ARRAY[value];"

    alter table(:teiserver_automod_actions) do
      remove :value
      remove :type
      remove :actions
    end
  end
end
