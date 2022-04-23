##
A set of commands for getting/setting user configs.

### TODO: `c.config.set`
```json
{
  "cmd": "c.config.set",
  "configs": {
    "key1": "value1",
    "key2": "123",
  }
}
```

### TODO: `c.config.get`
```json
{
  "cmd": "c.config.get",
  "keys": ["key1", "key2"]
}

{
  "cmd": "s.config.get",
  "configs": {
    "key1": "value1",
    "key2": "123",
  }
}
```

### `c.config.delete`
```json
{
  "cmd": "c.config.delete",
  "keys": ["key1", "key2"]
}
```
