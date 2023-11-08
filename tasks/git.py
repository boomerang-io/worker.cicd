import os
import re
import shlex
from subprocess import check_output
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List

from invoke import Context, Result, task

from ._utils import get_git_root_directory, picker, select_branch


PUSH_ALL_REMOTES_SKIP = os.environ.get("PUSH_ALL_REMOTES_SKIP", "").split(",")


@task(autoprint=True)
def get_commit_hash(ctx) -> str:
    """
    Gets the top level directory of the git repository
    """
    return check_output(shlex.split("git rev-parse HEAD")).decode("utf-8").strip()


@task(autoprint=True)
def git_checkout_clean(ctx) -> str:
    """
    Returns clean if there are no un-committed changes, dirty otherwise.
    """
    if not ctx.run("git status", hide=True, warn=True).ok:
        sys.exit("no-repo")
    if ctx.run("git diff --quiet", hide=True, warn=True).ok:
        return "clean"
    else:
        return "dirty"


@task(autoprint=True)
def git_branch_name(ctx) -> str:
    """
    Gets the branch name (from HEAD)
    """
    return ctx.run("git rev-parse --abbrev-ref HEAD", hide=True).stdout.strip()


@task(help={"host": "The host to "})
def git_push_and_pull_data(
    ctx: Context,
    host=None,
    branch=None,
    remote="origin",
    remote_checkout="/home/nahuel/workspace/workbench-geospatial-backend",
):
    """
    Push, pull in the remote
    """
    host = host or os.environ.get("REMOTE_GIT_HOST")
    ctx.run(f"git push {remote} HEAD", echo=True)
    ctx.run(f"ssh {host} cd {remote_checkout} && git fetch {remote}", echo=True)
    branch = branch or ctx.run("git rev-parse --abbrev-ref HEAD").stdout.strip()
    ctx.run(
        f"ssh {host} cd {remote_checkout} && "
        f"git status --untracked-files=no --porcelain && "
        f"git reset --hard origin/{branch}",
        echo=True,
    )


@task(
    help={
        "branch": "A git branch to create the worktree on, if not given will "
        "try to use fzf for interactive selection.",
        "path": "The path were to create the worktrees, by default is ../",
        "suffix": "Adds a suffix to the worktree name",
    }
)
def worktree(ctx: Context, branch=None, path=None, suffix: str = None):
    """Create a git worktree for reviewing a pull request. This feature is no available
    in VSCode. In order to create more than one worktree for the same branch use suffix
    """
    root = Path(get_git_root_directory())
    if not branch:
        branch = select_branch(ctx)
        if not branch:
            sys.exit("Cancelled by the user.")
    with ctx.cd(root):
        if not path:
            this_dir_name = ctx.run("basename $(pwd)", hide=True).stdout.strip()
            branch_name_no_slash = branch.replace("/", "_")
            name = f"{this_dir_name}.worktree.{branch_name_no_slash}"
            if suffix:
                name = f"{name}.{suffix}"
            path = f"../{name}"
        worktree_creation = ctx.run(
            f"git worktree add {path} {branch}", echo=True, warn=True
        )
        if worktree_creation.ok:
            print(f"Git worktree created in {path}")
        ctx.run("git worktree list", echo=True)

        # Settings
        # TODO: Check what's needed for a full review environment
        # TODO: Separate this?
        if worktree_creation.ok:
            print(f"Git worktree created in {path}")
            dot_env = root / ".env"
            if dot_env.is_file():
                print("Copying the env files")
                new_worktree_dot_env = (Path(root) / path / ".env").resolve()
                new_worktree_dot_env.write_text(
                    dot_env.read_text()
                    + f"\nCOMPOSE_PROJECT_NAME={branch_name_no_slash}"
                )


@dataclass
class WorktreeItem:
    path: Path
    head: str
    branch: str

    def __post_init__(self):
        if not isinstance(self.path, Path):
            self.path = Path(self.path)

    @classmethod
    def from_git_worktree(cls, path_head_branch_lines: str) -> "WorktreeItem":
        path, head, branch = (
            line.split(" ")[1] for line in path_head_branch_lines.splitlines()
        )
        return cls(path, head, branch)

    @property
    def branch_name(self):
        return self.branch.replace("refs/heads/", "")

    def __str__(self):
        return f"{self.path} [ {self.branch_name} ] {self.head[:8]}"


