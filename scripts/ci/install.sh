#!/bin/bash
echo "test"
docker --version
docker images -a
docker images -a -q
docker ps -a