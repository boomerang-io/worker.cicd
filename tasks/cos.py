"""
This model allow to access Cloud Object Storage
"""
# Debugging tip:
# PYTHONHUNTER='module__contains="cos", actions=[CodePrinter, VarsSnooper]' inv cos-list-bucket s3://bucket
import json
import os
import sys
import urllib.request
from pathlib import Path
from shutil import which
from tempfile import NamedTemporaryFile

from invoke import Context, task

from ._utils import create_request
from .setup import install_yq

COS_ENDPOINT_URL = os.environ.get("COS_ENDPOINT_URL", None)
COS_YQ_QUERY = os.environ.get(
    "COS_YQ_QUERY", ".service-endpoints.regional.us-south.public.us-south"
)


# TODO: Move to utils?
@task()
def json_selector_on_json_url(
    ctx: Context,
    url: str,
    selector=COS_YQ_QUERY,
    verbose=False,
) -> str:
    """Retrieves JSON from a URL and queries it using yq, similar to
    curl <url> | yq <selector>
    """
    if verbose:
        print(f"Requesting {url}", file=sys.stderr)
    try:
        req = create_request(url)
        response = urllib.request.urlopen(req)
    except urllib.error.HTTPError as error:
        sys.exit(f"Error reading from {url}: {error}")
    if not which("yq"):
        install_yq(ctx)

    with NamedTemporaryFile("w", suffix=".json") as fp:
        fp.write(response.read().decode("utf-8"))
        fp.flush()
        endpoint = ctx.run(
            f"yq -r eval {selector} {fp.name}",
            echo=verbose,
            hide=not verbose,
        ).stdout

    return f"https://{endpoint}".strip()


def read_credentials(json_credentials):
    try:
        json_file = Path(next(Path(".").glob(json_credentials)))
    except StopIteration:
        sys.exit(
            "No JSON credentials has been found, please provide --json-credentials "
            "parameters."
        )
    try:
        with json_file.open() as fp:
            data = json.load(fp)
    except json.decoder.JSONDecodeError:
        sys.exit(
            "Errors decoding the json credential files. Is it a JSON file?: "
            f"{json_file}"
        )
    return data


@task(
    autoprint=True,
)
def cos_env_from_json(
    ctx: Context, json_credentials="*.json", eval_=False, dict_=False
) -> str:
    if eval_ and dict_:
        sys.exit("Only one of these flags can be activated at a time: --eval, --dict")

    if not eval_ and not dict_:
        print("# Defaulting to eval", file=sys.stderr)
        eval_ = True

    data = read_credentials(json_credentials=json_credentials)

    creds = {
        f"AWS_{k.upper()}": value
        for k, value in data.items()
        if k in {"access_key_id", "secret_access_key"}
    }
    if eval_:
        print("# Run eval $(inv cos-env-from-json)")
        eval_str = " ".join(f"{k}={v}" for k, v in creds.items())
        return f"export {eval_str}"
    elif dict_:
        return creds


@task(
    autoprint=True,
    help={
        "json_credentials": "JSON credentials, can be a pattern glob (i.e. creds*.json)",
        "endpoint_url": "Override the endpoint URL",
    },
)
def cos_command_from_json(
    ctx: Context,
    json_credentials="*.json",
    endpoint_url=COS_ENDPOINT_URL,
    verbose=False,
    inline_credentials=True,
):
    """Show the command to use COS with AWS CLI. Run it in the folder where your
    credentials.json is located.

    """
    if not which("aws"):
        print("👀 aws CLI not found", file=sys.stderr)
    data = read_credentials(json_credentials=json_credentials)
    access_key_id = data["access_key_id"]
    secret_access_key = data["secret_access_key"]
    endpoint_url = endpoint_url or json_selector_on_json_url(
        ctx, data["endpoints"], verbose=verbose
    )
    if inline_credentials:
        credentials = (
            f"AWS_ACCESS_KEY_ID={access_key_id} "
            f"AWS_SECRET_ACCESS_KEY={secret_access_key} "
        )
    else:
        credentials = ""
    return f"{credentials}" f"aws --endpoint-url={endpoint_url}"


@task()
def cos_list_bucket(
    ctx: Context,
    bucket,
    json_credentials="*.json",
    endpoint_url=COS_ENDPOINT_URL,
    verbose=False,
) -> None:
    """
    Run aws s3 ls with reading the COS credentials.
    If the bucket is not found, try providing the endpoint_url.
    """
    command = cos_command_from_json(
        ctx,
        json_credentials=json_credentials,
        endpoint_url=endpoint_url,
        inline_credentials=False,
    ).strip()
    if bucket and not bucket.startswith("s3://"):
        bucket = f"s3://{bucket}"

    ctx.run(
        f"{command} s3 ls {bucket or ''}",
        echo=verbose,
        env=cos_env_from_json(ctx, json_credentials=json_credentials, dict_=True),
    )


@task()
def presign_url(ctx: Context, key) -> str:
    ...
