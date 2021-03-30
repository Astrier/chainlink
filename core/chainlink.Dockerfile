# MAKE ALL CHANGES WITHIN THE DEFAULT WORKDIR FOR YARN AND GO DEP CACHE HITS

ARG BUILDER=smartcontract/builder
FROM ${BUILDER}:1.0.39
WORKDIR /chainlink
# Have to reintroduce ENV vars from builder image
ENV PATH /go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY GNUmakefile VERSION ./
COPY tools/bin/ldflags tools/bin/ldflags
ARG COMMIT_SHA

# Install yarn dependencies
COPY yarn.lock package.json .yarnrc ./
COPY patches patches
COPY solc_bin solc_bin
COPY .yarn .yarn
COPY operator_ui/package.json ./operator_ui/
COPY belt/package.json ./belt/
COPY belt/bin ./belt/bin
COPY evm-test-helpers/package.json ./evm-test-helpers/
COPY evm-contracts/package.json ./evm-contracts/
COPY tools/bin/restore-solc-cache ./tools/bin/restore-solc-cache
RUN make yarndep


COPY tsconfig.cjs.json tsconfig.es6.json ./
COPY operator_ui ./operator_ui
COPY belt ./belt
COPY belt/bin ./belt/bin
COPY evm-test-helpers ./evm-test-helpers
COPY evm-contracts ./evm-contracts

# Build operator-ui and the smart contracts
RUN make contracts-operator-ui-build

# Build the golang binary

FROM ${BUILDER}:1.0.39
WORKDIR /chainlink

# Have to reintroduce ENV vars from builder image
ENV PATH /go/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY GNUmakefile VERSION ./
COPY tools/bin/ldflags ./tools/bin/

# Env vars needed for chainlink build
ADD go.mod go.sum ./
RUN go mod download

# Env vars needed for chainlink build
ARG COMMIT_SHA
ARG ENVIRONMENT

COPY --from=0 /chainlink/evm-contracts/abi ./evm-contracts/abi
COPY --from=0 /chainlink/operator_ui/dist ./operator_ui/dist
COPY core core
COPY packr packr

RUN make chainlink-build

# Final layer: ubuntu with chainlink binary
FROM quay.io/spivegin/tlmbasedebian
ENV DINIT=1.2.4 \
    DEBIAN_FRONTEND=noninteractive 
    
ADD https://github.com/Yelp/dumb-init/releases/download/v1.2.4/dumb-init_${DINIT}_amd64.deb /tmp/dumb-init.deb

RUN apt-get update && apt upgrade -y &&\
    apt-get install -y apt-transport-https gnupg2 curl proxychains psmisc nano procps lsof && \
    dpkg -i /tmp/dumb-init.deb &&\
    apt-get autoclean && apt-get autoremove &&\
    rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/* /root/*

ARG CHAINLINK_USER=root
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y ca-certificates
COPY --from=1 /go/bin/chainlink /usr/local/bin/

RUN if [ ${CHAINLINK_USER} != root ]; then \
  useradd --uid 14933 --create-home ${CHAINLINK_USER}; \
  fi
USER ${CHAINLINK_USER}
WORKDIR /home/${CHAINLINK_USER}

EXPOSE 6688
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["chainlink"]
# ENTRYPOINT ["chainlink"]
# CMD ["local", "node"]
