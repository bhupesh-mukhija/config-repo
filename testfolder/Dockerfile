# Container image that runs your code
FROM alpine:3.10

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY entrypoint.sh /entrypoint.sh

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]

# not using --update option in adding curl "https://github.com/gliderlabs/docker-alpine/blob/master/docs/usage.md"
# use sfdx 
RUN apk update \
    && apk add --no-cache curl \
    && mkdir sfdx \
    && wget $SFDX_URL \
    && tar xJf $SFDX_INSTALLER -C sfdx --strip-components 1 \
    && ./sfdx/install \
    && rm -r sfdx \
    && apk add jq \
    && rm -rf /var/cache/apk/* \
    && apk del curl