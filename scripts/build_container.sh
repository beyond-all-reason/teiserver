#!/usr/bin/env bash
# This is called from bin/deploy, you should not need to call it manually

docker build -t teiserver:output --target output .
