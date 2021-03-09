Parties are adhoc groups of players that wish to play together; often on the same team though not at the expense of balance. Of particular use when matchmaking a team game.

## Client to Server messages
- Create party
- Get party info
- Invite to party
- Transfer bossmode
- Leave party

## Server to Client messages
- Confirm party is created (maybe just OK message?)
- Send party info/member update
- Party invite receipt

## Structure of a party
- name: String
- boss: UserID
- members: List(UserID)
