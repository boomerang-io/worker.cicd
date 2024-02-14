import os
from shutil import which
import socket
import sys
from pathlib import Path
import hashlib
import tempfile
from textwrap import dedent
from typing import List, Union
from itertools import chain
from invoke import Context, task

# Update this with docker buildx inspect
PLATFORMS = {"linux/arm64", "linux/amd64", "linux/amd64/v2"}


DOCKER_BUILD_REGISTRY = os.environ.get(
    "DOCKER_BUILD_REGISTRY", Path(".").absolute().name
)
DOCKER_BUILD_TAG = os.environ.get("DOCKER_BUILD_TAG", "latest").split(",")
DOCKER_BUILD_PLATFORM = [
    p for p in os.environ.get("DOCKER_BUILD_PLATFORM", "").split(",") if p
]
DOCKER_BUILD_CONTEXT = os.environ.get("DOCKER_BUILD_CONTEXT", ".")


@task(
    help={
        "dockerfile_": "Define custom Dockerfile",
        "context": "The directory to pick files from, default to current directory",
        "registry": "The registry, defaults to the folder name"
        "defaults to the current folder name unless $DOCKER_BUILD_REGISTRY is defined",
        "tag_": "A list of tags to apply to the image",
        "tag_with_git_revision": "Controls if the last commit ID should be used to "
        "tag the docker image",
        "platform_": f"Build for multiple platforms, one of {PLATFORMS}. Can be "
        "defined with $DOCKER_BUILD_PLATFORM.",
        "default_args": "Controls if COMMIT_ID, BRANCH_NAME are passed as args by default",
    }
)
def docker_build(
    ctx: Context,
    dockerfile_=None,
    context: Union[str, Path] = DOCKER_BUILD_CONTEXT,
    registry: str = DOCKER_BUILD_REGISTRY,
    tag_: List = DOCKER_BUILD_TAG,
    args_: List = [],
    default_args: bool = True,
    tag_with_git_revision=True,
    platform_=[],
):
    """Builds a Docker image tagging with the commit hash by default"""
    if tag_with_git_revision:
        tag_.insert(0, ctx.run(f"git -C {context} rev-parse HEAD").stdout.strip())
    # TODO: Figure out why the initialization is not picking this
    platform_ = platform_ or DOCKER_BUILD_PLATFORM
    tag = tag_.pop(0)
    full_tag = f"{registry}:{tag}"
    platform = "" if not platform_ else f"--platform {','.join(platform_)}"
    dockerfile = "" if not dockerfile_ else f"-f {dockerfile_}"

    # TODO: Check if a Dockerfile exists
    def _split_arg_def(arg_def: str) -> tuple[str, str]:
        try:
            name, value = arg_def.split("=", maxsplit=1)
            return name, value
        except ValueError:
            return arg_def, ""

    build_arg_dict = {name: value for name, value in map(_split_arg_def, args_)}
    if default_args:
        from .git import get_commit_hash, git_checkout_clean, git_branch_name

        build_arg_dict.setdefault("COMMIT_ID", get_commit_hash(ctx))
        build_arg_dict.setdefault("GIT_BRANCH", git_branch_name(ctx))
        build_arg_dict.setdefault("CHECKOUT_STATUS", git_checkout_clean(ctx))

    args = " ".join(
        f"--build-arg {arg}={value}" for arg, value in build_arg_dict.items()
    )
    ctx.run(
        f"docker build {platform} {dockerfile} -t {full_tag} {args} {context}", pty=True
    )
    results = [full_tag]
    for extra_tag in tag_:
        extra_full_tag = f"{registry}:{extra_tag}"
        ctx.run(f"docker tag {full_tag} {extra_full_tag}")
        results.append(extra_full_tag)

    print("\n", "✨🐳 Tags created/built:", file=sys.stderr)
    for tagged in results:
        print(tagged, file=sys.stderr)
    ctx.config.DOCKER_BUILD_TAGS = results


@task(help={"tags_": "Tags to be pushed"})
def docker_push(
    ctx: Context,
    tags_: List[str] = [],
):
    """Pushes images built by docker-build"""
    tags_to_push = chain(tags_, ctx.config.get("DOCKER_BUILD_TAGS", []))
    for tag in tags_to_push:
        ctx.run(f"docker push {tag}", pty=True)


