#### global_moderation
```elixir
%{
  event: :new_report,
  report: Report
}

%{
  event: :new_action,
  action: Action
}

%{
  event: :updated_action,
  action: Action
}

%{
  event: :new_ban,
  ban: Ban
}
```