defmodule Central.Types do
  # alias Central.Types, as: T
  @type user_id() :: integer()
  @type group_id() :: integer()

  @type user() :: Central.Account.User.t()
  @type group() :: Central.Account.Group.t()
end
