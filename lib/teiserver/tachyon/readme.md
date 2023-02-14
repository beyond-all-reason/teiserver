To get the files run
```bash
# We're not getting them from elsewhere at this stage
```

To build the files run
```bash
protoc --elixir_out=gen_descriptors=true,plugins=grpc:. lib/teiserver/tachyon/tachyon.proto
```
