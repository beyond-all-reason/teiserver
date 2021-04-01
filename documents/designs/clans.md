Clans are public, organised and managed groups of players. Clans will have one or more leaders and potentially as functionality expands, additional tiers of membership/authority. Clans should be able to take part in clan-only events and have a separate leaderboard.

## Web sections
#### Guests
- Clan list
- Public homepage

#### Members
- Member list

#### Clan admin
- Homepage management
- Member management

#### Site admin
- Clan List, show, edit etc
- Clan memberships/requests

#### Homepage contents ideas
- Leadership team + blurb
- Highlighted clan games
- Clan stats vs other clans

## Server/Backend
- Clan being a property of user, not part of their name itself (thus rename not required)
- Clan TS/MMR rating, maybe something even more in-depth on a clan-clan relationship?

#### Nice to haves
- Clan announcements
- Clan chat (is this going to bring value when most clans might just have a discord?)
- Planetwars/Campaign mode, clans compete for territory
- Challenges, rewards/levels for completing them
- Stats, lots and lots of stats
- A way to handle clan tag being part of a name such as Fire[Z]torm

## Planned DB structure
Clan
- name: String
- tag: String
- icon: String *(option of an SVG image?)*
- colour1: String
- colour2: String
- rating: Map *(mmr/ts ratings)*
- homepage: Map *(No idea of structure yet)*

ClanMember
- user: UserID
- clan: ClanID
- role: String (admin, mod, member, player)

ClanInvite *(sent from clan to user)*
- user: UserID
- clan: ClanID
- response: String *(Pending, rejected, if accepted delete the request, rejections can be reset this way too)*
