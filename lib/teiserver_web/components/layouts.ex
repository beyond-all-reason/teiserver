defmodule TeiserverWeb.Layouts do
  @moduledoc false

  use TeiserverWeb, :html

  import Teiserver.Config, only: [get_user_config_cache: 2]

  embed_templates "layouts/*"
end
