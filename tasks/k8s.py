"""
This module contains kubernetes tasks for:
- Management of a development cluster though control patrol
- Develop a Helm chart using Tilt
- Run Text Oriented Interface for Kubernetes k9s
- Install helm chart in OCP
"""
import json
import os
import re
import sys
import webbrowser
from dataclasses import dataclass
from io import StringIO
from pathlib import Path
from shutil import which
from textwrap import dedent
from typing import Any, Dict, List, Optional, Union

from invoke import Context, Result, Task, task

from ._ctlptl import KIND_DEV_CLUSTER_CTLPTL_FORMAT, K3D_DEV_CLUSTER_CTLPTL_FORMAT
from ._utils import (
    dict_to_dataclass,
    get_commit_dict,
    get_git_root_directory,
    get_git_root_path,
    picker,
)
from .setup import install_ctlptl, install_kind, install_tilt, install_k3d

KNOWN_CTLPTL_GOOD_PRODUCTS = {
    "kind",
    "k3d",
    # For now we won't try to use rancher, but the kubernetes
    # clusters created by ctlptl (that have registries and all)
    # "rancher-desktop"
}

TASKS_DEV_CLUSTER_PROVIDER = os.environ.get("TASKS_DEV_CLUSTER_PROVIDER", "kind")
TASKS_POD_DEBUG_IMAGE = os.environ.get("TASKFILES_POD_DEBUG_IMAGE", "python:3.10")


TILT_PORT = os.environ.get("TILT_PORT", 10370)


@dataclass
class ClusterItemStatusRegistry:
    host: Optional[str] = None
    hostFromClusterNetwork: Optional[str] = None
    help: Optional[str] = None


@dataclass
class ClusterListItemStatus:
    creationTimestamp: str
    localRegistryHosting: Optional[ClusterItemStatusRegistry] = None
    kubernetesVersion: Optional[str] = None

    def __post_init__(self):
        if self.localRegistryHosting:
            self.localRegistryHosting = dict_to_dataclass(
                self.localRegistryHosting, ClusterItemStatusRegistry
            )


@dataclass
class ClusterListItem:
    """The items data from ctlplt get clusters -o json"""

    kind: str
    apiVersion: str
    name: str
    product: str
    status: ClusterListItemStatus
    registry: Optional[str] = None
    # This is to support the worker node customization
    kindV1Alpha4Cluster: Optional[Any] = None

    def __post_init__(self):
        self.status = dict_to_dataclass(self.status, ClusterListItemStatus)


@task(autoprint=True)
def find_local_kube_context(
    ctx: Context, debug=False, with_registry=True
) -> Optional[str]:
    """Find a local kubernetes contexts that have a push-able registry
    associated with them
    These clusters are created by ctlptl (Control Patrol).
    The cluster with the current directory folder name should be prioritized
    """
    if not which("ctlptl"):
        sys.exit("ctlptl not found, please install it first")

    contexts: Dict[str, Any] = json.loads(
        ctx.run("ctlptl get clusters -o json", hide=not debug).stdout
    )
    clusters = [ClusterListItem(**item) for item in contexts["items"]]

    def has_a_registry_according_to_ctlptl(cluster: ClusterListItem) -> bool:
        return cluster.status.localRegistryHosting is not None

    def is_a_good_dev_cluster(cluster: ClusterListItem) -> bool:
        good_product = cluster.product in KNOWN_CTLPTL_GOOD_PRODUCTS
        if debug:
            print(
                f"Checking if {cluster.name} ({cluster.product}) is dev friendly "
                f"{'✅' if good_product else '⛔️'}",
                file=sys.stderr,
            )
        return good_product

    candidates = [cluster for cluster in clusters if is_a_good_dev_cluster(cluster)]

    working_directory_name = Path(".").absolute().name

    def sorter(cluster: ClusterListItem):
        """Prefer registries that have registries"""
        if working_directory_name in cluster.name:
            return -2
        if has_a_registry_according_to_ctlptl(cluster=cluster):
            return 0
        return 1

    candidates.sort(key=sorter)
    if debug:
        print("Candidates: ", [c.name for c in candidates], sep=" ")
    if not candidates:
        print("No development cluster found")
    else:
        return candidates[0].name


@task()
def find_dot_kubeconfig(
    ctx: Context,
    query="",
):
    """
    Sets the KUBECONFIG variable if it finds a file named .kubeconfig

    If using starship for the prompt a good a custom extension to visualize the current
    context can be this:



    """
    kubeconfigs = list(Path(".").glob(".kubeconfig.*")) + [
        Path("~/.kube/config").expanduser()
    ]

    selected = picker(
        ctx, options=kubeconfigs, prompt="Which kubeconfig file?", query=query
    )
    if selected:
        current_value = os.environ.get("KUBECONFIG")
        if not current_value:
            os.environ["KUBECONFIG"] = str(selected)
        elif current_value != selected:
            os.environ["KUBECONFIG"] = str(selected)
        else:
            print("No change necessary:")


