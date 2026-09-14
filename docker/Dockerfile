FROM registry.access.redhat.com/ubi9/python-312

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
# CMD [ "python", "./app.py" ]
ENTRYPOINT [ "pipeline-migration-tool" ]