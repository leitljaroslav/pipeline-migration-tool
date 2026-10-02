define compile_deps
	pip-compile --generate-hashes $(1) --output-file=requirements.txt pyproject.toml
	pip-compile --extra=test --generate-hashes $(1) --output-file=requirements-test.txt pyproject.toml
	pip-compile --allow-unsafe --generate-hashes $(1) --output-file=requirements-build.txt requirements-build.in
endef

.PHONY: deps/compile deps/upgrade

deps/compile:
	$(call compile_deps)

deps/upgrade:
	$(call compile_deps,--upgrade)


.PHONY: venv/create venv/remove venv/recreate

venv/create:
	python3 -m venv --upgrade-deps .venv
	.venv/bin/python3 -m pip install -r requirements-test.txt
	.venv/bin/python3 -m pip install pip-tools pybuild-deps

venv/remove:
	rm -rf .venv

venv/recreate: venv/remove venv/create