@task(aliases=["helm_install"], help={"app_name": "Customize app name"})
def helm_upgrade(
    ctx: Context,
    app_name="helm-app",
    chart=None,
    kube_context=None,
    atomic=True,
    timeout="5m",
):
    if not which("helm"):
        sys.exit("Please install helm")
    if not kube_context:
        kube_context = find_local_kube_context(ctx)
        if not kube_context:
            sys.exit("Couldn't find any local kubernetes cluster")
        else:
            print(f"🪄  Using local context {kube_context}", file=sys.stderr)
    chart = chart or next(find_charts(ctx, get_git_root_path()))
    root = get_git_root_directory()
    with ctx.cd(root):
        ctx.run(
            "helm upgrade "
            f"{'--atomic' if atomic else ' '} "
            "--wait --debug --install "
            f"--timeout {timeout} "
            f"--kube-context {kube_context} {app_name} {chart}",
            echo=True,
            pty=True,
        )


def find_chart_paths(
    ctx: Context, where: Union[str, Path], only_in_git=False
) -> List[Path]:
    """Finds charts (folders containing a Chart.yaml) in a directory"""
    found = []
    where = Path(where)
    if only_in_git:
        found = [
            Path(p).parent
            for p in ctx.run(
                f"git -C {where} ls-files -- **/Chart.yaml", hide=True
            ).stdout.splitlines()
        ]
    else:
        for chart_file in where.glob("**/Chart.yaml"):
            chart_folder = chart_file.parent
            found.append(chart_folder)
    return found


@task()
def find_charts(ctx: Context, where: Union[str, Path], only_in_git=False) -> List[Path]:
    """Find chart files on a path"""
    for chart in find_chart_paths(ctx, where=where, only_in_git=only_in_git):
        print(chart)


@task(
    help={
        "chart_path_": "Path to the chart (folder containing Chart.yml)"
        "if not specified it will update all the charts"
    }
)
def helm_dep_build(ctx: Context, chart_path_=None, dep_update=False):
    if chart_path_:
        chart_path = Path(chart_path_)
        if not chart_path.exists():
            sys.exit(f"{chart_path} does not exist")
        chart_dirs = [chart_path]
    else:
        chart_dirs = list(find_charts(ctx, get_git_root_path()))
    if chart_dirs and dep_update:
        ctx.run("helm dependency update ", echo=True)

    for chart_location in chart_dirs:
        print()
        with ctx.cd(chart_location):
            ctx.run("helm dependency build", echo=True)


def convert_list_to_helm_set_arg(a_list: List[str]) -> str:
    if not a_list:
        return ""
    return " ".join(f"--set {v}" for v in a_list)


@task(
    help={
        "app_name": "The name used in the deployment, will prefix (almost) all resources",
        "chart": "Path to the chart, autodiscover",
        "values": "Path to the value files to use",
        "set_": "Extra values to set, can be used multiple time",
        "helm_debug": "Pass the debug flag to helm",
        "open_in_editor": "Open the result in an editor ($EDITOR) instead of "
        "printing to standard output",
        "verbose": "Show the commands being executed",
    }
)
def helm_template(
    ctx: Context,
    app_name="helm-app",
    chart=None,
    values=None,
    set_=[],
    verbose=False,
    helm_debug=False,
    open_in_editor=False,
    value_picker=False,
):
    """Generates the YAML from a Helm chart"""
    root = get_git_root_path()
    if not chart:
        charts = find_chart_paths(ctx, where=root, only_in_git=True)
        if len(charts) == 0:
            sys.exit(f"No chart found in {root}")
        elif len(charts) == 1:
            chart = charts[0]
        else:
            chart = picker(ctx, options=charts, prompt="Select the chart to render")
            if not chart:
                sys.exit("Cancelled by the user.")

    set_overrides = convert_list_to_helm_set_arg(set_)
    EMPTY_PLACEHOLDER = "(empty) default"
    with ctx.cd(root):
        if value_picker:
            files = [str(p) for p in Path("./deploy/values/").glob("*.y*ml")] + [
                EMPTY_PLACEHOLDER
            ]
            values = picker(
                ctx,
                options=files,
                prompt="Select the file to use",
                empty=EMPTY_PLACEHOLDER,
            )

        values = "" if not values else f"--values {values}"
        result: Result = ctx.run(
            f"helm template {app_name} {chart} {values} {set_overrides} "
            f"{'--debug' if helm_debug else ''}",
            hide="out",
            echo=verbose,
        )
        if not result.ok:
            sys.exit(f"Error rendering template: {result.stderr}")

        if not open_in_editor:
            print(result.stdout)
        else:
            output_file = (
                Path(os.environ.get("TEMPDIR", "/tmp"))
                / f"rendered_chart_{app_name}.yaml"
            )
            output_file.write_text(result.stdout)
            print("** You can regain the terminal with Ctrl-C now **")
            ctx.run(
                f"$EDITOR {output_file}",
                env={"EDITOR": os.environ.get("EDITOR", "code")},
            )


