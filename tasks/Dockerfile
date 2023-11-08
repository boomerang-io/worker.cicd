FROM python:3.11-slim
# 👇 keep these lines together
ARG COMMIT_ID=unknown \
    GIT_BRANCH=unknown \
    CHECKOUT_STATUS=unknown

ENV COMMIT_ID=${COMMIT_ID} \
    GIT_BRANCH=${GIT_BRANCH} \
    CHECKOUT_STATUS=${CHECKOUT_STATUS}
# 👆 keep these lines together

RUN apt-get update && apt-get -yqq install git-core gettext
RUN curl -fsSL https://clis.cloud.ibm.com/install/linux | sh

# hadolint ignore=DL3013
RUN pip install --no-cache-dir "invoke>2.0,<3.0" hunter pdbpp

COPY . /tasks/

ENV UID=2000 \
    USER=user

ENV PATH=/home/$USER/.local/bin:$PATH

# hadolint ignore=SC2086
RUN groupadd -g ${UID} -r ${USER} \
    && useradd -l -u ${UID} -r -g ${USER} ${USER} && \
    mkdir -p /home/${USER}/.local/bin && \
    mkdir -p /home/${USER}/.cache && \
    chown -R ${USER} /home/${USER}

USER ${USER}
WORKDIR /
RUN ibmcloud plugin install cdb ks sm
# RUN inv install-oc install-yq
ENTRYPOINT [ "bash" ]
