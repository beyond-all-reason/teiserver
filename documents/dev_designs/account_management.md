# Integrating with Steam and other game store accounts

# User Journeys (Requirements)

## Seamless Steam Accounts

- Users launching BAR on Steam should be able to automatically login for
  online play.
  - This user experience is unlike the current flow which requires registration
    prior to online play.
- Users should be able to manage their account on server4.beyondallreason.info.
  - If the user has never registered automatically by launching BAR on Steam,
  server4.beyondallreason.info should provide a registration flow with Steam as
  the ID provider.
  - If the user has registered via Steam, a 'login with steam' button should be
  provided.

## Upgrade Path For Current Players

- Players with pre-existing BAR accounts (henceforce called 'legacy accounts')
  should be able to migrate seamlessly onto Steam. To comply with the
  [no smurfs rule](https://www.beyondallreason.info/code-of-conduct#5-unfair-advantages)
  note the following:
  - Players may create a new account linked to Steam, i.e. by
    starting BAR from Steam, as stated in the requirements above. Players should
    have the ability to link the Steam account to the legacy account.
      - Extra care should be taken: legacy account
      owners may unknowingly start BAR on Steam and play with the new Steam
      account rather than linking - resulting in unintentional 'smurfs'.
  - Alternately, players should be able to log into their legacy accounts via server4.beyondallreason.info
    and link to a Steam account.
