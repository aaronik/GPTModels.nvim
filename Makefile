TESTS_INIT=tests/minimal_init.lua
TESTS_DIR=tests

.PHONY: test

# TODO I want test to contain a lua-language-server pass

test_nvim:
	@nvim \
		--headless \
		--noplugin \
		-u ${TESTS_INIT} \
		-c "PlenaryBustedDirectory ${TESTS_DIR} { minimal_init = '${TESTS_INIT}' }"

test:
	-$(MAKE) test_nvim || exit 1

test-watch:
	nodemon -e lua -x "$(MAKE) test"
