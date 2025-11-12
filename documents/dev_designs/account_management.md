# Integrating with Steam and other game store accounts

# Requirements

## Seamless Steam Accounts

- Users launching BAR on Steam must be able to login for online play without
  the need for registration.
  - This user experience is unlike the current flow which requires registration
  prior to online play.
- Users must be able to manage their account on server4.beyondallreason.info.
  - If the user has never registered automatically by launching BAR on Steam,
  server4.beyondallreason.info must provide a registration flow with Steam as
  the ID provider.
  - If the user has registered via Steam, a 'login with steam' button must be
  provided on server4.beyondallreason.info.

## Upgrade Path For Current Players

- Players with pre-existing BAR accounts (henceforce called 'legacy accounts')
  must be able to migrate seamlessly onto Steam. To comply with the
  [no smurfs rule](https://www.beyondallreason.info/code-of-conduct#5-unfair-advantages)
  note the following:
  - Players may create a new account linked to Steam and link the newly created
    Steam account with their legacy account.
      - Legacy account owners may unknowingly start BAR on Steam and play with
      the new Steam account prior to linking their legacy accounts - resulting
      in unintentional 'smurfs'. We must provide clear policy guidance, e.g. a
      possible grace period for 'accidently' playing on these smurfs, send
      notifications for these 'smurfs' to link their accounts.
  - Alternately, players must be able to log into their legacy accounts via
    server4.beyondallreason.info and link to a Steam account.

## (Stretch) Support For Additional Game Stores

- We may want to also have the same Steam experience with other game stores
  (e.g. Epic Games).
  - The design should allow any account to be linked to any number of additional game stores.

## (Stretch) Support For Unlinking

- We may provide the ability for players to request accounts to be unlinked.

## (Stretch) Deprecation of Legacy Account Creation

- Once BAR on Steam is generally available, we may no longer support the
creation of accounts through the current flow, i.e. through BYAR-Chobby via the
[REGISTER](https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html#REGISTER:client)
command.

# Additional Thoughts (Unorganized)

## Support additional identity providers

We should not restrict players from authenticating via any of their preferred
methods:
- Via the legacy flow
   - Through the web portal at server4.beyondallreason.info
   - [LOGIN](https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html#LOGIN:client)
- Using Steam as the ID provider
- Using any other game store as the ID provider.
- Using any identity provider? (Login via Facebook??)

When evolving the account system, adding any number of additional ID providers
should be part of the 'regular flow'.

## Unique In Game Identifier

Steam allows users to rename themselves at any time. Additionally, Steam in game
names are not necessarily unique.

- BAR Replays already store the 'accountid' of the player. However, replays also
store the name of the player which should now be treated as ephemeral.
  - How do we deal with renaming while allowing searching replays?
    - Any UI can no longer display the player name as stored in the replay file,
    but must instead use the stored 'accountid' to lookup the current player
    name.
    - How does this experience work when players want to lookup a specific match
    in their history? I.e. a player may say "Oh I want to lookup the match I had
    against 'Zow' in the past", but 'Zow' has renamed to 'Clyret'.

## Linking Accounts

When linking accounts, how do we merge the data?

A simple first implementation would be to just take the data of the older
account.
