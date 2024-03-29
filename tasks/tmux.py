from pathlib import Path

from invoke import Context, task

from ._utils import picker


@task()
def edit_tmuxp_conf(ctx: Context, editor=None):
    files = list(Path("~/.tmuxp").expanduser().glob("*.yaml"))
    to_edit = picker(ctx, files)
    ctx.run(f"$EDITOR {to_edit}", env={"EDITOR": editor or "code --wait"})
