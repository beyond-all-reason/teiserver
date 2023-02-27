#!/usr/bin/env bash
# This is called from bin/deploy, you should not need to call it manually

docker buildx build --build-arg env=prod -t teiserver:latest .
