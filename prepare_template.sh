#!/bin/bash

TEMPLATE_DIR=$1

if [ -z "$TEMPLATE_DIR" ] ; then
    echo "USAGE:"
    echo "  $> $0 /path/to/template-directory"
    exit 1
fi

export PATH="$PATH":"$HOME/.pub-cache/bin"

dart pub global run project_template prepare -d "$TEMPLATE_DIR" -o lib/src/template/bones_ui_app_template.tar.gz -r "^\.git" -r "\.DS_Store$"
