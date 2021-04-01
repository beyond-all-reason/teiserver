Parties are adhoc groups of players that wish to play together; often on the same team though not at the expense of balance. Of particular use when matchmaking a team game.

## Client to Server messages
- Create party `c.party.create`
- Get party info `c.party.get_info`
- Invite to party `c.party.invite username`
- Accept invite to party `c.party.accept username` (username of the person that sent the invite, it's possible there might be multiple invites pending)
- Transfer leadership `c.party.leader username`
- Leave party `c.party.leave`
- Message party `c.party.message message`

## Server to Client messages
- Send party info/member update `s.party.joined username`, `s.party.left username`
- Party invite receipt, `s.party.invited member_list`
- Party invite responded to, `s.party.accepted username`, `s.party.declined username`
- Message from party member `s.party.message username message`

## Structure of a party
- name: String
- boss: UserID
- members: List(UserID)
- options: Map(String => String) *(Things like all players in the party being from the same clan)*
