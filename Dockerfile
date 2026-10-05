FROM quay.io/konflux-ci/rust-builder:1.94.1@sha256:8e84d5507f664cd2d3c6dfa1ad5ac33c3fd13480d6571c4ec1b9c3d26a28f0bc AS rust-builder
FROM registry.access.redhat.com/ubi9/python-312:latest@sha256:e6a10c3150624fbfd33dbd7721ef99ce7a1001b417d64427ad58515ab8044121 AS base
USER root
COPY requirements.txt requirements-build.txt ./
COPY --from=rust-builder /usr/local/share/rust /usr/local/share/rust
ENV PATH="/usr/local/share/rust/bin:${PATH}"

# Use pip from the base image to install the requirements.
# The bundled pip is older than the one in the base image and does not includes this:
# https://github.com/pypa/pip/pull/12449
# So the build fails with missing wheel package when install oras from requirements.txt which does
# not have a `build-system` metadata in pyproject.toml.
RUN python3.12 -m venv --without-pip /venv && pip --python=/venv/bin/python install -r requirements.txt
COPY . .
RUN pip --python=/venv/bin/python install --no-cache-dir .

##########################
# GENERATE RELEASE ARTIFACTS (sdist, wheel, checksums, manifest) FROM SOURCE
# Version is read from src/pipeline_migration/__init__.py.
# This only builds the installable sdist/wheel artifacts
##########################
FROM registry.access.redhat.com/ubi9/python-312-minimal:9.8@sha256:bdfae86a800f2a1eb520a69e79e59f9f03ba5368dc54be5caf454dd5c0f382f2 AS package
USER root
COPY --from=base /venv /venv
USER root
RUN ln -s /venv/bin/pipeline-migration-tool /usr/local/bin/pipeline-migration-tool

USER 1001

ENTRYPOINT [ "/usr/local/bin/pipeline-migration-tool" ]

##########################
# RELEASE IMAGE
# Based on ubi9-minimal to satisfy Conforma gate
##########################
FROM registry.access.redhat.com/ubi9/ubi-minimal:9.8@sha256:1d7c5517a4a1a8e2688620b39ee980e82505ca1ab7ae5541b5463120ae9b3897 as release
ARG APP_VERSION=0.9.0
LABEL maintainer="Red Hat"
LABEL io.k8s.display-name="pipeline-migration-tool-release"
LABEL io.openshift.tags="konflux, pipeline-migration-tool, cli"
LABEL summary="pipeline-migration-tool"
LABEL description="Release artifacts (sdist, wheel, checksums, manifest) for pipeline-migration-tool"
LABEL name="pipeline-migration-tool-release"
LABEL com.redhat.component="pipeline-migration-tool"
LABEL vendor="Red Hat, Inc."
LABEL version=$APP_VERSION
LABEL release="1"
COPY LICENSE /licenses/LICENSE
COPY --from=package --chown=1001:0 /out/* /releases/
USER 1001

##########################
# ASSEMBLE THE FINAL (SLIM) IMAGE
##########################
FROM registry.access.redhat.com/ubi9/python-312-minimal:9.8@sha256:bdfae86a800f2a1eb520a69e79e59f9f03ba5368dc54be5caf454dd5c0f382f2 AS runtime
LABEL maintainer="Red Hat"
LABEL io.k8s.display-name="pipeline-migration-tool"
LABEL io.openshift.tags="konflux, pipeline-migration-tool, cli"
LABEL summary="pipeline-migration-tool"
LABEL name="pipeline-migration-tool"
LABEL com.redhat.component="pipeline-migration-tool"

COPY --from=base /venv /venv
USER root
RUN ln -s /venv/bin/pipeline-migration-tool /usr/local/bin/pipeline-migration-tool

USER 1001

ENTRYPOINT [ "/usr/local/bin/pipeline-migration-tool" ]