@task(autoprint=True)
def get_git_worktrees(ctx: Context, git_repo_root=None) -> List[WorktreeItem]:
    """Get a list of worktree data"""
    args = "" if not git_repo_root else f"-C {git_repo_root}"
    worktrees_path_head_branch_list = ctx.run(
        f"git {args} worktree list --porcelain", hide="out"
    ).stdout.split("\n\n")
    worktree_list = [
        WorktreeItem.from_git_worktree(lines)
        for lines in worktrees_path_head_branch_list
        if lines  # last empty line
    ]
    return worktree_list


@task(
    help={
        "others": "Only list the worktrees not matching with the current path",
        "porcelain": "Only print path",
    }
)
def worktree_list(ctx: Context, others=False, porcelain=False):
    """List worktrees and displays the one in use.
    TIP: If working with 2 worktrees, a quick switch can be implemented
    with:
        inv worktree-list --porcelain --others | xargs code --new-window
    """
    root = Path(get_git_root_directory())
    with ctx.cd(root):
        worktrees = get_git_worktrees(ctx)
        if others:
            worktrees = [wt for wt in worktrees if wt.path != root]
        for worktree_item in worktrees:
            current = root == worktree_item.path
            if not porcelain:
                print(f"[{'*' if current else ' '}] {worktree_item}")
            else:
                print(worktree_item.path)


@task()
def worktree_editor_open(ctx: Context, default_editor=None):
    """Opens the editor in a worktree"""
    editor = os.environ.get("EDITOR", default=default_editor or "code")
    root = Path(get_git_root_directory())
    others_worktrees = {
        worktree.branch_name: worktree
        for worktree in get_git_worktrees(ctx)
        if worktree.path != root
    }
    selected = picker(
        ctx,
        others_worktrees,
        prompt=f"Which worktree to open with {shlex.quote(editor)}? ",
    )
    if not selected:
        sys.exit("Cancelled by the user.")
    path = others_worktrees[selected].path
    ctx.run(f"{editor} {path}", echo=True)


@task(
    help={
        "ref": "Branch or reference",
        "skip": "List of remotes to skip, defaults to $PUSH_ALL_REMOTES_SKIP. "
        "Argument overrides environment variable contents",
        "verbose": "Print debug information",
    }
)
def push_all_remotes(ctx: Context, ref="HEAD", skip=[], verbose=False):
    """git push to all registered remotes"""
    remotes: Result = ctx.run("git remote -v", hide=True, warn=True)
    if not remotes.ok:
        sys.exit("Not a git repo?")

    # CLI overrides
    skip = skip or PUSH_ALL_REMOTES_SKIP

    if verbose:
        print(f"Skipping these remote names: {','.join(skip)}", file=sys.stderr)
    push_remotes = [
        remote for remote in remotes.stdout.splitlines() if "push" in remote
    ]
    names = {re.split(r"\s+", line)[0] for line in push_remotes} - set(skip)
    if not names:
        sys.exit("No remotes to push to 😢")
    all_push_ok = True
    for remote in names:
        result: Result = ctx.run(
            f"git push {remote} {ref}", echo=True, pty=True, warn=True
        )
        all_push_ok &= result.ok
    if not all_push_ok:
        sys.exit("Some remotes failed.")


@task()
def worktree_cleanup(ctx: Context, git_repo_root=None):
    """Deletes worktrees created by inv worktree-create"""
    if git_repo_root:
        git_args = f"-C {git_repo_root}"
    worktrees: List[WorktreeItem] = get_git_worktrees(ctx, git_repo_root=git_repo_root)

    for worktree_item in worktrees:
        if ".worktree" in str(worktree_item.path):
            ctx.run(f"git {git_args} worktree remove {worktree_item.path}")


@task()
def submodule_update(ctx: Context):
    """Shorthand for updating the submodules from remotes recursively"""
    ctx.run("git submodule update --remote --recursive")
