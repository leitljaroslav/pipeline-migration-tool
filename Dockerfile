FROM registry.access.redhat.com/ubi10/python-312-minimal:10.2@sha256:438056e6f95de4fd39e560bf5be5ef45216427a4f8e0d6e7187ba4ca179ad02d AS base
USER root
COPY requirements.txt requirements-build.txt ./
RUN python3.12 -m venv /venv && \
    /venv/bin/pip install -r requirements-build.txt --no-deps --no-cache-dir --require-hashes && \
    /venv/bin/pip install -r requirements.txt --no-deps --no-cache-dir --require-hashes
COPY . .
RUN /venv/bin/pip install --no-cache-dir .

##########################
# GENERATE RELEASE ARTIFACTS (sdist, wheel, checksums, manifest) FROM SOURCE
# Version is read from src/pipeline_migration/__init__.py.
# This only builds the installable sdist/wheel artifacts
##########################
FROM registry.access.redhat.com/ubi10/python-312-minimal:10.2@sha256:438056e6f95de4fd39e560bf5be5ef45216427a4f8e0d6e7187ba4ca179ad02d AS package
USER root
COPY --from=base /venv /venv
WORKDIR /src
COPY . .
RUN mkdir -p /out && /venv/bin/python hack/build_release_artifacts.py /out

##########################
# RELEASE IMAGE
# Based on ubi10-minimal rather than scratch so it satisfies the
# ecosystem-cert-preflight-checks Conforma gate
##########################
FROM registry.access.redhat.com/ubi10/ubi-minimal:10.2@sha256:a9f9316ec3a1419a2de6ce4d2d9f034d477e97cdf2a16d6f04b7bd632ac753c4 as release
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
FROM registry.access.redhat.com/ubi10/python-312-minimal:10.2@sha256:438056e6f95de4fd39e560bf5be5ef45216427a4f8e0d6e7187ba4ca179ad02d as runtime
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
