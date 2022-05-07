# Goals
In matchmaking you have an ever-changing pool of potential players who you are trying to match up to the best of your ability. In an ideal world when a person joins the queue they will have a comparable skill level opponent join at the same time. In reality the queue will be a constantly shifting slope of skill levels. As such we want to:
- Minimise the amount of time a player will spend waiting for an opponent
- Minimise gap in rating/skill between any two players matched with each other

### Problem - Scaling
A naive solution would be to constantly compare every player to every other player and over time loosen the requirements for two players to match. The issue here is this is `O(n^2)` complexity and will not scale; doubling the number of players could quadruple the comparisons to make.

We can optimise this by never allowing a player of lower skill to match the higher skill and always making the match happen from the higher skilled player. This would result in a complexity of `O(n^2 / 2)` which while better still scales badly even if not as badly.

### Solution - Buckets
My proposed solution is to use buckets. Each player is placed in a bucket, the bucket is derived in some way from the skill rating of the player (e.g. rounding their skill to the nearest integer). Players then gradually search buckets further and further away the longer they wait.

## Example
We have 3 players in a 1v1 queue, Pawn20 and Grunt17. Their bucket numbers are 20 and 17 respectively. We'll have Pawn20 start in the queue and then add Grunt17 at a later stage.

#### Cycle 0
Pawn20, no other opponents within range (20)

#### Cycle 1 (increase range)
Pawn20, no other opponents within range (19-21)
Add Grunt17
Grunt17, no other opponents within range (17)

#### Cycle 2 (increase range)
Pawn20, no other opponents within range (18-22)
Grunt17, no other opponents within range (16-18)

#### Cycle 3 (increase range)
Pawn20, one opponent within range (17-23) but their range isn't enough to match with us
Grunt17, no other opponents within range (15-19)

#### Cycle 4 (increase range)
Pawn20, found opponent (Grunt17)
Grunt17, match has been found for this player so they are not checked

### Settings and improvements
We can tweak any of the following values to alter the behaviour of the algorithm:
- Bucket function
- Range increase rate
- Range maximum (could be a static value or a % of your skill or some combo item)
- Reciprocal range requirement (100% = you need to be within their range too, 50% = they need to be at least halfway, 0% = if you can match them they are playing with you)
- Check rate

As with the naive solution we can optimise this by only ever having a player look below themselves for matches halving the number of checks needed every cycle. Alternately given the reciprocal range option we might want to only look above instead.

### Suggested initial settings
Given our use of TrueSkill at the current time my suggested initial settings would be:
- Bucket function - `round()`
- Range increase rate - `1 every 20 seconds`
- Range maximum - `10`
- Reciprocal range requirement - `100%`
- Check rate - `every 250ms`

## Match found
Once a pairing is found a MatchServer is created. It selects a lobby, ensures they are both ready and such. If the MatchServer fails it can re-add both of these to the QueueServer at the same priority and rating as when they left and their search can resume.

## Implementation
##### Check function
I'll use a GenServer per queue and have a check function on a timer. Every check it will perform the above algorithm. If no matches are found it will set the `skip` flag to true. If this flag is enable then the check will short-circuit and skip since nothing has changed.

The `skip` flag can be set to true when a new player joins the queue or when the ranges increase. The ranges will increase on a separate repeating function call.

##### Data structure
The buckets themselves can be stored as a map of lists:
```elixir
%{
  1 => [...],
  2 => [...],
  3 => [...],
}
```

Each player can be stored as a tuple in their respective bucket:

```elixir
  # If a single user
  {user_id, current_range, :user}
  
  # If a party
  {party_id, current_range, :party}
```

We don't need to store their bucket number since they will be stored under said bucket number and it will always be accessible.