# FIXME: Move to yq for YAML
@task()
def helm_show_dependency_values(
    ctx: Context,
    dependency=None,
    open_in_editor=False,
):
    try:
        import yaml
    except ImportError:
        sys.exit(
            dedent(
                f"""
                🔔 This task is missing a required package, please re-run it under poetry 🔔

                poetry run inv {' '.join(sys.argv[1:])}
                """
            )
        )

    chart_yaml = find_charts(ctx, get_git_root_path()) / "Chart.yaml"
    chart_data = yaml.safe_load(chart_yaml.read_text())
    deps = chart_data["dependencies"]
    dependency_map = {d["name"]: d for d in deps}
    if dependency:
        dep = dependency_map.get(dependency)
        if not dep:
            sys.exit(
                dedent(
                    f"""
                    Can't find a dependency called {dependency}

                    Possible values are: {' '.join(dependency_map)}
                   """
                )
            )
    else:
        dep = deps[0]
        print(
            f"No dependency provided, choosing the first {dep['name']}", file=sys.stderr
        )
    #
    local_repos = json.loads(ctx.run("helm repo list --output json", hide=True).stdout)
    repo_url_to_name = {lr["url"]: lr["name"] for lr in local_repos}

    name_to_use = repo_url_to_name.get(dep["repository"])
    if not name_to_use:
        sys.exit("Please add to your helm repositories")

    result: Result = ctx.run(
        f"helm show values {name_to_use}/{dep['name']}", echo=False, hide="out"
    )

    if not result.ok:
        sys.exit(f"Error getting values: {result.stderr}")
    if not open_in_editor:
        print(result.stdout)
    else:
        output_file = (
            Path(os.environ.get("TEMPDIR", "/tmp")) / f"values_{dependency}.yaml"
        )
        output_file.write_text(result.stdout)
        print("** You can regain the terminal with Ctrl-C now **")
        ctx.run(
            f"$EDITOR {output_file}",
            env={"EDITOR": os.environ.get("EDITOR", "code")},
        )


@task()
def psql_into_pod(
    ctx: Context,
    app_name=None,
    kube_context=None,
    verbose=False,
    command="PGPASSWORD=$POSTGRES_PASSWORD psql -U 'postgres' -h 127.0.0.1 -p 5432",
    interactive_=True,
):
    LABEL_MATCHING = {
        "app.kubernetes.io/component": "primary",
        "app.kubernetes.io/name": "postgresql",
        "app.kubernetes.io/instance": app_name,
    }
    if not kube_context:
        kube_context = find_local_kube_context(ctx)
    label_selector = ",".join(
        f"{label}={value}" for label, value in LABEL_MATCHING.items()
    )
    pod_name = ctx.run(
        f"kubectl --context {kube_context} get pods "
        f"--selector {label_selector} -o name",
        echo=verbose,
    ).stdout.strip()
    if not pod_name:
        sys.exit(f"Couldn't find anything by {label_selector}")

    interactive = "-ti" if interactive_ else ""

    ctx.run(
        f"kubectl --context {kube_context} exec {interactive} {pod_name} -- "
        f'bash -c "{command}"',
        echo=True,
        pty=interactive_,
    )


@task(
    help={
        "command": "Overrides the default resource to load when the application "
        "launches",
        "namespace": "Override namespace",
    }
)
def k9s(ctx: Context, command=None, namespace=None, kube_context=None):
    """Starts k9s"""
    if not which("k9s"):
        # TODO: Add k9s downloads to tasks.setup module
        sys.exit("Please install k9s")
    kube_context = kube_context or find_local_kube_context(ctx)
    command = (
        f"k9s --context {kube_context} "
        f"{'' if not command else f'--command {command}'} "
        f"{'' if not namespace else f'--namespace {namespace}'} "
    )
    print(command, file=sys.stderr)
    os.system(command)


@dataclass
class DockerContext:
    Current: bool
    Description: str
    DockerEndpoint: str
    Name: str
    Error: str
    KubernetesEndpoint: Optional[str] = ""


@task(autoprint=True)
def get_current_docker_host(ctx: Context, verbose=False, raw=False):
    """
    Get the current value for the DOCKER_HOST environment variable.
    """
    contexts = map(
        json.loads,
        ctx.run(
            "docker context ls --format json", hide=not verbose
        ).stdout.splitlines(),
    )
    docker_contexts: List[DockerContext] = [
        dict_to_dataclass(data, DockerContext) for data in contexts
    ]
    try:
        current: DockerContext = next(dctx for dctx in docker_contexts if dctx.Current)
    except StopAsyncIteration:
        return None
    if not raw:
        if "fish" in os.environ.get("SHELL"):
            export_line = "set -g -x DOCKER_HOST {host}"
        else:
            # bash, zsh
            export_line = "export DOCKER_HOST={host}"
        print("# Source this with eval $(inv get-current-docker-host)", file=sys.stderr)
        print("# Get the raw value with --raw", file=sys.stderr)
        return export_line.format(host=current.DockerEndpoint)
    else:
        return current.DockerEndpoint


