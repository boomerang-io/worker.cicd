import sys
from datetime import datetime, timedelta
from pathlib import Path

from invoke import Context, task


@task()
def delete_screenshots(ctx: Context, all=False, older_than_days=1, dry_run=False):
    """Deletes screenshots from desktop"""
    to_delete = Path("~/Desktop/").expanduser().glob("Screenshot*png")
    if not all:
        if older_than_days < 0:
            sys.exit("Days can't be negative")
        threshold = datetime.now() - timedelta(days=older_than_days)

        def is_old_enough(p: Path) -> bool:
            creation_date = datetime.fromtimestamp(p.stat().st_ctime)
            return creation_date < threshold

        to_delete = [p for p in to_delete if is_old_enough(p)]
    for deletable in to_delete:
        if not dry_run:
            deletable.unlink()
        else:
            print(f"Would have deleted {deletable}")


@task(help={"warn": "Warn on app exit failure"})
def tell_application_to_quit(ctx, application_name: str, warn=False):
    """Use osasccript in OSX to tell an application to quit"""
    script = f'quit app "{application_name}"'
    return ctx.run(f"osascript -e {script}", echo=True, warn=warn)
