## in progress:

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

#### Bugfixes

- Relationships report now correctly combines Block/Avoid
- Relationships report correctly reports on Ignore counts
- Fixed issue where a LobbyPolicy bot could repeatedly rename a lobby
- Fixed incorrect output of `c.user.list_relationships`
- Fixed possible cause of an infinite redirect if cookies are borked

#### Internal improvements

- Added `Communication.use_discord?/1` to make it easier to not make discord calls in dev
- Unit tests for microblog system
- Converted some tests for old pages into the new liveview pages
- Moved nearly all of the `Central` stuff over to be part of Teiserver
- Started making progress on

## v1.1.1

* Report forms now include the option to ignore players along with buttons to avoid or block them
* Ignoring is now separate from avoiding or blocking
* The `$meme` commands have been expanded significantly (credit: robertthepie)
* Contributors can set their own flag
* Moderation action updates/deletions now propagate to the discord

## v1.1.0

- I didn't bother with a changelog because I was lazy and kept putting it off
