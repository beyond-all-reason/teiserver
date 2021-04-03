"""
This script is designed to take the database export from uberserver and convert it into data for your Teiserver implementation.

1 - Feed the backup.sql file into this script (e.g. python3 uberserver_convert.py backup.sql)
2 - Take the exported data (uberserver_export.json) and feed that into your Teiserver importer (Teiserver -> Tools -> Uberserver)
3 - It might take a while to complete as it will need to perform the password encryption process for every user

To use this script you will need to:
  pip install sqlparse
"""

import sqlparse
import sys
import re
import json

include_tables = ["friendRequests", "friends", "ignores", "users", "verifications"]

def get_queries(db_file):
  with open(db_file, "r") as f:
    content = f.read()
    queries = sqlparse.split(content)

  query_map = {}

  # Load up and parse the queries, skipping ones we don't want to make use of
  for q in queries:
    query_string = str(q)
    if query_string[0:11] != "INSERT INTO":
      continue
    table_name = re.search(
        r'INSERT INTO `([a-zA-Z_]+)`', query_string).groups()[0]

    query_map[table_name] = q

  return query_map

# Uberserver does not enforce email uniqueness, Teiserver does
# this means we need to take into account some emails may
# exist more than once and deal with it accordingly
# duplicated emails will appear in the output json under the key
# "duplicated_emails" in case you need to alter your users
# after the fact
def find_duplicated_emails(rows):
  all_emails = []
  dupes = []

  for row in rows:
    parts = row.replace("(", "").replace(")", "").split(",")
    [_key, _username, _password, _salt, _register_date, _last_login,
    _last_ip, _last_id, _ingame_time, _access, email, _bot] = parts

    email = email[1:-1]
    if email in all_emails:
      if email not in dupes:
        dupes.append(email)
    else:
      all_emails.append(email)
  
  return dupes

def get_users(users_query):
  q = sqlparse.parse(users_query)[0]
  inserts = q.tokens[6]
  rows = re.findall(r"\(.+?\)", str(inserts))
  duplicated_emails = find_duplicated_emails(rows)

  results = {}
  for row in rows:
    parts = row.replace("(", "").replace(")", "").split(",")
    [key, username, password, _salt, _register_date, _last_login,
     last_ip, _last_id, ingame_time, access, email, bot] = parts

    username = username[1:-1]
    email = email[1:-1]
    if email in duplicated_emails:
      email = f"{username}_{email}"

    results[int(key)] = {
        "username": username,
        "password": password[1:-1],
        "last_ip": last_ip[1:-1],
        "ingame_time": ingame_time,
        "access": access[1:-1],
        "email": email,
        "bot": bot,
        "friends": [],
        "ignores": [],
        "requests": [],
        "verification_code": None
    }

  return (results, duplicated_emails)

def add_friends(users, friends_query):
  q = sqlparse.parse(friends_query)[0]
  inserts = q.tokens[6]

  rows = re.findall(r"\(.+?\)", str(inserts))

  for row in rows:
    parts = row.split(",")
    [_id, first_user, second_user, _time] = parts
    first_user = int(first_user)
    second_user = int(second_user)

    users[first_user]["friends"] += [second_user]
    users[second_user]["friends"] += [first_user]

  return users


def add_ignores(users, ignores_query):
  q = sqlparse.parse(ignores_query)[0]
  inserts = q.tokens[6]

  rows = re.findall(r"\(.+?\)", str(inserts))

  for row in rows:
    parts = row.split(",")
    [_id, user, ignored, _reason, _time] = parts
    user = int(user)
    ignored = int(ignored)

    users[user]["ignores"] += [ignored]

  return users


def add_friend_requests(users, requests_query):
  q = sqlparse.parse(requests_query)[0]
  inserts = q.tokens[6]

  rows = re.findall(r"\(.+?\)", str(inserts))

  for row in rows:
    parts = row.split(",")
    [_id, requester_id, requested_id, _msg, _time] = parts
    requester_id = int(requester_id)
    requested_id = int(requested_id)

    users[requested_id]["requests"] += [requester_id]

  return users


def add_verifications(users, verifications_query):
  q = sqlparse.parse(verifications_query)[0]
  inserts = q.tokens[6]

  rows = re.findall(r"\(.+?\)", str(inserts))

  for row in rows:
    parts = row.split(",")
    [_id, user, _email, code, _expiry, _attempts,
     _resends, _use_delay, _reason] = parts
    user = int(user)

    users[user]["verification_code"] = code

  return users


def write_script(users):
  with open("uberserver_export.json", "w") as f:
    f.write(json.dumps(users))

if __name__ == '__main__':
  [_, db_file] = sys.argv

  query_map = get_queries(db_file)
  print("Got queries")

  # Now build up the users table
  (users, duplicated_emails) = get_users(query_map["users"])
  print("Built users")

  users = add_friends(users, query_map["friends"])
  print("Built friends")

  users = add_ignores(users, query_map["ignores"])
  print("Built ignores")

  users = add_friend_requests(users, query_map["friendRequests"])
  print("Built requests")

  users = add_verifications(users, query_map["verifications"])
  print("Built verifications")

  write_script({
    "users": users,
    "duplicated_emails": duplicated_emails
  })