@task(autoprint=True)
def docker_env(ctx: Context, verbose=False) -> Dict[str, str]:
    """Creates a dictionary to pass to ctx.run making sure the DOCKER_HOST is passed
    for Rancher Desktop"""
    docker_version = json.loads(
        ctx.run("docker version -f '{{ json . }}'", echo=False, hide=True).stdout,
    )
    name = docker_version.get("Server", {}).get("Platform", {}).get("Name", "")

    if "docker desktop" in name.lower():
        return {}
    else:
        return {
            "DOCKER_HOST": get_current_docker_host(
                ctx,
                verbose=verbose,
                raw=True,
            )
        }


@task(autoprint=True)
def get_default_kube_context(ctx: Context) -> Optional[str]:
    """Get the default context in kubernetes."""
    try:
        default_context = json.loads(
            ctx.run("kubectl config view --minify --output json", hide=True).stdout,
        )
    except Exception:
        return None
    try:
        name = default_context["clusters"][0]["name"]
    except Exception:
        print("Error getting the default context", file=sys.stderr)
        return None
    return name


def get_dev_cluster_name_suffix(ctx: Context, max_name_length=31):
    """Gets the name suffix of the default cluster, it's called suffix because
    ctlptl will prefix with the product type, like kind-, k3d-, minikube-, etc."""
    name = Path(get_git_root_directory()).name
    name = re.sub(r"[_\.]", "-", name)
    if len(name) > max_name_length:
        name = name[:max_name_length]
    return name


@task(autoprint=True, aliases=["get-dev-cluster-name"])
def get_dev_cluster_context(ctx: Context, product=None):
    """Gets the name/context of the default cluster
    The name == context comes from the ctlptl behavior that
    creates {product}-{name}.
    """
    product = product or TASKS_DEV_CLUSTER_PROVIDER
    suffix = get_dev_cluster_name_suffix(ctx)
    full_name = f"{product}-{suffix}"
    # Can only be 32 characters
    return full_name[:32]


@task(
    pre=[Task(install_ctlptl)],
    help={
        "type_": "Type of development cluster, k3d and kind clusters are supported",
        "name": "Name of the cluster",
        "debug": "Show debugging information of the creation process",
    },
    autoprint=True,
)
def create_local_dev_cluster(ctx: Context, type_=None, name=None, debug=False):
    """Creates a local development cluster"""
    if not name:
        name = get_dev_cluster_name_suffix(ctx)

    if not type_:
        print("Checking DEV_CLUSTER_PROVIDER for cluster provider", file=sys.stderr)
        type_ = os.environ.get("DEV_CLUSTER_PROVIDER", "kind")

    if type_ == "kind":
        install_kind(ctx)
        config = KIND_DEV_CLUSTER_CTLPTL_FORMAT.format(name=name)
    elif type_ == "k3d":
        install_k3d(ctx)

        if not name.startswith("k3d-"):
            name = f"k3d-{name}"
        config = K3D_DEV_CLUSTER_CTLPTL_FORMAT.format(name=name)
    else:
        url = "https://github.com/tilt-dev/ctlptl#examples"
        sys.exit(f"Support for {type_} not implemented yet. Check out {url}")

    if debug:
        print(config, file=sys.stderr)
    ctx.run(
        # f"ctlptl create cluster {type_} --name {type_}-{name} --registry {name}",
        "ctlptl apply -f -",
        in_stream=StringIO(config),
        echo=True,
        env=docker_env(ctx, verbose=debug),
    )
    context = ctx.run(
        "kubectl config get-contexts -o name " f"| grep {type_} | grep {name}",
        hide=True,
    ).stdout.strip()

    return context


@dataclass
class Cluster:
    kind: str
    apiVersion: str
    name: str
    product: str
    status: str


@task(autoprint=True)
def get_clusters(ctx: Context, debug=False):
    data = json.loads(ctx.run("ctlptl get clusters -o json", hide=not debug).stdout)
    # cluster_configs = map(lambda d: dict_to_dataclass(d, Cluster), data)
    cluster_configs = [dict_to_dataclass(d, Cluster) for d in data["items"]]
    return list(cluster_configs)


@task(pre=[Task(install_ctlptl)])
def delete_local_dev_cluster(ctx: Context, name=None, product=None, debug=False):
    """Deletes a local development cluster"""
    if name and product:
        sys.exit("You can't use --name or --product at the same time.")
    if not name:
        name = get_dev_cluster_context(ctx, product=product)
    deleted = ctx.run(f"ctlptl delete cluster {name}", warn=True)
    if not deleted.ok:
        print("Can't delete the cluster, try passing a different --product")


