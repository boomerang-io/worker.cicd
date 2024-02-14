import sys
from typing import Optional
from invoke import Context, task
import os

# from ._discovery import find_and_import_tasks

# FIXME: Improve task location resolution
# @task()
# def show_tasks_env_vars(ctx: Context):
#     """
#     Finds the environment variables defined for the reachable task modules
#     """
#     and show them.
#     print(find_and_import_tasks(__file__))


@task()
def self_trace(
    ctx,
    query_: list[str] = [],
    verbose: bool = False,
    action: Optional[str] = "VarsSnooper",
):  # noqa: F821
    """
    Enables tracing of execution of the tasks.
    Consider this as bash -x with selections.

    For more sophisticated calls use PYTHONHUNTER=xxx inv yyy
    Read more about it at: https://python-hunter.readthedocs.io/en/latest/introduction.html#activation
    """
    try:
        import hunter  # noqa: F401
    except ImportError:
        sys.exit("hunter package not available")

    if not query_:
        query_ = ["module_sw=tasks"]

    def build_query(a_string):
        key, value = a_string.split(
            "=",
        )
        kw = {key: value}
        return hunter.Query(**kw)

    queries = [build_query(query) for query in query_]
    if verbose:
        print(queries, file=sys.stderr)

    hunter.trace(*queries, stdlib=False)


@task(
    autoprint=True,
)
def show_interpreter(ctx: Context):
    """Shows the Python interpreter being used"""
    return sys.executable


@task(autoprint=True)
def version(ctx: Context):
    env_keys = ("COMMIT_ID", "GIT_BRANCH", "CHECKOUT_STATUS")
    info = {name: os.environ.get(name, "missing") for name in env_keys}
    return info
