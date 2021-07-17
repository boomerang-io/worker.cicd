mkdir -p /kaniko/.docker

echo "{\"auths\":{\"test:test1\":{\"username\":\"user\",\"password\":\"password\"}}}" > /kaniko/.docker/config.json

less /kaniko/.docker/config.json

/kaniko/executor