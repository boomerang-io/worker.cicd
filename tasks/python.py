import re
from pathlib import Path

from invoke import Context, task


@task()
def clean_pyc(ctx: Context):
    ctx.run("find ./ -name '*.pyc'")


@task()
def self_update(ctx: Context, git_remote=None, git_branch="main"):
    """Updates these scripts if they were cloned to ~/tasks or added as submodule"""
    folder = show_folder(ctx)
    if not git_remote:
        remote_line = ctx.run(f"git -C {folder} remote -v ").stdout.splitlines()[0]
        git_remote, *_ = re.split(r"\s+", remote_line)
    ctx.run(f"git -C {folder} pull {git_remote} {git_branch}", echo=True)


@task(autoprint=True)
def show_folder(
    ctx: Context,
):
    """Shows the folder where the taskfiles repo infers it's installed to"""
    # TODO: Check how this would work in a shiv/pex format
    folder = Path(__file__).resolve().parent
    return folder
