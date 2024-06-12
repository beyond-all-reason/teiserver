defmodule Teiserver.MetadataCache do
  @moduledoc """
  Cache and setup for miscellaneous metadata
  """

  use Supervisor
  alias Teiserver.Helpers.CacheHelper

  def start_link(opts) do
    with {:ok, sup} <- Supervisor.start_link(__MODULE__, :ok, opts),
         :ok <- random_names(),
         :ok <- audit() do
      {:ok, sup}
    end
  end

  @impl true
  def init(:ok) do
    children = [
      CacheHelper.concache_perm_sup(:application_metadata_cache)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp random_names() do
    # Brought over from Central
    Teiserver.store_put(
      :application_metadata_cache,
      "random_names_1",
      ~w(serene energised humble auspicious decisive exemplary cheerful determined playful spry springy)
    )

    Teiserver.store_put(:application_metadata_cache, "random_names_2", ~w(
      maroon cherry rose ruby
      amber carrot
      lemon beige
      mint lime cadmium
      aqua cerulean
      lavender indigo
      magenta amethyst
    ))

    Teiserver.store_put(
      :application_metadata_cache,
      "random_names_3",
      ~w(tick pawn lazarus rocketeer crossbow mace centurion tumbleweed smuggler compass ghost sprinter butler webber platypus hound welder recluse archangel gunslinger sharpshooter umbrella fatboy marauder vanguard razorback titan) ++
        ~w(grunt graverobber aggravator trasher thug bedbug deceiver augur spectre fiend twitcher duck skuttle sumo arbiter manticore termite commando mammoth shiva karganeth catapult behemoth juggernaught)
    )
  end

  defp audit() do
    Teiserver.Logging.AuditLogLib.add_audit_types([
      "Account:User password reset",
      "Account:Failed login",
      "Account:Created user",
      "Account:Updated user",
      "Account:Updated user permissions",
      "Account:User registration",
      "Account:Updated report",
      "Site config:Update value",
      "Moderation:Ban enabled",
      "Moderation:Ban disabled",
      "Moderation:Ban updated",
      "Moderation:Ban enacted",
      "Moderation:Action deleted",
      "Moderation:Action halted",
      "Moderation:Action re_posted",
      "Moderation:Action updated",
      "Moderation:Action created",
      "Moderation:De-bridged user",
      "Moderation:Mark as smurf",
      "Teiserver:Updated automod action",
      "Teiserver:Automod action enacted",
      "Teiserver:De-bridged user",
      "Teiserver:Changed user rating",
      "Teiserver:Changed user name",
      "Teiserver:Smurf merge",
      "Microblog.delete_post",
      "Discord.text_callback"
    ])
  end
end
