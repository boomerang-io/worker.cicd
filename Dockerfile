#Import the base worker
FROM tools.boomerangplatform.net:8500/ise/bmrg-worker-base:2.0.0

WORKDIR /opt/bin

#Add Packages
RUN apk add --no-cache bash sed grep curl coreutils nodejs npm ca-certificates make openssh-client git socat skopeo openssl && \
    curl -fSL "https://github.com/genuinetools/img/releases/download/v0.5.7/img-linux-amd64" -o "/opt/bin/img" && chmod a+x "/opt/bin/img"

WORKDIR /cli
ADD ./package.json ./package-lock.json ./
ADD ./cicd ./cicd
ADD ./commands ./commands
RUN npm install

ENTRYPOINT [ "node", "cli" ]
