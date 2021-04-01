Clans are public, organised and managed groups of players. Clans will have one or more leaders and potentially as functionality expands, additional tiers of membership/authority. Clans should be able to take part in clan-only events and have a separate leaderboard.

### Ideas from Discord
#### Raghna
- clan management
- different clan member types
- clan vs clan matches ?
- clan homebase (like a chatroom, announcements, clan overview, member overview and what servers they're in, member profiles (just top of the head ideas)
- inviting people to a clan instead of /rename
- official tags and making your own clan tags (option for making tag in front of in back)
- clan colour and choosing clan palette for ingame colours

#### PtaQ
a Clan score/sort of clan TS rating and a record of which clan beat which in official clan battles
official clan battles being only clan members vs clan members
at least 2v2
clan homebase - Raghna suggestion - it would be nice to eventually make clans foght over maps (or worlds) like in ZK planetwars
and display on the website that a given map (worlds) now belongs to a given clan
with other clans able to challenge the current inhabitants to win it over

#### Brothers
- Clan challenges, rewards/levels for completing them
-  Stats, LOTS of stats

#### Beherith
- Home planets for clans and some form of clan wars would be epic indeed


#### Planned DB structure
Clan
- name: String
- tag: String
- icon: String (option of an SVG image?)
- colour1: String
- colour2: String

ClanMember
- user: UserID
- clan: ClanID
- role: String (admin, mod, member, player)

ClanMemberRequest
- user: UserID
- clan: ClanID