@task()
def docker_build_debug(ctx: Context, path=".", dockerfile="Dockerfile", name=None):
    path = Path(path).absolute()
    name = name or path.name
    dockerfile = path / dockerfile
    if not dockerfile.exists():
        sys.exit(f"{dockerfile} not found")
    else:
        print(f"Building {dockerfile}", file=sys.stderr)
    ctx.run(
        f"docker build -t {name} -f {dockerfile} {path}", env={"DOCKER_BUILDKIT": "0"}
    )


@task()
def docker_use_remote(ctx: Context, host="localhost", port=2375, override=False):
    """Sets the DOCKER_HOST to a remote environment"""
    if os.environ.get("DOCKER_HOST") and not override:
        print(
            f"DOCKER_HOST already present: {os.environ['DOCKER_HOST']}", file=sys.stderr
        )
    else:
        s = socket.socket()
        s.settimeout(1)
        try:
            s.connect((host, port))
            s.close()
        except Exception:
            print(f"⚠️ Can't reach {host}:{port} ⚠️ ", file=sys.stderr)
        os.environ["DOCKER_HOST"] = f"tcp://{host}:{port}"


@task(
    autoprint=True,
)
def docker_context_estimate(ctx: Context, context_dir="."):
    """Estimate the size of the context
    (use this command to debug the size of a Context)
    """
    context_dir = Path(context_dir)
    if not context_dir.is_dir():
        sys.exit(f"{context_dir} is not a directory")
    suffix = hashlib.sha256(str(context_dir.absolute()).encode("utf-8")).hexdigest()
    tag = f"context-estimation:{suffix}"
    with tempfile.NamedTemporaryFile(
        suffix=".dockerfile",
    ) as f:
        Path(f.name).write_text(
            dedent(
                """
                    FROM alpine
                    COPY . /context
                    """
            )
        )

        with ctx.cd(context_dir):
            ctx.run(
                f"docker build -f {f.name} -t {tag} .",
                echo=ctx.config.run.echo,
                hide=not ctx.config.run.echo,
            )
        output = ctx.run(
            f"docker run --rm {tag} du -hs /context",
            echo=ctx.config.run.echo,
            hide=not ctx.config.run.echo,
        ).stdout.strip()
        ctx.run(
            f"docker image rm -f {tag}",
            echo=ctx.config.run.echo,
            hide=not ctx.config.run.echo,
        )
        return output


DOCKER_TUNNEL_HOST = os.environ.get("DOCKER_TUNNEL_HOST", "")


@task(
    help={
        "host": "The docker host, defaults to $DOCKER_TUNNEL_HOST",
        "local_docker_port": "2375, don't change unless you need it.",
        "remote_docker_port": "2375, don't change unless you need it.",
    }
)
def start_docker_tunnel(
    ctx: Context,
    host=DOCKER_TUNNEL_HOST,
    local_docker_port=2375,
    remote_docker_port=2375,
):
    """
    Start a docker tunnel with SSH to use a remote VM to accelerate
    the build times and ensure ARM builds. May require to chain right login to the
    registry.
    This command should give back the control and be idempotent.
    """
    # TODO: Move this task to taskfiles repo, connect it with docker-build-remote

    running = ctx.run(f"nc -v -z localhost {remote_docker_port}", warn=True)
    print(
        f"🔪 If you want to stop the tunnel, run pkill -i :{local_docker_port} 🔪 ",
        file=sys.stderr,
    )
    if running.ok:
        print("Tunnel already running.")
        return

    if not host:
        sys.exit("You need to pass --host me@vm or set $DOCKER_TUNNEL_HOST")
    if not which("autossh"):
        print(
            "autossh (for more long standing connections) not found, using bare ssh",
            file=sys.stderr,
        )
        ssh = ctx.run(
            f"ssh -L {local_docker_port}:localhost:{remote_docker_port} -fN {host}",
            echo=True,
            warn=True,
        )
        if not ssh.ok:
            print("Looks like it's running in the background.", file=sys.stderr)

    else:
        print("Starting tunnel in the background, use pkill -i :2375", file=sys.stderr)
        ctx.run(
            'autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" '
            f"-gL {local_docker_port}:localhost:{remote_docker_port} -fN {host}",
            echo=True,
        )
