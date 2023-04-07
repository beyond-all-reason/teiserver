defmodule Teiserver.Account.CodeOfConductData do
  @moduledoc false

  @spec data() :: %{String.t() => %{String.t() => String.t()}}
  def data do
    %{
      "1" => %{
        "1" =>
          "Promoting illegal activities including but not limited to gambling, drug use, phishing, self-harm and the like; note some of these can be discussed in the appropriate locations but this is a game and generally not a place for sharing these topics",
        "2" =>
          "Discrimination or abuse especially on the grounds or context of sexism, racism, homophobia, disability, religion and similar",
        "3" =>
          "Threats and harassment, saying 'it was just a joke' does not excuse this either; it's only a joke if all parties find it funny",
        "4" =>
          "Nicknames and clan tags must not be offensive or inappropriate. An account which doesn't abide by this rule will be suspended until it gets renamed. Impersonation of other players and real-life figures is forbidden",
        "5" =>
          "Griefing or actively working against your team. Examples include teamkilling, purposefully hurting/imprisoning allied, actively stealing allied units without consent",
        "6" =>
          "Custom widgets used on public servers must be made publicly available, we have a section on the discord specifically for it",
        "7" =>
          "Self destructing all your units in a team game; if you want to leave then resign and let your team take control of your units",
        "8" =>
          "Harassing players for using perfectly valid strategies such as rushing, commander drops, unexpected air raids and the like",
        "9" =>
          "Abuse of the ping or draw function to obscure team mates view or drawing hate symbols, heavy profanity etc",
        "10" =>
          "Disrupting game lobbies either by flooding chat, calling repeated votes or repeatedly joining when asked to leave",
        "11" =>
          "Respect for all other members is mandatory, harassment and baiting of any community member, especially contributors is not tolerated. Note: Constant unwarranted negative information and misinformation intended to cast a negative light on the project or contributors will not be tolerated."
      },
      "2" => %{
        "1" =>
          "Playing in a team game but not working with your team; you are not obliged do everything your team says but you are expected to play with them not against them",
        "2" =>
          "Profanity; we discourage swearing but it isn't banned as long as it's not excessive. Be careful not to confuse curse words with unacceptable behaviour such as racism",
        "3" =>
          "In a teamgame everybody needs some space, purposefully limiting allies so you can have more without an objectively reasonable cause is not acceptable",
        "4" => "Pausing at inappropriate moments or unpausing when someone is disconnected",
        "5" => "Dragging out very clearly won games",
        "6" => "Abusing spectator mode to pass on information to a player"
      },
      "3" => %{
        "1" =>
          "Attempting to hack another player's account or the game infrastructure (if you wish to perform security testing contact the devs)",
        "2" =>
          "Revealing personal or identifiable information about another player they've not already revealed themselves",
        "3" =>
          "Posting malware, spam or scam links/messages. We'd assume most of these would be bot behaviours but we're listing it here to be safe.",
        "4" => "False or intentionally erroneous reports",
        "5" =>
          "Impersonation of another player or the team running and making BAR, this includes taking credit for things you did not contribute to",
        "6" =>
          "Circumvention of moderation, if you've been temporarily banned don't try to create a new account to get around it",
        "7" =>
          "Exploiting bugs, hacking, spec cheating (second account to view the game as a spectator) or using game features to gain an unfair advantage in some manner (e.g. abusing subbing to co-op in a team game)",
        "8" =>
          "Attempting to exploit the player skill rating system, either by dumping by losing on purpose or boosting with smurf accounts"
      }
    }
  end

  @spec flat_data :: list
  def flat_data() do
    data()
    |> Enum.map(fn {key1, items} ->
      items
      |> Enum.map(fn {key2, text} ->
        {"#{key1}.#{key2}", text}
      end)
    end)
    |> List.flatten()
  end

  @spec get_point(String.t()) :: String.t() | nil
  def get_point(key) do
    case String.split(key, ".") do
      [p1, p2] ->
        get_in(data(), [p1, p2])

      _ ->
        nil
    end
  end
end
