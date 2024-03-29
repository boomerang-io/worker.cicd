from pathlib import Path
from typing import List
from invoke import task, Context
import sys
import re
import os
import string
import json
from string import Template


@task()
def load_envrc(ctx: Context, path_=".", verbose=False):
    """Helper function to load .env. Use if direnv is not available/setup/working"""
    path = Path(path_).resolve().absolute()
    envfile = None
    if path.is_dir():
        for name in [".env", ".envrc"]:
            computed_path = path / name
            if computed_path.exists():
                envfile = computed_path
                break
    elif path.is_file():
        envfile = path

    if envfile is None:
        print(f"Can't find any .env or .envrc files in {path_}", file=sys.stderr)

    print(f"Reading {envfile} for values", file=sys.stderr)

    if verbose:
        print(f"Reading {path}")
    lines = envfile.read_text().splitlines()
    for line in lines:
        # Ignore the empty lines and the commented ones
        if not line.strip():
            continue
        if line.startswith("#"):
            if verbose:
                print(f"Ignoring {line}")
            continue
        try:
            if line.startswith("export "):
                _, name, value, *_ = re.split(r"[\s\=]", line, maxsplit=1)

            else:
                name, value = re.split(r"[\s\=]", line, maxsplit=1)
            if verbose:
                print(
                    "Adding variable", name, "=", value, "from", line, file=sys.stderr
                )
            os.environ[name] = value
        except (ValueError, OSError):
            pass


@task(
    pre=[
        load_envrc,
    ],
    autoprint=True,
)
def substitute_variables(ctx: Context, file_to_substitute=None) -> str:
    """Substitutes $VALUE from environment.
    This command is similar to envsubst CLI but it will fail on missing keys.
    """
    try:
        file_to_substitute = Path(file_to_substitute)
    except (ValueError, OSError, AssertionError):
        sys.exit("No file provided, or doesn't exist. Pass -f/--file-to-substitute")
    template = string.Template(file_to_substitute.read_text())
    try:
        return template.substitute(**os.environ)
    except KeyError as err:
        name = f"${err.args[0]}"
        sys.exit(f"😭 Can't find variable {name} 😭")


def _include_exclude(
    incoming_string: str,
    include_expressions: List[str] = None,
    exclude_expressions: List[str] = None,
) -> bool:
    if exclude_expressions:
        for exclude in exclude_expressions:
            if exclude in incoming_string:
                return False
    if include_expressions:
        for include in include_expressions:
            if include in incoming_string:
                return True
        return False
    return True


@task(
    autoprint=True,
)
def env_to_json(
    ctx: Context,
    env_file=".env",
    substitute=True,
    envsubst=False,
    include: List[str] = [],
    exclude: List[str] = [],
) -> str:
    """
    Converts a .env/.envrc into JSON
    """
    path = Path(env_file)
    if path.is_dir():
        path = next(x for x in path.glob(".env*") if not x.name.endswith(".example"))
        print(f"📁 Folder passed as argument, first env file is {path}", file=sys.stderr)
    if not path.exists():
        sys.exit(f"{env_file} does not exit")

    lines = path.read_text().splitlines()
    data = {}
    for line in lines:
        content, *_comments = line.split("#")
        if not content:
            continue
        try:
            prefix_and_name, value = line.split("=", maxsplit=1)
        except ValueError:
            if ctx.config.run.echo:
                print(f"🙈 Skipping line {line}", file=sys.stderr)
        *_exports, name = prefix_and_name.split(" ")
        if not _include_exclude(name, include, exclude):
            if ctx.config.run.echo:
                print(f"Skipping {name}", file=sys.stderr)
            continue
        if substitute:
            try:
                value = Template(value).substitute(data)
            except (ValueError, KeyError):
                if ctx.config.run.echo:
                    print(f"Can't substitute variable {value}", file=sys.stderr)
        if envsubst:
            try:
                value = Template(value).substitute(os.environ)
            except (ValueError, KeyError):
                if ctx.config.run.echo:
                    print(f"Can't substitute environment {value}", file=sys.stderr)
        data[name] = value

    return json.dumps(data, indent=2)
