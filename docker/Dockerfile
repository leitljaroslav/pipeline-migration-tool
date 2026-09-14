FROM registry.access.redhat.com/ubi9/python-312@sha256:debc1c4ae8ce13a7b65f6dd8498e40c9f31c54b2eae922a59246dda987b00a83

# Set the working directory in the container
WORKDIR /projects

# Copy the dependencies files to the working directory
COPY requirements.txt .
COPY requirements-build.txt .

# Install any dependencies
RUN pip install --use-pep517 -r requirements.txt
# Copy the content of the local src directory to the working directory
COPY --chown=1001:0 . .

RUN pip install --no-cache-dir .


# Specify the command to run on container start
ENTRYPOINT [ "pipeline-migration-tool" ]