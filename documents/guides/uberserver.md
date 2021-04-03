**Disclaimer:** This is written as an alternative to Uberserver. If you are happy with Uberserver then you don't need to change to Teiserver. The Uberserver team have done a fantastic job writing a stable and long lasting server which has aged very well for software.

### Steps
Setup server
Deploy code
Run ubereserver_convert.py on export
Import json into Teiserver

### Functional differences
- Additional web interface
- Password security (Argon2 vs md5)

### Technical differences
- Elixir (OTP) instead of Twisted Python
- Postgres instead of MySQL
