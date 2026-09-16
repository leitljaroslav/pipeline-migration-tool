FROM registry.access.redhat.com/ubi10/python-312-minimal@sha256:0f71645815e5e9fa5cbbbba051047fd3a276a45171e591498802a76c156c3a7c as base
########################
# PREPARE OUR BASE IMAGE
########################

FROM base AS builder
WORKDIR /src
USER root
RUN mkdir -p /venv && \
    mkdir -p /releases && \
    mkdir -p /src && \
    chown -R 1001:0 /venv /releases /src

USER 1001
WORKDIR /src
COPY --chown=1001:0 requirements.txt requirements-build.txt build-constraints.txt ./
RUN python3.12 -m venv /venv && \
    /venv/bin/pip install -r requirements-build.txt -c build-constraints.txt --no-deps --no-cache-dir --require-hashes && \
    /venv/bin/pip install -r requirements.txt --no-deps --no-cache-dir --require-hashes
COPY --chown=1001:0 . .
RUN /venv/bin/pip install --no-cache-dir -c build-constraints.txt .

# Build release artifacts (tar.gz, zip, SHA256SUMS) into /releases
# The script needs to import pipeline_migration (to read __version__) and setuptools (to build sdist)
RUN bash -c '. /venv/bin/activate && bash docker/build-packages.sh /releases'

##############################
# ASSEMBLE THE RELEASE IMAGE #
##############################

FROM builder AS release
WORKDIR /releases
COPY --from=builder /releases /releases

##########################
# ASSEMBLE THE FINAL IMAGE
##########################
FROM base AS final
LABEL maintainer="Red Hat"
COPY --from=builder /venv /venv
ENTRYPOINT [ "/venv/bin/pipeline-migration-tool" ]
