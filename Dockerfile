FROM registry.access.redhat.com/ubi10/ubi@sha256:6e3f045f5380e8d8dffaea7e01bf926d2db44aff751048697e780d1253687843 AS builder

WORKDIR /src

COPY requirements.txt requirements-build.txt ./
RUN python3.12 -m venv /venv && \
    /venv/bin/pip install -r requirements-build.txt --no-deps --no-cache-dir --require-hashes && \
    /venv/bin/pip install -r requirements.txt --no-deps --no-cache-dir --require-hashes

COPY . .
RUN /venv/bin/pip install --no-deps --no-cache-dir .

FROM builder AS final

LABEL maintainer="Red Hat"
COPY --from=builder /venv /venv
RUN ln -s /venv/bin/pipeline-migration-tool /usr/local/bin/pipeline-migration-tool
ENTRYPOINT [ "/usr/local/bin/pipeline-migration-tool" ]