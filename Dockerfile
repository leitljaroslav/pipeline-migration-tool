FROM registry.access.redhat.com/ubi10/python-312-minimal:10.2@sha256:438056e6f95de4fd39e560bf5be5ef45216427a4f8e0d6e7187ba4ca179ad02d AS base
USER root
COPY requirements.txt requirements-build.txt ./
RUN python3.12 -m venv /venv && \
    /venv/bin/pip install -r requirements-build.txt --no-deps --no-cache-dir --require-hashes && \
    /venv/bin/pip install -r requirements.txt --no-deps --no-cache-dir --require-hashes
COPY . .
RUN /venv/bin/pip install --no-cache-dir .

##########################
# GENERATE RELEASE ARTIFACTS (tarball, zip, checksums, manifest) FROM SOURCE
# Version is read from src/pipeline_migration/__init__.py, so this always
# matches whatever revision is being built -- no GitHub release dependency.
#
# Hermetic builds cannot install packages and the
# python-312-minimal base lacks tar/gzip/zip. The full ubi10/ubi image ships
# python3 out of the box, so packaging is done with stdlib tarfile/zipfile
##########################
FROM registry.access.redhat.com/ubi10/ubi:10.2@sha256:223f8b83bcaa1159416724627ff2fadbfd2444653756b0c00d9dae1eacccbfbc AS package
WORKDIR /src
COPY . .
RUN mkdir -p /out && python3 hack/build-release-artifacts.py /out

##########################
# IMAGE WITH RELEASE ARTIFACTS BAKED IN (manual: buildah build --target release)
# Not built by default -- docker-build-oci-ta has no target-stage param, so it
# always builds through to the LAST stage in this file, which is the slim one below.
##########################
FROM registry.access.redhat.com/ubi10/python-312-minimal:10.2@sha256:438056e6f95de4fd39e560bf5be5ef45216427a4f8e0d6e7187ba4ca179ad02d as release
LABEL maintainer="Red Hat"
LABEL io.k8s.display-name="pipeline-migration-tool-release"
LABEL io.openshift.tags="konflux, pipeline-migration-tool, cli"
LABEL summary="pipeline-migration-tool"
LABEL name="pipeline-migration-tool-release"
LABEL com.redhat.component="pipeline-migration-tool"

COPY --from=base /venv /venv
USER root
RUN mkdir -p /releases
COPY --from=package --chown=1001:0 /out/* /releases/

RUN ln -s /venv/bin/pipeline-migration-tool /usr/local/bin/pipeline-migration-tool

USER 1001

ENTRYPOINT [ "/usr/local/bin/pipeline-migration-tool" ]

##########################
# ASSEMBLE THE FINAL (SLIM) IMAGE -- this is what Konflux builds and ships by default
##########################
FROM registry.access.redhat.com/ubi10/python-312-minimal:10.2@sha256:438056e6f95de4fd39e560bf5be5ef45216427a4f8e0d6e7187ba4ca179ad02d
LABEL maintainer="Red Hat"
LABEL io.k8s.display-name="pipeline-migration-tool"
LABEL io.openshift.tags="konflux, pipeline-migration-tool, cli"
LABEL summary="pipeline-migration-tool"
LABEL name="pipeline-migration-tool"
LABEL com.redhat.component="pipeline-migration-tool"

COPY --from=base /venv /venv
# TEMPORARY: copy release artifacts from the package stage to please the pipeline overlords
COPY --from=package --chown=1001:0 /out/* /releases/
USER root
RUN ln -s /venv/bin/pipeline-migration-tool /usr/local/bin/pipeline-migration-tool

USER 1001

ENTRYPOINT [ "/usr/local/bin/pipeline-migration-tool" ]
