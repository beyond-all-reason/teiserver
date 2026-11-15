# Micro benchmark for banned phrase matching, comparing the previous
# implementation (downcase + split per phrase, per message) with the current one.
#
# Usage (does not need the database or a running server):
#
#     mix run --no-start scripts/bench_banned_phrases.exs
#
# Optional env vars: PHRASES (default 200), MESSAGES (default 20000)
alias Teiserver.Moderation.BannedPhrase

phrase_count = String.to_integer(System.get_env("PHRASES", "200"))
message_count = String.to_integer(System.get_env("MESSAGES", "20000"))

# Old behaviour: loaded_phrase for raw phrases was the downcased string
old_load = fn %BannedPhrase{type: :raw, phrase: phrase} = bp ->
  %BannedPhrase{bp | loaded_phrase: String.downcase(phrase)}
end

old_match = fn %BannedPhrase{loaded_phrase: loaded}, message ->
  String.contains?(String.downcase(message), String.split(loaded, ","))
end

# Mostly raw phrases (some comma separated), plus a few fuzzy/regex ones
raw =
  for i <- 1..phrase_count do
    phrase =
      if rem(i, 5) == 0,
        do: "BadWord#{i},WorseWord#{i}",
        else: "BadWord#{i}"

    %BannedPhrase{id: i, type: :raw, phrase: phrase, use_cases: ["chat"]}
  end

other =
  [
    %BannedPhrase{id: 100_001, type: :fuzzy, phrase: "foo*bar", use_cases: ["chat"]},
    %BannedPhrase{id: 100_002, type: :regex, phrase: "ba[dz]+\\d{3}", use_cases: ["chat"]}
  ]

new_phrases = Enum.map(raw ++ other, &BannedPhrase.load_phrase/1)
old_raw = Enum.map(raw, old_load)

# Realistic chat messages: mostly clean, a few hits
messages =
  for i <- 1..message_count do
    base = "Hello There, This Is Chat Message Number #{i} about the GAME and units"
    if rem(i, 100) == 0, do: base <> " badword#{rem(i, phrase_count) + 1}", else: base
  end

run = fn fun -> for m <- messages, do: fun.(m) end

old_fun = fn m -> Enum.any?(old_raw, &old_match.(&1, m)) end

new_fun = fn m ->
  Enum.any?(new_phrases, &BannedPhrase.phrase_match?(&1, m))
end

# message_is_banned? hoists the downcase out of the loop, mimic that here by
# going through the public API that does the whole list in one call
new_hoisted_fun = fn m ->
  lowered = String.downcase(m)

  Enum.any?(new_phrases, fn
    %BannedPhrase{type: :raw, loaded_phrase: parts} -> String.contains?(lowered, parts)
    %BannedPhrase{loaded_phrase: regex} -> Regex.match?(regex, m)
  end)
end

# Sanity check, both implementations must agree
for m <- Enum.take(messages, 1000) do
  true = old_fun.(m) == new_fun.(m) and new_fun.(m) == new_hoisted_fun.(m)
end

time = fn label, fun ->
  run.(fun)
  {micros, _} = :timer.tc(fn -> Enum.each(1..5, fn _ -> run.(fun) end) end)
  per_msg = micros / (5 * message_count)
  IO.puts("#{String.pad_trailing(label, 42)} #{Float.round(per_msg, 2)} µs/message")
end

IO.puts("#{phrase_count} raw phrases + 2 other, #{message_count} messages\n")
time.("old (downcase+split per phrase)", old_fun)
time.("new phrase_match?/2 (split at load)", new_fun)
time.("new hoisted (as message_is_banned?/3)", new_hoisted_fun)
