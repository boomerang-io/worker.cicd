import sys
from pathlib import Path

from ._discovery import find_and_import_tasks

try:
    ns = find_and_import_tasks(where=Path(__path__[0]))
except Exception as error:
    # Manual import, failsafe mode
    print(f"During auto-import the following error occurred: {error}", file=sys.stderr)