@task(
    pre=[Task(install_tilt)],
    help={
        "namespace": "The namespace to use",
        "stop_others": "Kill other processes listening to the tilt port",
        "to_run": "List of services to run. "
        "(see https://docs.tilt.dev/tiltfile_config.html#specify-services-to-edit)",
        "to_edit": "List of services to edit. "
        "(see https://docs.tilt.dev/tiltfile_config.html#specify-services-to-edit)",
        "dev_kube_context": "Kubernetes context to use, this should be auto-detected "
        "in most cases.",
        "auto_create_cluster": "Control if a local development cluster should be "
        "created if not found",
        "port": f"Define the port, will use TILT_PORT by default ({TILT_PORT})",
    },
)
def tilt_up(
    ctx: Context,
    namespace="tilt-dev",
    stop_others=True,
    port=TILT_PORT,
    dev_kube_context=None,
    to_edit=[],
    to_run=[],
    debug=False,
    auto_create_cluster=True,
):
    """Runs tilt up with a local kubernetes cluster"""
    if stop_others:
        print("Stopping other instances...", end="")
        kill_result = ctx.run(
            "lsof -t -i :$PORT_NUMBER && kill $(lsof -t -i :$PORT_NUMBER)",
            env={"PORT_NUMBER": str(port)},
            warn=True,
            echo=debug,
        )
        if not kill_result.ok:
            print("No other instances found.")
    dev_kube_context = find_local_kube_context(ctx) or find_local_kube_context(
        ctx, with_registry=False
    )

    if not dev_kube_context:
        if not auto_create_cluster:
            sys.exit(
                "⛔️⛔️ Couldn't find a local development cluster with registry. ⛔️⛔️\n\n"
                "Run create-local-dev-cluster first."
            )
        else:
            dev_kube_context = create_local_dev_cluster(ctx)

    current_kube_context = get_default_kube_context(ctx)
    if current_kube_context != dev_kube_context:
        print(f"🔔🔔 Setting the kubernetes context to {dev_kube_context} 🔔🔔")
        print(
            f" If you don't want to use  {dev_kube_context}, Ctrl-C and run "
            "inv create-local-dev-cluster ⚠️⚠️"
        )
        #
        ctx.run(
            f"kubectl config set-context {dev_kube_context} --namespace {namespace}"
        )
        ctx.run(f"kubectl config use-context {dev_kube_context}")
    print(f"✨ Creating namespace (if doesn't exist) {namespace}")
    ctx.run(
        f"kubectl --context {dev_kube_context} create ns {namespace}",
        hide=True,
        warn=True,
    )
    print("🚀  Running tilt")
    if to_run:
        to_run_arg = " ".join(f"--to-run {svc}" for svc in to_run)
    else:
        to_run_arg = ""

    if to_edit:
        to_edit_arg = " ".join(f"--to-edit {svc}" for svc in to_edit)
    else:
        to_edit_arg = ""

    # TODO: Generalize
    prefix = ""
    if Path(".envrc").exists():
        if not which("direnv"):
            print("direnv not found, but .envrc exists ‼️ ", file=sys.stderr)
        else:
            prefix = "direnv exec . "

    with ctx.cd(get_git_root_directory()):
        ctx.run(
            f"{prefix} tilt up --context {dev_kube_context} --port {TILT_PORT} "
            f"--namespace {namespace} -- {to_edit_arg} {to_run_arg}",
            echo=True,
            env=docker_env(ctx, verbose=False),
        )


@task(
    help={
        "cluster": "Delete the cluster after tilt down",
    }
)
def tilt_down(
    ctx: Context, cluster=False, kube_context=None, namespace=False, debug=False
):
    """Stops tilt up"""
    kube_context = kube_context or get_dev_cluster_context(ctx)
    ctx.run(
        f"tilt down --context {kube_context}",
        echo=True,
        env=docker_env(ctx, verbose=False),
        warn=True,
    )
    if namespace:
        print("Deleting namespace tilt-dev", file=sys.stderr)
        context = find_local_kube_context(ctx, debug=debug)
        if context:
            print("Trying to delete namespace tilt-dev")
            ctx.run(f"kubectl delete ns tilt-dev --context {context}")
        else:
            print("Can't find a development cluster/context")
    if cluster:
        delete_local_dev_cluster(
            ctx,
        )


@task(
    help={
        "port": f"Define the port, will use TILT_PORT by default ({TILT_PORT})",
    }
)
def tilt_open(ctx: Context, port=TILT_PORT):
    """Opens the system default browser on tilt UI"""
    webbrowser.open(f"http://localhost:{port}")


@task(help={"query": "Pre-filter the results option with fuzzy search"})
def oc_project_switcher(ctx: Context, query=None):
    """An interactive project switcher based in fzf"""
    from ._utils import picker

    if not which("fzf"):
        sys.exit("fzf command not found, install it first.")
    prompt = "Which oc project should we select"
    custom_config = os.environ.get("KUBECONFIG")
    if custom_config:
        prompt = f"{prompt} ({custom_config})"
    prompt = f"{prompt}? "

    project = picker(ctx, options=ctx.run("oc projects -q"), prompt=prompt, query=query)
    if project:
        ctx.run(f"oc project {project}")
    else:
        sys.exit("No project was selected 😭")
    # os.system("oc project $(oc projects -q | fzf )")


