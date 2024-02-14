# pylint: disable=unused-argument
import os
import platform
import shutil
import sys
import tarfile
from textwrap import dedent
import urllib.request
import zipfile
from copy import copy
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Dict, Iterator, List, Union
from ._utils import get_git_remotes

from invoke import Context, task, Task


def is_directory_writable(a_directory: Union[str, Path]) -> bool:
    """Evaluate if a directory can be written to

    Parameters
    ----------
    a_directory : Union[str, Path]
        The directory to check for write access

    Returns
    -------
    bool
        True if the directory is writable, False otherwise
    """ """"""
    return os.access(a_directory, os.W_OK) and Path(a_directory).is_dir()


HOME: Path = Path("~").expanduser()


def find_suitable_writable_directories_in_path() -> List[Path]:
    """Find a directory where we can download binaries using the $PATH
    environment variable. It will prefer ~/.local/bin"""

    def weight(p: Path) -> int:
        p_str = str(p)
        if p == HOME / ".local/bin":
            return 100
        if p_str.startswith(str(HOME)):
            return 0
        if "Library" in p_str:
            return -1
        return -10

    unique_path_parts = set(os.environ.get("PATH").split(":"))
    path_directories = [Path(p) for p in unique_path_parts if is_directory_writable(p)]
    path_directories = sorted(path_directories, key=weight, reverse=True)
    return path_directories


def download_extract_and_copy(
    url,
    find_file=None,
    copy_to: Union[str, Path] = "auto",
    rename_to=None,
    permission=0o744,
    overwrite=False,
    verbose=False,
) -> bool:
    """Downloads a file, decompress if necessary and copy to a directory.

    Parameters
    ----------
    url : str
        The download URL (likely a github release)
    find_file : str, optional
        The file to copy, by default None
    copy_to : Union[str, Path], optional
        Either a Path to drop the file at, or "auto", by default "auto"

    Returns
    -------
    bool
        If the operation was successful
    """
    final_file = rename_to or find_file
    if shutil.which(final_file) and not overwrite:
        print(
            f"Skipping {final_file} installation step, already exists in $PATH",
            file=sys.stdout,
        )
        return

    name = Path(url).name
    if not find_file:
        sys.exit(f"I don't know what to copy from {url}")

    if copy_to == "auto":
        try:
            copy_to = find_suitable_writable_directories_in_path()[0]
        except IndexError:
            sys.exit(
                "Couldn't find any writable directory in $PATH. "
                "Try creating $HOME/.local/bin and adding to your $PATH to fix this."
            )
        print(
            f"{rename_to or find_file} will be installed to {copy_to}", file=sys.stderr
        )

    assert isinstance(copy_to, Path)

    def move_chmod_rename(file_to_copy: Union[Path, Iterator[Path]]):
        if isinstance(file_to_copy, Path):
            if not file_to_copy.exists():
                existing = "\n".join(p.name for p in file_to_copy.parent.glob("*"))
                sys.exit(
                    f"Couldn't find {find_file} in the context extracted from {url}:\n{existing}"
                )
        else:
            try:
                file_to_copy = next(file_to_copy)
            except StopIteration:
                sys.exit(
                    "No Path received... This you provide the right fnmatch? "
                    f" find_file={find_file}"
                )
        if rename_to:
            target = copy_to / rename_to
        else:
            target = copy_to / find_file
        try:
            shutil.move(file_to_copy, target)
        except shutil.Error:  # exists
            pass
        os.chmod(target, permission)
        return target

    with TemporaryDirectory(suffix=f"{name}-download") as tmpdirname:
        base = Path(tmpdirname)
        downloaded_file = base / name
        try:
            response = urllib.request.urlopen(url)
        except urllib.error.HTTPError:
            sys.exit(f"Error downloading {url}")
        with open(downloaded_file, "wb") as fp:
            fp.write(response.read())

        if name.endswith(".zip"):
            outdir = base / "outdir"
            outdir.mkdir(exist_ok=True, parents=True)
            with zipfile.ZipFile(downloaded_file, "r") as zip_ref:
                zip_ref.extractall(outdir)
            downloaded_file_to_copy = outdir.glob(find_file)
            return move_chmod_rename(downloaded_file)

        if name.endswith(".tar.gz"):
            outdir = base / "outdir"
            outdir.mkdir(exist_ok=True, parents=True)
            with tarfile.open(downloaded_file) as tar:
                tar.extractall(outdir)
            downloaded_file_to_copy = outdir.glob(find_file)
            return move_chmod_rename(downloaded_file_to_copy)
        else:
            return move_chmod_rename(
                file_to_copy=downloaded_file,
            )


