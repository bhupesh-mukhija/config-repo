# Container image that runs your code
FROM alpine:3.14

ARG SFDX_INSTALLER=sfdx-linux-x64.tar.xz
ARG SFDX_URL=https://developer.salesforce.com/media/salesforce-cli/sfdx/channels/stable/sfdx-linux-x64.tar.xz

RUN mkdir /root/entrypoint

# Copies your code file from your action repository to the filesystem path `/` of the container
#COPY createPackage.sh /createPackage.sh
COPY entrypoint.sh /root/entrypoint/entrypoint.sh
#COPY scripts/bash/utility.sh /root/scripts/bash/utility.sh

# Code file to execute when the docker container starts up (`entrypoint.sh`)
# entrypoint path is depneding on github action, change required for local
ENTRYPOINT ["/root/scripts/entrypoint.sh"]

# not using --update option in adding curl "https://github.com/gliderlabs/docker-alpine/blob/master/docs/usage.md"
# use sfdx
RUN    apk update \
    && apk add --no-cache \
                    bash \
                    curl \
                    tzdata \
                    xz \
                    jq \
                    npm

RUN    mkdir ~/sfdx \
    && mkdir ~/secrets \
    && ls -l root/ \
    && wget $SFDX_URL \
    && tar xJf $SFDX_INSTALLER -C ~/sfdx --strip-components 1 \
    && PATH=~/sfdx/bin:$PATH \
    && which sfdx \
    && rm ~/sfdx/bin/node \
    && ln -s /usr/local/bin/node ~/sfdx/bin/node \
    && sfdx --version \
    && apk del curl \
    && rm $SFDX_INSTALLER