OCP_SERVER = os.environ.get("OCP_SERVER")
OCP_SA_TOKEN = os.environ.get("OCP_SA_TOKEN")

_token_docs = dedent(
    """
    You can prevent it to be leaked in your shell"
    history by setting it using $OCP_SA_TOKEN (.envrc with direnv hook
    can autoload it per project)
    """
)


@task(
    help={
        "token": _token_docs,
        "token_from": "Define the environment variable that has the token. "
        "This is useful for Service Account secert tokens that only map to one namepasce",
        "server": "OCP server endpoint, will look like https://xxxx:6443",
        "insecure_skip_tls_verify": "Skip TLS verification.",
    }
)
def oc_login(
    ctx: Context,
    token=OCP_SA_TOKEN,
    token_from=None,
    server=OCP_SERVER,
    insecure_skip_tls_verify=False,
):
    """
    Log in to OCP cluster using OpenShift client command line utility.
    """
    if not which("oc"):
        from setup import install_oc

        install_oc(ctx)
    if not server:
        sys.exit("Please define a server, preferably in $OCP_SERVER")
    if token_from:
        token = os.environ.get(token_from, "")
    if not token:
        sys.exit("Please provide a token. ")

    ctx.run(
        f"oc login --token=$TOKEN {server} "
        f"{'--insecure-skip-tls-verify=false' if insecure_skip_tls_verify else ''}",
        env={"TOKEN": token},
    )


@task(
    help={
        # "namespace": "This is the project in OCP",
        "name": "Name of the app",
        "chart": "Path to the chart",
        "values": "Values file",
        "kube_context": "The kubernetes context, the name of the OCP project "
        "is the first part of the context",
        "timeout": "Tell helm how long to wait for desired state to be reached,"
        " rolling back afterwards.",
        "tag": "The docker image tag",
    }
)
def helm_ocp_deploy(
    ctx: Context,
    name=None,
    chart=None,
    values=None,
    timeout="5m",
    kube_context=None,
    set_=[],
    tag=None,
    auto_tag=False,
    dry_run=False,
):
    """
    Deploy the helm chart into a OCP cluster. We use the kubernetes context
    that the oc command line utility generates, with the following structure:
    {project-namespace}/{server}/{user}
    """
    # yq binary is used to convert YAML to JSON, this is because we don't want
    # to add python dependencies to invoke as they complicate the setup process.
    if not which("yq"):
        from .setup import install_yq

        install_yq(
            ctx,
        )
    kubectl_config_json_result = ctx.run(
        "kubectl config view | yq -o=json", hide="out", warn=True
    )
    if not kubectl_config_json_result.ok:
        sys.exit(kubectl_config_json_result)
    try:
        config = json.loads(kubectl_config_json_result.stdout)
    except json.JSONDecodeError:
        sys.exit(f"{kubectl_config_json_result}")

    kube_contexts = config["contexts"]
    name_to_context_dict = {context["name"]: context for context in kube_contexts}
    kube_context = kube_context or picker(ctx, name_to_context_dict)
    # TODO: Understand why there's discrepancy between kubectl config view
    # and the above dict 👇
    # context_dict = name_to_context_dict[kube_context]

    try:
        namespace, _server, _user = kube_context.split("/")
    except ValueError:
        sys.exit(
            "Couldn't understand find the structure project/server/user. Run oc login "
        )

    if auto_tag and tag:
        sys.exit("Can't use auto_tag and tag at the same time")
    if auto_tag:
        commit_hash_to_msg_time = get_commit_dict(ctx, branch="main")
        tag, message_and_date = next(iter(commit_hash_to_msg_time.items()))
        print(
            f"Selecting {tag}, authored on {message_and_date['date']} under the subject: "
            f"{message_and_date['message']}",
            file=sys.stderr,
        )
    if tag:
        set_.append(f"backend.image.tag={tag}")
    set_arg = convert_list_to_helm_set_arg(set_)

    with ctx.cd(get_git_root_directory()):
        ctx.run(
            f"helm upgrade --install --atomic --debug {name} {chart} "
            f"--values {values} {set_arg} --timeout={timeout} "
            f"--kube-context {kube_context} --namespace {namespace} "
            f"{'--dry-run' if dry_run else ''}",
            echo=True,
            pty=True,
        )


@task(autoprint=True)
def kube_context_picker(ctx: Context, query=None) -> str:
    """Shows a kubernets context picker dialog using fzf"""
    if not which("fzf"):
        sys.exit("Please install fzf")
    selected_context = picker(
        ctx,
        ctx.run("kubectl config get-contexts -o name", hide=True),
        query=query,
        prompt="Select a kubernetes context> ",
    )
    if selected_context:
        ctx.config.kube_context = selected_context
    return selected_context


@task(autoprint=True)
def kube_pod_picker(ctx: Context, kube_context=None, query=None):
    """Shows a pod picker"""
    if not which("fzf"):
        sys.exit("Please install fzf")

    kube_context = kube_context or ctx.config.get("kube_context")
    args = f"--context {kube_context}" if kube_context else ""
    pod = picker(
        ctx, ctx.run(f"kubectl get pods {args} -o name", hide=True), query=query
    )
    if pod:
        ctx.config.pod = pod
    return pod