def format_string(braced_string: str, **extra: Dict[str, str]) -> str:
    """Format strings using the OS and architecture

    Parameters
    ----------
    braced_string : str
        A string containing {system} or {system_lower}

    Returns
    -------
    str
        The formatted string
    """
    machine = platform.machine()
    machine_lower = platform.machine().lower()
    system = platform.system()
    system_lower = platform.system().lower()

    # Some github releases use this
    if machine == "x86_64":
        machine_amd_or_arm = "amd64"
    elif machine == "aarch64":
        machine_amd_or_arm = "arm64"
    else:
        machine_amd_or_arm = "FIXME"

    return braced_string.format(
        machine=machine,
        machine_lower=machine_lower,
        system=system,
        system_lower=system_lower,
        machine_amd_or_arm=machine_amd_or_arm,
        **extra,
    )


@task()
def install_yq(ctx: Context, version="4.34.1", overwrite=False):
    """Download the yq binary to convert YAML to JSON and query"""
    file_to_find = format_string("yq_{system_lower}_{machine_amd_or_arm}")
    url = format_string(
        "https://github.com/mikefarah/yq/releases/download/v{version}/"
        "yq_{system_lower}_{machine_amd_or_arm}.tar.gz",
        version=version,
    )
    download_extract_and_copy(
        url, find_file=file_to_find, copy_to="auto", rename_to="yq", overwrite=overwrite
    )


@task()
def install_kind(ctx: Context, version="0.19.0", overwrite=False):
    """Downloads kind"""
    url = format_string(
        "https://github.com/kubernetes-sigs/kind/releases/download/v{version}/"
        "kind-{system_lower}-{machine_amd_or_arm}",
        version=version,
    )
    return download_extract_and_copy(
        url,
        find_file=format_string("kind_{system_lower}_{machine_amd_or_arm}"),
        rename_to="kind",
        overwrite=overwrite,
    )


@task()
def install_kubectl(ctx: Context, version="1.27.2", overwrite=False):
    """Downloads kubernetes CLI (kubectl)"""
    if version == "stable":
        with urllib.request.urlopen(
            "https://storage.googleapis.com/kubernetes-release/release/stable.txt"
        ) as request:
            version = request.read().decode("utf-8")

    url = format_string(
        "https://dl.k8s.io/release/v{version}/bin/{system_lower}/{machine_amd_or_arm}/kubectl",
        version=version,
    )
    download_extract_and_copy(url, find_file="kubectl", overwrite=overwrite)


# https://get.helm.sh/helm-v3.13.1-linux-arm64.tar.gz


@task()
def install_helm(ctx: Context, version="3.12.1", overwrite=False):
    """Downloads Helm"""
    url = format_string(
        "https://get.helm.sh/helm-v{version}-{system_lower}-{machine_amd_or_arm}.tar.gz",
        version=version,
    )

    download_extract_and_copy(
        url, find_file="**/helm", rename_to="helm", overwrite=overwrite
    )


@task(help={"overwrite": "Overwrite existing file"})
def install_ctlptl(ctx: Context, version="0.8.19", overwrite=False):
    """Download control patrol (created local development clusters with connected registries)"""
    custom_system = platform.system()
    if custom_system == "Darwin":
        custom_system = "mac"
    elif custom_system == "Linux":
        custom_system = "linux"

    custom_machine = platform.machine()
    if custom_machine in {"aarch64"}:
        custom_machine = "arm64"

    url = format_string(
        "https://github.com/tilt-dev/ctlptl/releases/download/v{version}/"
        "ctlptl.{version}.{custom_system}.{custom_machine}.tar.gz",
        version=version,
        custom_system=custom_system,
        custom_machine=custom_machine,
    )
    download_extract_and_copy(url, find_file="ctlptl", overwrite=overwrite)


