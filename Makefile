LUA ?= ./lua
STABLE_TL ?= $(LUA) ./tl
NEW_TL ?= $(LUA) ./tl
TLGENFLAGS = --check --gen-target=5.1
BUSTED = busted --suppress-pending

PRECOMPILED = teal/precompiled/default_env.lua
SOURCES = teal/debug.tl teal/attributes.tl teal/errors.tl teal/lexer.tl \
	teal/reader.tl teal/block-parser.tl teal/check/block_string_checker.tl teal/check/block_file_checker.tl tl-block.tl\
	teal/util.tl teal/types.tl teal/facts.tl teal/parser.tl teal/traversal.tl \
	teal/gen/lua_generator.tl teal/gen/lua_compat.tl teal/variables.tl teal/type_reporter.tl \
	teal/macroexps.tl teal/metamethods.tl \
	teal/type_errors.tl teal/environment.tl \
	teal/check/context.tl teal/check/visitors.tl teal/check/check.tl \
	teal/check/relations.tl teal/check/special_functions.tl \
	teal/check/type_checker.tl teal/check/node_checker.tl \
	teal/check/file_checker.tl teal/check/string_checker.tl \
	teal/check/require_file.tl teal/package_loader.tl tl.tl

all: selfbuild suite

########################################
# Multi-stage bootstrap process:
########################################

precompiler.lua: precompiler.tl
	$(STABLE_TL) gen $< -o $@ || { rm $@; exit 1; }

teal/precompiled/default_env.lua: precompiler.lua teal/default/prelude.d.tl teal/default/stdlib.d.tl tl.tl
	$(LUA) precompiler.lua > teal/precompiled/default_env.lua || { rm $@; exit 1; }

_temp/%.lua.1: %.tl $(PRECOMPILED)
	@mkdir -p `dirname $@`
	$(STABLE_TL) gen $(TLGENFLAGS) $< -o $@ || { rm $@; exit 1; }

_temp/%.lua.2: %.tl _temp/%.lua.1 $(PRECOMPILED)
	$(NEW_TL) gen $(TLGENFLAGS) $< -o $@ || extras/make.sh revert

build1: $(addprefix _temp/,$(addsuffix .lua.1,$(basename $(SOURCES))))

replace1:
	extras/make.sh move_1_to_lua

build2: $(addprefix _temp/,$(addsuffix .lua.2,$(basename $(SOURCES))))

selfbuild: build1 replace1 build2
	extras/make.sh diff_1_and_2 || extras/make.sh revert

########################################
# Test suite:
########################################

suite:
	${BUSTED} -v $(TESTFLAGS) spec/block-lang
	${BUSTED} -v $(TESTFLAGS) spec/lang
	${BUSTED} -v $(TESTFLAGS) spec/api
	${BUSTED} -v $(TESTFLAGS) spec/cli

########################################
# Utility targets:
########################################

bin:
	$(MAKE) STABLE_TL=_binary/build/tl

binary:
	extras/binary.sh --clean

revert:
	git checkout $(PRECOMPILED) $(addsuffix .lua,$(basename $(SOURCES)))

cov:
	rm -f luacov.stats.out luacov.report.out
	${BUSTED} -c
	luacov tl.lua
	cat luacov.report.out

cleantemp:
	rm -rf _temp

clean: cleantemp

########################################
# Makefile administrivia
########################################

.PHONY: all build1 replace1 build2 selfbuild \
	suite bin binary cov revert cov cleantemp clean