@task(
    help={
        "pod": "Name of the pod, will use fzf picker if not passed",
        "image": "Container image to use for debug, defaults to "
        "$TASKFILES_POD_DEBUG_IMAGE or python:3.10",
        "command": "Command to run in the container, defaults to bash",
    }
)
def pod_debug(
    ctx: Context,
    dev_kube_context=True,
    kube_context=None,
    namespace=None,
    labels_=[],
    pod=None,
    image=TASKS_POD_DEBUG_IMAGE,
    command="bash",
):
    """Runs a container in a pod for debugging in interactive mode"""
    if dev_kube_context:
        if kube_context:
            print("--kube-context passed, not doing any discovery")
        else:
            kube_context = get_dev_cluster_context(ctx)

    context_arg = "" if not kube_context else f"--context {kube_context}"

    ns_arg = "" if not namespace else f"--namespace {namespace}"

    if labels_:
        label_arg = " ".join(f"-l {lbl}" for lbl in labels_)
        pod = ctx.run(
            f"kubectl {context_arg} {ns_arg} get pods {label_arg} -o name"
        ).stdout.splitlines()[0]

        image = ctx.run(
            f"kubectl {context_arg} {ns_arg} get pods {label_arg} "
            "-o='jsonpath={.items[0].spec.containers[0].image}'"
        ).stdout.strip()
    pod = pod or kube_pod_picker(ctx)
    _, pod = pod.split("/")
    ctx.run(
        f"kubectl {context_arg} {ns_arg} debug -ti --image={image} {pod} -- {command}",
        echo=True,
        pty=True,
    )


@task(
    help={
        "kube_context": "Provide a kubernetes context, it will prompt if not provided",
        "pod": "The pod to be used, it will prompt if not provided",
        "command": "The command to execute",
    }
)
def kube_exec(ctx: Context, command="bash", kube_context=None, pod=None):
    """Shells into a pod using kubectl exec"""
    kube_context = (
        kube_context or ctx.config.get("kube_context") or kube_context_picker(ctx)
    )
    if not kube_context:
        sys.exit("No context selected")
    pod = (
        pod or ctx.config.get("pod") or kube_pod_picker(ctx, kube_context=kube_context)
    )
    if not pod:
        sys.exit("No pod selected")
    ctx.run(
        f"kubectl exec -ti --context {kube_context} {pod} -- {command}",
        pty=True,
        echo=True,
    )


@task(
    help={
        "grep_": "Filter kubernetes by string matching. Can be used multiple times",
        "output": "Specify kubectl output",
        "resource": "The type of kubernetes resource to get",
    }
)
def find_resources(ctx: Context, grep_=[], output=None, resource="route"):
    """Find resources across namespaces(/oc projects) running grep.
    By default looks four route

    Example use:
        inv find-resources --grep dev
        inv ocp-routes --grep dev -o json
    """
    grep = "|".join(f"grep {term}" for term in grep_)
    if not grep:
        grep = "tee"
    output = "" if not output else f"-o {output}"
    ctx.run(
        f"kubectl config get-contexts -o name  | {grep} | "
        rf'xargs printf "kubectl --context %s get {resource} {output}\n" | $SHELL',
        echo=True,
    )


@task()
def find_helm_releases(ctx: Context, grep_=[], output="table"):
    grep = "|".join(f"grep {term}" for term in grep_)
    if not grep:
        grep = "tee"
    contexts = ctx.run(
        f"kubectl config get-contexts -o name  | {grep}",
        hide=True,
    ).stdout.splitlines()
    for context in contexts:
        helm_ls_result = ctx.run(
            f"helm ls --kube-context {context} -o {output}", warn=True, hide="out"
        )

        if helm_ls_result.ok:
            print(context)
            print(helm_ls_result.stdout)


@task(
    pre=[Task(install_tilt)],
    help={},
)
def tilt_get_port_forwards(ctx: Context, grep=[]):
    pipe_out = (
        "" if not grep else "| {}".format("| ".join(f"grep {pat}" for pat in grep))
    )
    ctx.run(f"tilt get pf  {pipe_out}", echo=True)


@task()
def helm_package(ctx: Context, debug=False):
    for chart_path in find_charts(ctx, get_git_root_path()):
        with ctx.cd(chart_path):
            ctx.run("helm package .", echo=debug)