@task(help={"overwrite": "Overwrite existing file"})
def install_k3d(ctx: Context, version="5.5.1", overwrite=False):
    """Download control patrol (created local development clusters with connected registries)"""
    custom_system = (
        "darwin" if platform.system() == "Darwin" else platform.system().lower()
    )
    # https://github.com/k3d-io/k3d/releases/download/v5.5.1/k3d-darwin-arm64
    binary_name = format_string(
        "k3d-{custom_system}-{machine_amd_or_arm}", custom_system=custom_system
    )
    url = format_string(
        "https://github.com/k3d-io/k3d/releases/download/v{version}/{binary_name}",
        version=version,
        custom_system=custom_system,
        binary_name=binary_name,
    )
    download_extract_and_copy(
        url, find_file="binary_name", rename_to="k3d", overwrite=overwrite
    )


@task()
def install_tilt(
    ctx: Context,
    version="0.32.4",
    overwrite=False,
):
    """Downloads tilt"""
    #
    custom_system = (
        "mac" if platform.system() == "Darwin" else platform.system().lower()
    )
    custom_machine = platform.machine()
    if custom_machine == "aarch64":
        custom_machine = "arm64"

    url = format_string(
        "https://github.com/tilt-dev/tilt/releases/download/v{version}/"
        "tilt.{version}.{custom_system}.{custom_machine}.tar.gz",
        version=version,
        custom_system=custom_system,
        custom_machine=custom_machine,
    )

    download_extract_and_copy(url, find_file="tilt", overwrite=overwrite)


@task()
def install_fzf(ctx: Context, version="0.41.1", overwrite=False):
    """Downloads fuzzy matcher"""
    # https://github.com/junegunn/fzf/releases/download/0.41.1/fzf-0.41.1-darwin_arm64.zip
    url = format_string(
        "https://github.com/junegunn/fzf/releases/download/"
        "{version}/fzf-{version}-{system_lower}_{machine_amd_or_arm}.tar.gz",
        version=version,
    )
    download_extract_and_copy(url, find_file="fzf", copy_to="auto", overwrite=overwrite)


@task()
def install_k9s(
    ctx: Context, version="0.27.4", system=None, machine=None, overwrite=False
):
    """Downloads k9s (TUI for kubernetes)"""
    url = format_string(
        "https://github.com/derailed/k9s/releases/download/v{version}/"
        "k9s_{system_lower}_{machine_amd_or_arm}.tar.gz",
        version=version,
    )
    download_extract_and_copy(url, find_file="k9s", overwrite=overwrite)


@task()
def install_oc(ctx: Context, version="4.13.0-0.okd-2023-09-30-084937", overwrite=False):
    """Install OCP CLI using OKD project"""
    platform_system = platform.system()
    custom_system = {"Linux": "linux", "Windows": "windows", "Darwin": "mac"}.get(
        platform_system,
    )

    # Support OKD Github release naming convention for ARM
    if_arm_add_arm = "" if platform.machine() not in {"arm64", "aarch64"} else "-arm64"

    url = format_string(
        "https://github.com/okd-project/okd/releases/download/{version}/"
        "openshift-client-{custom_system}{if_arm_add_arm}-{version}.tar.gz",
        # "https://mirror.openshift.com/pub/openshift-v4/{machine}/clients/ocp/{version}/",
        version=version,
        custom_system=custom_system,
        if_arm_add_arm=if_arm_add_arm,
    )
    download_extract_and_copy(url, find_file="oc", overwrite=overwrite)


@task()
def install_kustomize(ctx: Context, version="5.0.3", overwrite=False):
    """Install kustomize binary"""

    url = format_string(
        "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize"
        "/v{version}/kustomize_v{version}_{system_lower}_{machine_amd_or_arm}.tar.gz",
        version=version,
    )
    download_extract_and_copy(
        url,
        find_file="kustomize",
        overwrite=overwrite,
    )


