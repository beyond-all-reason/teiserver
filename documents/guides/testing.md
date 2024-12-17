## Testing
Run as above (`mix run --no-halt`) and load up Chobby. Set Chobby's server to `localhost`. In my experience it's then fastest to restart Chobby and it will connect to your locally running instance. After you've finished you'll want to set the server back to `road-flag.bnr.la`.

You can login using the normal login command but it's much easier to login using `LI <username>` which is currently in place for testing purposes. `test_data.ex` has a bunch of existing users for testing purposes but you can use the protocols `REGISTER username password email` command to create a new user. State is currently not persisted over restarts. If you are familiar with Elixir then starting it with `iex -S mix` will put it in console mode and you can execute commands through the modules there too.

## Testing modules with specific tags
The balance test cases have `@moduletag :balance_test` and you can test them while excluding others:
```
mix test --only balance_test
```

## Integration tests
We have a separate project to perform integration tests on Teiserver called [Hailstorm](https://github.com/beyond-all-reason/hailstorm). All Hailstorm documentation is located on the Hailstorm repo.

## Debugging with VSCode using ElixirLS
You can run the server in the visual studio code debugger using the ElixirLS extension

For WSL users make sure Visual Studio Code is running using the WSL extention and is connected remotely to your WSL instance, for more info on how to do this consult [the relevant microsoft documentation](https://code.visualstudio.com/docs/remote/wsl) 

Next in the teiserver root directory open VSCode with 
`code .`

In extensions you need to install [ElixirLS](https://marketplace.visualstudio.com/items?itemName=JakeBecker.elixir-ls) 
If you have no Terminal open go to Terminal>Run to open a terminal in VS Code then click on Debug Console to have access to the program output and the Interactive REPL mode while debugging

Then make sure you have any elixir file selected and in the run and debug panel click on **create a launch.json file**

In the file you need to add the line `"task": "phx.server",` to the first configuration

the full launch.json should look like that:
```json
{
    "version": "0.2.0",
    "configurations": [

        {
            "type": "mix_task",
            "name": "mix (Default task)",
            "request": "launch",
            "task": "phx.server",
            "projectDir": "${workspaceRoot}"
        },
        {
            "type": "mix_task",
            "name": "mix test",
            "request": "launch",
            "task": "test",
            "taskArgs": [
                "--trace"
            ],
            "startApps": true,
            "projectDir": "${workspaceRoot}",
            "requireFiles": [
                "test/**/test_helper.exs",
                "test/**/*_test.exs"
            ]
        }
    ]
}
```

Then you can press the mix (Default task) button or F5 to start debugging. **It may take a while to start**

## Review test coverage of recently changed files
To get a quick list of recently changed files and their test coverage, run `scripts/show_test_coverage_for_files_changed_in_last_month.sh`

To update minimum test coverage requirements, edit `coveralls.json`