@task()
def kubeconfig_picker(ctx: Context, exclude_=[]):
    """
    Allows to set the KUBECONFIG variable for a task chain, setting the
    variable locally. To set a variable locally you can use
    export KUBECONFIG=$PWD/.kubeconfig.tilt
    or in fish
    set -x KUBECONFIG $PWD/.kubeconfig.tilt

    If there's a common default, you can set in in your .envrc
    """
    path = Path(".")
    if not exclude_:
        exclude_ = ["tilt", "k3s", "local"]

    def is_good_kubeconfig(kc: Path) -> bool:
        for exclude in exclude_:
            if exclude in str(kc):
                return False
        return True

    kubeconfigs = list(filter(is_good_kubeconfig, path.glob(".kubeconfig*")))
    if kubeconfigs:
        kubeconfig = kubeconfigs[0].absolute()
        current_kubeconfig = os.environ.get("KUBECONFIG")
        if current_kubeconfig:
            if Path(current_kubeconfig).absolute() != kubeconfig:
                print(
                    f"Changing from old kubeconfig {current_kubeconfig} to ...",
                    file=sys.stderr,
                )
        print(f"Using KUBECONFIG={kubeconfig}", file=sys.stderr)
        os.environ["KUBECONFIG"] = str(kubeconfig)
    else:
        if ctx.config.run.echo:
            print(f"No kubeconfig found in {path.absolute()}", file=sys.stderr)


# @task()
# def helm_values_delta(
#     ctx: Context,
# ):
#     """
#     Calculates the delta between two values files.
#     Use when you need to provide added values to helm upgrade --reuse-values
#     and templates require new config in values
#     """
#     values_path = "./helm_chart/values.yaml"
#     with tempfile.NamedTemporaryFile(prefix="values", suffix=".yaml") as values:
#         values_yaml_path = Path(values.name)
#         values_yaml_path.write_text(
#             ctx.run(f"git show HEAD:{values_path}", hide=not ctx.config.run.echo).stdout
#         )
#         ctx.run(f"cat {values_yaml_path}")

DOCKER_REGISTRY_USERNAME = os.getenv("DOCKER_REGISTRY_USERNAME")
DOCKER_REGISTRY_DOMAIN = os.getenv("DOCKER_REGISTRY_DOMAIN")
DOCKER_REGISTRY_PASSWORD = os.getenv("DOCKER_REGISTRY_PASSWORD")


@task(
    help={
        "domain": "docker.io or cri.io, etc.",
        "username": "Username to login as, defaults to $DOCKER_REGISTRY_USERNAME",
        "password_stdin": "Read password from stdin instead of $DOCKER_REGISTRY_PASSWORD",
    }
)
def container_registry_login(
    ctx: Context,
    username: str = DOCKER_REGISTRY_USERNAME,
    domain: str = DOCKER_REGISTRY_DOMAIN,
    password_stdin=False,
):
    if DOCKER_REGISTRY_PASSWORD:
        ctx.run(
            f"echo $DOCKER_REGISTRY_PASSWORD | docker login -u {username} --password-stdin {domain}"
        )
    elif password_stdin:
        print("Reading password from stdin...", file=sys.stderr)
        ctx.run(f"docker login -u {username} --password-stdin {domain}", pty=True)
    else:
        sys.exit(
            "You need either to pass --password-stdin or set $DOCKER_REGISTRY_PASSWORD"
        )


# TODO: Show project to the user by getting the tokens' namespace
@task()
def oc_login_token_to_kubeconfig(
    ctx: Context,
    verbose=False,
    kubeconfig=None,
    insecure_skip_tls_verify=True,
    show_project=False,
):
    """
    Creates a kubeconfig file with a service account token for authentication.
    It can only log people in for one namespace.
    """
    # kubeconfig = os.environ.get("KUBECONFIG")
    if not kubeconfig:
        kubeconfig = "auto"
    server = ctx.run(
        "oc config view --minify | yq '.clusters[0].cluster.server'", hide=not verbose
    ).stdout.strip()
    token_lines_json = ctx.run(
        dedent(
            """
        oc get secret -o yaml | yq '.items[] | select(.metadata.name | contains("token")) |
        {"name":.metadata.name, "token": .data.token | @base64d } ' -o json -I0
        """
        ).replace("\n", " "),
        hide=not verbose,
    ).stdout.splitlines()
    if not token_lines_json:
        sys.exit(f"No secrets with token were found in {server}")
    tokens = {
        minidict["name"]: minidict["token"]
        for minidict in map(json.loads, token_lines_json)
    }
    option = picker(
        ctx,
        tokens,
        prompt=f"Which token should we use for {server} for?"
        f"{kubeconfig} (Ctrl-C to cancel)?",
    )
    if not option:
        sys.exit("Cancelled by the user")
    if kubeconfig == "auto":
        kubeconfig = f".kubeconfig-{option}"
    args = ""
    if insecure_skip_tls_verify:
        args = f"{args} --insecure-skip-tls-verify"
    login: Result = ctx.run(
        f"oc login --token=$TOKEN {server} {args}",
        env={
            "TOKEN": tokens[option],
            "KUBECONFIG": kubeconfig,
        },
        warn=True,
    )
    if login.ok:
        print(f"Successfully logged in to {server}. Set KUBECONFIG={kubeconfig}")
    else:
        return
    if show_project:
        ctx.run(
            "oc project",
            env={
                "KUBECONFIG": kubeconfig,
            },
        )
