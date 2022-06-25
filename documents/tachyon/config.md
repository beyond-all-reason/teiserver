##
A set of commands for getting/setting configs. Not to be confused with user_configs.

## Game configs
Game configs are a key-value store with no enforced structure. You can add keys as you wish, you can update keys to any type. Keys must be strings though values can be strings, integers, booleans, lists or even maps.

Note this is not designed to be a large data store, please don't store large blobs of data in it.

### `c.config.game_set`
```json
{
  "cmd": "c.config.game_set",
  "configs": {
    "key1": "value1",
    "key2": "123",
  }
}
```

### `c.config.game_get`
If a game config hasn't been set or is nil it will be absent from the results.
```json
{
  "cmd": "c.config.game_get",
  "keys": ["key1", "key2", "missing_key"]
}

{
  "cmd": "s.config.game_get",
  "configs": {
    "key1": "value1",
    "key2": "123",
  }
}
```

### `c.config.game_delete`
```json
{
  "cmd": "c.config.game_set",
  "keys": ["value1", "123"]
}
```

## User configs
User configs are tied to the Teiserver structured configs that can be accessed on the site itself. These are constrained by data type (though will where possible convert inputs to that data type) and come with defaults.

### `c.config.list_user_types`
Lists the types of configs available to get/set.
```json
{
  "cmd": "c.config.list_user_types"
}

{
  "cmd": "s.config.list_user_types",
  "configs": [
    UserConfigType,
    UserConfigType,
  ]
}
```

### `c.config.user_set`
```json
{
  "cmd": "c.config.user_set",
  "configs": {
    "key1": "value1",
    "key2": "123",
  }
}
```

### `c.config.user_get`
```json
{
  "cmd": "c.config.user_get",
  "keys": ["key1", "key2"]
}

{
  "cmd": "s.config.user_get",
  "configs": {
    "key1": "value1",
    "key2": "123",
  }
}
```
