defmodule Teiserver.Repo.Migrations.AddAccoladeRestriction do
  use Ecto.Migration

  def change do
    alter table("teiserver_account_badge_types") do
      add :restriction, :string
    end

    # Restrict new column to certain values
    constraint_query = """
     ALTER TABLE teiserver_account_badge_types
     ADD CONSTRAINT restriction_constraint check(restriction in ('Ally', 'Enemy') OR restriction is null);


    """

    # If we rollback remove the constraint
    rollback_query =
      "ALTER TABLE teiserver_account_badge_types DROP CONSTRAINT restriction_constraint;"

    execute(constraint_query, rollback_query)

    # UPDATE Good Teammate accolade to be ally only
    update_restrictions = """
     UPDATE teiserver_account_badge_types
      set restriction = 'Ally'
      where lower(name) = 'good teammate';
    """

    # If we rollback don't need to do anything extra
    rollback_query =
      ""

    execute(update_restrictions, rollback_query)
  end
end