# FIXME: Installation fails
# Install with:
#  docker compose -f _tests/compose.yaml run --rm test -- bash
# Then run
#  inv install-ibmcloud
# @task()
# def install_ibmcloud(ctx: Context, version="2.17.1", overwrite=False):
#     if platform.system() != "Linux":
#         print(
#             "This command is currently only supported in Linux AMD64/ARM64."
#             "Pull requests welcomed :)"
#         )
#     url = format_string(
#         f"https://download.clis.cloud.ibm.com/ibm-cloud-cli/{version}/binaries/"
#         "IBM_Cloud_CLI_{version}_linux_{machine_amd_or_arm}.tgz",
#         version=version,
#     )
#     download_extract_and_copy(url=url, find_file="ibmcloud", overwrite=overwrite)


# TODO: Implement https://direnv.net/install.sh
# TODO: Hook it  direnv hook > ~/.bashrc.d/03_direnv && exec $SHELL


# TODO: Implement ensurepath for zsh
@task()
def ensurepath(ctx: Context):
    """Ensures that ~/.local/bin exists and it's in the path for bash and fish.
    Still not implemented for zsh"""
    local_bin = Path("~/.local/bin").expanduser()
    if not local_bin.is_dir():
        local_bin.mkdir(parents=True, exist_ok=True)
    env_path = {Path(p).expanduser() for p in os.environ.get("PATH").split(":")}
    if local_bin in env_path:
        print(f"{local_bin} already in the $PATH 😀", file=sys.stderr)
    else:
        # Needs to add it depending on the shell
        print(
            f"Need to add {local_bin} to the $PATH, detecting shell...",
            file=sys.stderr,
            end="",
        )
        shell = os.environ.get("SHELL")
        if not shell:
            sys.exit("Can't determine shell")
        # /usr/bin/bash -> bash
        shell_name = Path(shell).name
        print(shell_name, file=sys.stderr)
        if shell_name == "bash":
            # has the user structured the shell in ~/.bashrc.d/ ?
            bashrc_d = Path("~/.bashrc.d/").expanduser()
            if bashrc_d.is_dir():
                rc_file = bashrc_d / "00_path"
                rc_file.write_text("export PATH={local_bin}:$PATH")
            else:
                # Append the line
                bashrc = Path("~/.bashrc").expanduser()
                if bashrc.exists():
                    backup = copy(bashrc)
                    backup.name += ".back"
                    shutil.copy(bashrc, str(bashrc))
                    with bashrc.open("+a") as fp:
                        fp.write(
                            dedent(
                                f"""
                                # Adding local path
                                export PATH="{local_bin}:$PATH"
                                """
                            )
                        )
        elif shell_name == "zsh":
            sys.exit("Not implemented for {shell_name} yet")
        elif shell_name == "fish":
            # Fisher...
            fish_base_config_dir = Path("~/.config/fish/")
            conf_d = fish_base_config_dir / "conf.d/"
            if not conf_d.is_dir():
                append = False
                target = conf_d / "local_path.fish"
            else:
                target = fish_base_config_dir / "config.fish"
                append = target.exists()
            print(
                f"🐟 About to {'append' if append else 'create'} {target}",
                file=sys.stderr,
            )
            mode = "w" if not append else "a"
            print(mode, file=sys.stderr)
            with target.open(mode) as fp:
                fp.write(
                    dedent(
                        """
                        # Add local path
                        fish_add_path ~/.local/bin
                        """
                    )
                )


@task()
def install_all(ctx: Context, debug=False, overwrite=False):
    """Install all tools registered."""
    install_tasks = {
        name: obj
        for name, obj in globals().items()
        if name != "install_all"
        and name.startswith("install_")
        and isinstance(obj, Task)
    }

    for name, function in install_tasks.items():
        if debug:
            print(f"Running {name}", file=sys.stderr)
        try:
            function(ctx, overwrite=overwrite)
        except SystemExit:
            print(f"Error running {name}")


@task()
def tmux_conf(
    ctx: Context,
    repo="https://github.com/gpakosz/.tmux.git",
    verbose=False,
):
    tmux_conf_dir = Path("~/.tmux").expanduser().absolute()
    remotes = get_git_remotes(ctx, tmux_conf_dir, verbose=verbose)
    if repo in remotes.values():
        print("Already setup")
