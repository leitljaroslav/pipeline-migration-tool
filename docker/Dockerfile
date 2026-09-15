FROM registry.access.redhat.com/ubi9/python-312@sha256:debc1c4ae8ce13a7b65f6dd8498e40c9f31c54b2eae922a59246dda987b00a83 AS builder

WORKDIR /projects

# Only setuptools + wheel are needed to build the sdist. They are prefetched via
# requirements-build.txt (setuptools==84.0.0, wheel). In the hermetic Konflux build
# the pip index env (PIP_FIND_LINKS/PIP_NO_INDEX) is injected automatically, so the
# versions resolve from the prefetched find-links; no env sourcing is needed.
# requirements-build.txt itself is not installable directly (it is a prefetch
# manifest containing multiple conflicting versions of the same build deps).
RUN pip install --use-pep517 "setuptools>=84.0"

COPY --chown=1001:0 . .

# Build the sdist (.tar.gz), a matching source .zip and SHA256SUMS into
# /projects/releases, and a wheel into /projects/dist for the runtime stage.
RUN bash docker/build-packages.sh

FROM registry.access.redhat.com/ubi9/python-312@sha256:debc1c4ae8ce13a7b65f6dd8498e40c9f31c54b2eae922a59246dda987b00a83

EXPOSE 8081/tcp
ENV FLASK_PORT=8081

WORKDIR /projects

COPY requirements.txt .

RUN pip install --use-pep517 -r requirements.txt

# Install the tool from the wheel built in the builder stage. Runtime deps are
# already installed above, so --no-deps keeps this hermetic (no resolution/network).
COPY --from=builder /projects/dist/*.whl /tmp/dist/
RUN pip install --no-cache-dir --no-deps /tmp/dist/*.whl

COPY --from=builder /projects/releases /releases

ENTRYPOINT [ "pipeline-migration-tool" ]