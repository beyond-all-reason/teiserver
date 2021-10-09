defmodule Central.Config.SiteConfigLib do
  # We can't define it as a library since the libraries import get_site_config from here

  alias Central.Repo
  alias Central.Config.SiteConfig

  alias CentralWeb.ACL.PermissionLib

  def colours(), do: Central.Helpers.StylingHelper.colours(:success2)
  def icon(), do: "far fa-cogs"

  def get_grouped_user_configs(user) do
    Cache.get_all
    |> Enum.filter(fn c ->
      c.permissions != nil
    end)
    |> Enum.filter(fn c ->
      Enum.map(c.permissions, fn p ->
        PermissionLib.has_permission?(user, p)
      end)
      |> Enum.all?
    end)
    |> Enum.sort(fn c1, c2 ->
      c1.key <= c2.key
    end)
    |> Enum.group_by(fn c ->
      hd String.split(c.key, ".")
    end)
  end

  def add_site_config(key, default, type, permissions, description, opts \\ []) do
    # Designed to be used at startup to ensure certain config types exist in the database
    if Cache.get(key) == nil do
      SiteConfig.creation_changeset(%SiteConfig{}, %{
        :key => key,
        :value => default,
      })
      |> Repo.insert!

      Cache.set({key, default, type, permissions, description, opts})
      :inserted
    else
      Cache.set_meta({key, type, permissions, description, opts})
      :found
    end
  end

  # This is exported so normal controllers can pull the configs from the cache
  def get_site_config(key) do
    conf = Cache.get(key)

    if conf != nil, do: conf.value, else: nil
  end

  def get_site_config(key, :full) do
    Cache.get(key)
  end
end
