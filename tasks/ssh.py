from invoke import task, Context


@task(autoprint=True)
def ssh_host(ctx: Context):
    return ctx.run(
        'grep -h "^Host" ~/.ssh/config ~/.ssh/config.d/* | '
        r"grep -v '\*' | sed -e s/Host//g | awk '{ print $1}'",
        hide="out",
        pty=True,
    ).stdout


@task()
def create_ssh_key_private_rsa(ctx: Context, comment=None, name="key"):
    """
    Creates a ssh key-pair with private RSA.
    """
    if not comment:
        comment = "taskfiles.automation"
    ctx.run(f"ssh-keygen -t rsa -b 4096 -C '{comment}' -f {name}.pem")
    ctx.run(f"ssh-keygen -p -N '' -m pem -f {name}.pem")
