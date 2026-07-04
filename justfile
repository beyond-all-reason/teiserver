
# List available recipes
default:
    @just --list

# Run a dev cluster node, e.g. `just iex` or `just iex 2`
# Instance 1: http 4002, spring tcp 8200, metrics 4001; each further
# instance is offset by 100. Asset watchers only run on instance 1.
node instance='1':
    TEISERVER_HTTP_PORT=$((4002 + ({{instance}} - 1) * 100)) \
    TEI_SPRING_TCP_PORT=$((8200 + ({{instance}} - 1) * 100)) \
    TEI_METRICS_SERVER_PORT=$((4001 + ({{instance}} - 1) * 100)) \
    {{ if instance == '1' { '' } else { 'TEISERVER_WATCHERS=off' } }} \
    iex --name node{{instance}}@127.0.0.1 --cookie teiserver-dev -S mix phx.server
