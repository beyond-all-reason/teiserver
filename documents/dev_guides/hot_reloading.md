# Hot Reloading code is risky business
That's right, if you do it wrong you can cause instability in your server; worst case scenario you need to re-release it but I wanted to make it clear this is something you should only do with this understanding.

### Required reading
I highly recommend you read [A guide to hot code reloading in Elixir](https://blog.appsignal.com/2021/07/27/a-guide-to-hot-code-reloading-in-elixir.html) on the AppSignal blog.

### Usage
1 - Identify the modules you have changed and thus want to reload
2 - Run the `hot_reload` script (be sure to modify it with your server address etc)
3 - Do what the script says to reload the modules


```python
#!/usr/bin/env python3
# Example usage:
# hot_reload Central.Helpers.TimexHelper Teiserver.Coordinator.ConsulCommands

import os, sys

hot_path = "hot_reload/opt/build/_build/prod/lib/central/ebin"

def do_build():
    os.system("sh scripts/build_container.sh")
    os.system("sh scripts/generate_release.sh")
    os.system("mix phx.digest.clean --all")

    os.system("mkdir -p hot_reload")
    os.system("cp rel/artifacts/teiserver.tar.gz hot_reload")
    os.system("cd hot_reload; tar mxfz teiserver.tar.gz")

def upload_file(name):
    os.system(
        f"scp -i rsa_key_path {hot_path}/Elixir.{name}.beam user@address:/apps/central/lib/central-0.1.0/ebin")

if __name__ == '__main__':
  module_list = sys.argv[1:]
  do_build()

  if module_list != []:
    # Upload
    for module in module_list:
        upload_file(module)
    
    # Print out instructions
    instructions = "ssh to server\n---\ncentralapp remote"
    for module in module_list:
      instructions += f"\n:code.load_file({module})"
      instructions += f"\n:code.purge({module})"
      instructions += f"\n:code.load_file({module})"

    print(instructions)
```
