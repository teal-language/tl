LUA ?=

ifeq ($(OS), Windows_NT)
	BUSTED = busted.bat --suppress-pending --exclude-tags=unix
else
	BUSTED = busted --suppress-pending
endif

PRECOMPILED = teal/precompiled/default_env.lua
SOURCES = teal/debug.tl teal/attributes.tl teal/errors.tl teal/lexer.tl \
	teal/util.tl teal/types.tl teal/facts.tl teal/parser.tl teal/traversal.tl \
	teal/gen/lua_generator.tl teal/variables.tl teal/type_reporter.tl \
	teal/type_errors.tl teal/environment.tl teal/checker/checker.tl \
	teal/checker/type_checker.tl teal/checker/file_checker.tl \
	teal/checker/string_checker.tl teal/checker/require_file.tl \
	teal/package_loader.tl tl.tl

all: selfbuild suite

precompiler.lua: precompiler.tl
	$(LUA) ./tl gen $< -o $@ || { rm $@; exit 1; }

teal/precompiled/default_env.lua: precompiler.lua teal/default/prelude.d.tl teal/default/stdlib.d.tl tl.tl
	lua precompiler.lua > teal/precompiled/default_env.lua || { rm $@; exit 1; }

_temp/%.lua.1: %.tl $(PRECOMPILED)
	@mkdir -p `dirname $@`
	$(LUA) ./tl gen --check --gen-target=5.1 $< -o $@ || { rm $@; exit 1; }

_temp/%.lua.2: %.tl _temp/%.lua.1 $(PRECOMPILED)
	$(LUA) ./tl gen --check --gen-target=5.1 $< -o $@ || extras/make.sh revert

build1: $(addprefix _temp/,$(addsuffix .lua.1,$(basename $(SOURCES))))

replace1:
	extras/make.sh move_1_to_lua

build2: $(addprefix _temp/,$(addsuffix .lua.2,$(basename $(SOURCES))))

selfbuild: build1 replace1 build2
	extras/make.sh diff_1_and_2 || extras/make.sh revert

suite:
	${BUSTED} -v $(TESTFLAGS) spec/lang
	${BUSTED} -v $(TESTFLAGS) spec/api
	${BUSTED} -v $(TESTFLAGS) spec/cli

cov:
	rm -f luacov.stats.out luacov.report.out
	${BUSTED} -c
	luacov tl.lua
	cat luacov.report.out

cleantemp:
	rm -rf _temp

clean: cleantemp
