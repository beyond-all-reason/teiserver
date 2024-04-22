## In progress
#### Features
- Added `country` to public [leaderboard API response](https://server4.beyondallreason.info/teiserver/api/public/leaderboard/Team)
- Display uncertainy values for each match
- Show intuitive chevron rank number
- Scroll big tables on narrow screens
- Better moderation log formatting
- Extend leaderboards from 30 to 100 positions
- Documentation improvements
#### Bugfixes
- Test fixes
- Moderation related fixes and improvements
- Fix splitlobby error when original splitter leaves lobby
- Not allowing spaces in custom flags
#### Internal improvements
- Replace Parallel with ParallelStream
- Add Github action for tests
## v1.2.0
#### Features
- New spring friendship commands added
- Spring `c.user.whois` command added
- Spring `c.user.accept_friend_request` command added
- Spring `c.user.decline_friend_request` command added
- Added microblog report
- Added RSS feed to microblog
- Tags for the microblog can now be filtered
- Microblog posts now have a datetime shown beneath their title and we've split the summary out from the content completely
- Completely removed notification system
- If avoided or blocked by a lobby boss, you cannot join that lobby
- Text callbacks now work as discord commands
- Telemetry log for when a user kicks another user
- Added ability to manually add smurf keys

#### Bugfixes
- Relationships report now correctly combines Block/Avoid
- Relationships report correctly reports on Ignore counts
- Fixed issue where a LobbyPolicy bot could repeatedly rename a lobby
- Fixed incorrect output of `c.user.list_relationships`
- Fixed possible cause of an infinite redirect if cookies are borked
- Fixed a bug where renaming could leave a cached value pointing to the wrong place
- Fixed a bug where a smurf could still access the website
- Fixed a bug where match UUIDs might sometimes not be present in the tags
- Fixed a bug when cleaning up older battles with a report attached
- Fixed an auth bug on the admin chat interface

#### Internal improvements
- Added `Communication.use_discord?/1` to make it easier to not make discord calls in dev
- Unit tests for microblog system
- Converted some tests for old pages into the new liveview pages
- Moved nearly all of the `Central` stuff over to be part of Teiserver
- Started making progress on
- Added `hms_or_hms_ymd` format to `TimexHelper`
- Added framework for adding more discord commands
- Better internal event tracking for disconnects

## v1.1.1
* Report forms now include the option to ignore players along with buttons to avoid or block them
* Ignoring is now separate from avoiding or blocking
* The `$meme` commands have been expanded significantly (credit: robertthepie)
* Contributors can set their own flag
* Moderation action updates/deletions now propagate to the discord

## v1.1.0

- I didn't bother with a changelog because I was lazy and kept putting it off
