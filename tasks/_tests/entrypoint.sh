#!/usr/bin/env bash
set -xeuo pipefail

COMMAND="$@"

if [ -z "$COMMAND" ]; then
    COMMAND="inv install-all"
fi

set -euo pipefail
python -m pip install invoke ${EXTRA_PACKAGES:-}
pwd
exec $COMMAND
