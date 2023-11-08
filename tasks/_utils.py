"""
Utilities to use from task definitions
"""
from dataclasses import dataclass, fields
from datetime import datetime
import json
import os
import re
import shlex
import sys
from functools import lru_cache
from pathlib import Path
from shlex import split
from shutil import which
from subprocess import check_output
from tempfile import NamedTemporaryFile
from textwrap import dedent
from typing import Any, Dict, Iterator, List, Optional, Union
from urllib.request import Request

from invoke import Context, task, Result


@lru_cache
def get_git_root_directory() -> str:
    """
    Gets the top level directory of the git repository
    """
    return check_output(split("git rev-parse --show-toplevel")).decode("utf-8").strip()


@lru_cache
def get_git_root_path() -> Path:
    """
    Gets the top level directory of the git repository
    """
    return Path(get_git_root_directory())


def _cos_creds_to_env_dict(path_to_creds) -> Dict[str, str]:
    creds_dict: Dict = json.loads(Path(path_to_creds).read_text())
    return {
        "FSSPEC_S3_ENDPOINT_URL": "https://s3.us-east.cloud-object-storage.appdomain.cloud",
        # "FSSPEC_S3_ENDPOINT_URL": "https://s3.private.us-east.cloud-object-storage.appdomain.cloud",
        "FSSPEC_S3_KEY": creds_dict["cos_hmac_keys"]["access_key_id"],
        "FSSPEC_S3_SECRET": creds_dict["cos_hmac_keys"]["secret_access_key"],
        "AWS_ACCESS_KEY_ID": creds_dict["cos_hmac_keys"]["access_key_id"],
        "AWS_SECRET_ACCESS_KEY": creds_dict["cos_hmac_keys"]["secret_access_key"],
    }


def cmd_based_selector(prompt, options, default=None):
    ...


FZF_FANCY_CHOOSER = dedent(
    """
    git branch -a -vv --color=always | grep -v '/HEAD\\s' | \
    fzf --height 40% --ansi --multi --tac \
    | sed 's/^..//' | awk '{print $1}' | \
    sed 's#^remotes/[^/]*/##'
    """.strip()
)


def select_branch(ctx: Context, query="Please select a branch") -> str:
    """Returns a branch name in interactive mode"""
    # Interactively select a branch
    assert isinstance(ctx, Context)
    if which("fzf"):
        selected_branch: str = ctx.run(f'bash -c "{FZF_FANCY_CHOOSER}"').stdout
        try:
            branch, commit, name = re.split(r"\s+", selected_branch, maxsplit=2)
        except ValueError:
            # User cancelled
            return None
        return branch
    else:
        # TODO: Find a way to do this with stdlib
        raise NotImplementedError("Please install fzf with brew/nix")


# We don't decorate this function so it's not exposed
# We can change our mind later about it.
@task(autoprint=True)
def find_compose_command(ctx: Context):
    if which("docker"):
        ctx.config.COMPOSE_COMMAND = "docker compose"
    elif which("podman"):
        if which("podman-compose"):
            ctx.config.COMPOSE_COMMAND = "podman-compose"
        else:
            sys.exit("You need to install podman-compose")
    return ctx.config.COMPOSE_COMMAND


def dict_to_dataclass(
    data: Dict[str, Any],
    dt: dataclass,
):
    """Create a dataclass with only the fields in the dataclass"""
    fields_to_include = {f.name for f in fields(dt)}
    init_values = {
        name: value for name, value in data.items() if name in fields_to_include
    }
    return dt(
        **init_values,
    )


def filter_list_of_strings_by_pattern(
    list_of_strings: List[str], exclude_list=List[str]
) -> Iterator[str]:
    """
    Given a list of strings, will return only those that don't have one of the
    filter strings
    """
    for string in list_of_strings:
        ok = True
        for exclusion in exclude_list:
            if exclusion in string:
                ok = False
                break
        if ok:
            yield string


# CommitHash = Annotated[str, "The commit hash used to tag images"]
# CommitComment = Annotated[str, "The first line of the commit"]
# CommitDate = Annotated[datetime, "The date the commit was authored"]
# CommitDict = Dict[CommitHash, CommitComment]


def get_commit_dict(
    ctx: Context, branch="origin/main", pre_fetch=True
) -> Dict[str, Any]:
    """Get the commit list for a branch"""
    result = {}
    if pre_fetch:
        ctx.run("git fetch origin", warn=True)
    try:
        # https://git-scm.com/docs/pretty-formats
        commits: List[str] = ctx.run(
            f"git log {branch} --pretty='%H %at %s'", hide="out"
        ).stdout.splitlines()
        for hash_msg_line in commits:
            hash_, timestamp, msg = hash_msg_line.split(" ", maxsplit=2)
            result[hash_] = {
                "message": msg,
                "date": datetime.fromtimestamp(int(timestamp)),
            }
    except Exception as error:
        print(f"Error parsing the commit list: {error}", file=sys.stderr)

    return result


@task(
    autoprint=True,
    help={
        "options": "A list of options",
        "prompt": "Prompt to show",
        "empty": "Empty value",
        "query": "Initial query",
    },
)
def picker(
    ctx: Context,
    options: Union[Dict[str, Any], List[str]] = [],
    prompt=None,
    empty=None,
    query=None,
) -> Optional[str]:
    """A fzf wrapper"""
    if not options:
        return ""
    elif isinstance(options, Result):
        options = options.stdout.splitlines()
    if not which("fzf"):
        from .setup import install_fzf

        try:
            install_fzf(
                ctx,
            )
        except:  # noqa: E722
            print("Couldn't auto-install fzf from setup scripts", file=sys.stderr)
            sys.exit("Please install fzf manually")
    with NamedTemporaryFile("w", suffix="picker_options") as options_file:
        options_file.write("\n".join(str(opt) for opt in options))
        options_file.flush()
        parent = Path(options_file.name).parent
        target = parent / "selected.txt"
        fzf_args = "" if not prompt else f"--prompt {shlex.quote(prompt)}"
        if query:
            fzf_args = f"{fzf_args} --query {query}"
        os.system(f"fzf  {fzf_args} <{options_file.name} > {target}")
        result = target.read_text().strip()
        if result and result == empty:
            return ""
        return result


def get_git_remotes(
    ctx: Context, path: Union[str, Path], verbose=False
) -> Optional[Dict[str, str]]:
    """
    Returns a dictionary with the remotes of a git repo pointed by path
    """
    git_remotes: Result = ctx.run(
        f"git -C {path} remote -v", hide=not verbose, warn=True
    )
    if not git_remotes.ok:
        return None
    result: Dict[str, str] = {}
    for remote_line in git_remotes.stdout.splitlines():
        name, url, *_ = re.split(r"\s+", remote_line)
        result[name] = url
    return result


def create_request(url) -> Request:
    """Creates a Request object with headers"""
    req = Request(
        url,
        data=None,
        headers={
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_3) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/35.0.1916.47 Safari/537.36"
        },
    )
    return req
