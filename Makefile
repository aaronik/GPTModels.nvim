TESTS_INIT=tests/minimal_init.lua
TESTS_DIR=tests

.PHONY: test

test_nvim:
	@nvim \
		--headless \
		--noplugin \
		-u ${TESTS_INIT} \
		-c "PlenaryBustedDirectory ${TESTS_DIR} { minimal_init = '${TESTS_INIT}' }"

test:
	$(MAKE) test_nvim

test-watch:
	nodemon -e lua -x "$(MAKE) test || exit 1"

build-doc:
	pre-commit run

# Currently not used; README.md is in :help
install-precommit-hook:
	pre-commit install

ensure-no-util-r:
	! grep --exclude-dir=.git -r --exclude test.yml 'util.R' | grep -v '\-\-'

# Run everything, if it's a 0 code, everything's good
pass: test ensure-no-util-r
