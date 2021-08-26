#!/usr/bin/env bash
docker run -v $(pwd):/opt/build --rm -it teiserver:latest /opt/build/bin/build
