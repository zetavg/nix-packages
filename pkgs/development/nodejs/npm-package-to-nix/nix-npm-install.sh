#!/usr/bin/env bash
#
# A wrapper for `npm install` to only generate the package-lock.json, instead
# of checking node_modules and downloading dependencies

set -e

npm install --package-lock-only "$@"
