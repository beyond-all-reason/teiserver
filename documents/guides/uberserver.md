**Disclaimer:** Teiserver is written as an alternative to Uberserver. If you are happy with Uberserver and it does everything you need then you don't need to change to Teiserver. The Uberserver team have done a fantastic job writing a stable and long lasting server which has aged very well for software.

### Conversion process
- Setup server [Linux](production_setup_linux.md)/[Windows](production_setup_windows.md)
- [Deploy code](deployment.md)
- Run [ubereserver_convert.py](../prod/uberserver_convert.py) on your database export
- Import json into Teiserver at: https://yourdomain.com/teiserver/admin/tools/convert
- Restart the server to recache the users right away

#### Caveat
Uberserver doesn't enforce unique email addresses while Teiserver does. In many cases bot accounts will have duplicate addresses and the conversion script will automatically mutate them (email + name combo) to allow the process to continue. A list of fund duplicates is included with the json output from the python converter. Some manual wiggling may be required.

### Functional differences
#### Additional web interface
Teiserver comes with a web interface. It is split into users and mods/admins. Users are able to access the battle list, account details the like. The admin side allows control and configuration of all other aspects of Teiserver not controlled by the source configs themselves.

While many of the web pages are standard ones, things like battles and client (admin) pages are live pages and will update in realtime as if you are a client.

#### Password security (Argon2 vs md5)
Passwords in Uberserver are stored as md5 converted into base64. This is because the spring protocol requires it. While I can't change spring protocol the passwords stored in Teiserver make use of Argon2 (encryption rather than hashing) and would represent a significantly harder target than md5 should the database be compromised.

In addition to storing spring-md5 passwords more securely, Teiserver allows for tokenised logins. Tokens can be requested over a secure connection and used in the future to login meaning the password doesn't need to be stored locally either.

#### Extended protocol
Teiserver is [implementing some additional commands](/documents/spring/extensions.md) as it seeks to add features beyond Uberserver. In the future a new protocol designed to prevent the O(n^2) problem is going to be implemented.

### Technical differences
#### Elixir (OTP) instead of Twisted Python
Python is notoriously bad at multithreading, Twisted is an attempt to improve this and was a wise choice in writing Uberserver. Elixir is built on top of Erlang which was designed precisely for this sort of middleware server. The inclusion of the OTP framework allows incredibly concurrent programs to be created.

#### Postgres instead of MySQL
For the purpose of the server there's very little difference between the two. This is more a note in case you have some aversion to Postgres.
