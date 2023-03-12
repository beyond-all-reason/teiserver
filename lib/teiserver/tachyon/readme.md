To get and build the files run
```bash
curl -o lib/teiserver/tachyon/tachyon.proto https://raw.githubusercontent.com/beyond-all-reason/tachyon/master/protos/tachyon.proto
protoc --elixir_out=gen_descriptors=true:. lib/teiserver/tachyon/tachyon.proto
```
