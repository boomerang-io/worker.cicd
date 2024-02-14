import ast
import os
from shlex import split
import sys
from importlib import import_module
from pathlib import Path
from subprocess import run, CalledProcessError
import invoke.exceptions
from invoke import Collection, Task

TASKS_KEEP_MODULE_NAME_PREFIX_ = os.environ.get(
    "TASKS_KEEP_MODULE_NAME_PREFIX", "False"
)

try:
    # Evaluate python expression, set to False on parsing error
    TASKS_KEEP_MODULE_NAME_PREFIX = ast.literal_eval(TASKS_KEEP_MODULE_NAME_PREFIX_)
except Exception:
    TASKS_KEEP_MODULE_NAME_PREFIX = False


def is_a_task_module(p: Path) -> bool:
    """Checks whether the file should be consider an task file"""
    if p.name.startswith("_"):
        return False
    if p.name == "tasks.py":
        # Avoid cyclic imports
        return False
    return True


def add_repo_root_to_sys_path() -> bool:
    """If running from a git repo, will find local_tasks.py in the toplevel"""
    try:
        top_level_git = run(split("git rev-parse --show-toplevel"), capture_output=True)
    except (CalledProcessError, FileNotFoundError):
        return False
    if top_level_git.returncode != 0:
        return False
    toplevel = top_level_git.stdout.strip().decode("utf-8")
    local_task_path = Path(toplevel) / "local_tasks.py"
    if not local_task_path.is_file():
        return False

    sys.path.insert(0, toplevel)
    return True


def find_and_import_tasks(
    where="__path__",
    keep_module_name_prefix=TASKS_KEEP_MODULE_NAME_PREFIX,
):
    """Autodiscovers any .py file in the tasks/ folder and adds it to the tasks
    collection. It can also split the task files into separate Collections.

    Parameters
    ----------
    where : str, optional
        The location where to find the modules, by default "__path__"
    keep_module_name_prefix : str, optional
        If "1" will split collections, by default
            os.environ.get("TASKS_KEEP_MODULE_NAME_PREFIX")

    Raises
    ------
    NotImplementedError
        When the where is not understood
    invoke.exceptions.Failure
        When the __path__ attribute fails to be spit (to be checked with PEX)
    """

    if isinstance(where, Path):
        mod_path_attribute = where.name
        path = where
    elif isinstance(where, str):
        mod_path_attribute = globals().get(where)
        try:
            path, *_ = mod_path_attribute
        except ValueError:
            raise invoke.exceptions.Failure(
                f"Failed to process tasks in {where}: {path}"
            )
    else:
        raise NotImplementedError(f"task discovery in {where} not implemented")

    global_ns = Collection()

    def populate(
        module,
        name,
    ):
        if keep_module_name_prefix:
            ns = Collection.from_module(
                module,
                name,
            )
            global_ns.add_collection(coll=ns, name=name)
        else:
            for name, task in module.__dict__.items():
                if not isinstance(task, Task):
                    continue
                global_ns.add_task(task)

    task_files = [p for p in Path(path).glob("*.py") if is_a_task_module(p)]
    for task_file in task_files:
        name = task_file.stem
        import_string = f"tasks.{name}"
        try:
            module = import_module(import_string)
        except Exception as error:
            print(
                f"The module {name} has the following error: {error}."
                "You will not see any of the task defined in it until you fix the "
                "problem.",
                sep="\n",
                file=sys.stderr,
            )
            continue

        populate(module=module, name=name)

    # Finally try to import repo's top level task

    if add_repo_root_to_sys_path():
        name = "local_tasks"
        try:
            module = import_module(name)
        except Exception as error:
            print(
                f"The module {name} has the following error: {error}."
                "You will not see any of the task defined in it until you fix the "
                "problem.",
                sep="\n",
                file=sys.stderr,
            )
        populate(module, name=name)

    return global_ns
