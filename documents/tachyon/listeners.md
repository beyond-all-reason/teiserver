## Listeners
Tachyon uses Listeners to allow clients to subscribe to certain update channels. When you login you will be subscribed to a user update channel for that user, meaning if a server change happens to your account you'd receive a message (even if you were the one that prompted the change).

### Defaults
- You are subscribed to your own `user` channel
- You are subscribed to your own `private-chat` channel

### User
- Can subscribe to your friends to see changes to their users

### Battle
- Joining/Leaving a battle will sub/unsub you from the battle

### Chat room
- Joining/Leaving a chat room will sub/unsub you from the room
- You subscribe to messages by default

