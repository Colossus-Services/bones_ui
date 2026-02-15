#!/bin/bash

APIKEY=$1
shift  # remove the first argument (API key) from "$@"

## dart pub global activate dart_bump

dart_bump . \
  --extra-file "lib/src/bones_ui.dart=static\\s+const\\s+String\\s+version\\s+=\\s+['\"]([\\w.\\-]+)['\"]" \
  --api-key $APIKEY \
  "$@"
