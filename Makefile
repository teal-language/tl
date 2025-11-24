LUA ?= lua
STABLE_TL ?= $(LUA) ./tl
NEW_TL ?= $(LUA) ./tl
TLGENFLAGS = --check --gen-target=5.1
BUSTED = busted --suppress-pending

PRECOMPILED = teal/precompiled/default_env.lua
SOURCES = teal/debug.tl teal/attributes.tl teal/errors.tl teal/lexer.tl \
	teal/reader.tl teal/reader_api.tl teal/block.tl \
	teal/util.tl teal/types.tl teal/facts.tl teal/parser.tl teal/traversal.tl \
	teal/variables.tl teal/type_reporter.tl \
	teal/macroexps.tl teal/macro_eval.tl teal/metamethods.tl \
	teal/type_errors.tl teal/environment.tl \
	teal/check/context.tl teal/check/visitors.tl teal/check/check.tl \
	teal/check/relations.tl teal/check/special_functions.tl \
	teal/check/type_checker.tl teal/check/node_checker.tl \
	teal/input.tl \
	teal/check/require_file.tl \
	teal/gen/targets.tl teal/gen/lua_generator.tl teal/gen/lua_compat.tl \
	teal/package_loader.tl teal/loader.tl \
	teal/api/v2.tl teal/api/v1.tl \
	teal/init.tl \
	tl.tl \
	tlcli/configuration.tl \
	tlcli/report.tl \
	tlcli/driver.tl \
	tlcli/perf.tl \
	tlcli/main.tl \
	tlcli/commands/run.tl \
	tlcli/commands/warnings.tl \
	tlcli/commands/types.tl \
	tlcli/commands/check.tl \
	tlcli/commands/gen.tl \
	tlcli/common.tl

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
	@echo $< >> _temp/list1
	@echo $@ >> _temp/list1.1
	@touch $@

_temp/%.lua.2: %.tl _temp/%.lua.1 $(PRECOMPILED)
	@mkdir -p `dirname $@`
	@echo $< >> _temp/list2
	@touch $@

build1: $(addprefix _temp/,$(addsuffix .lua.1,$(basename $(SOURCES))))
	if [ -e _temp/list1 ]; \
	then $(STABLE_TL) gen $(TLGENFLAGS) --root . --custom-ext .lua.1 --output-dir _temp `cat _temp/list1` || { rm `cat _temp/list1.1`; exit 1; };\
	fi

replace1:
	extras/make.sh move_1_to_lua
	@rm -f _temp/list2

build2: $(addprefix _temp/,$(addsuffix .lua.2,$(basename $(SOURCES))))
	if [ -e _temp/list2 ]; \
	then $(NEW_TL) gen $(TLGENFLAGS) --root . --custom-ext .lua.2 --output-dir _temp `cat _temp/list2` || extras/make.sh revert; \
	fi

newlist:
	@mkdir -p _temp/
	@rm -f _temp/list1
	@rm -f _temp/list1.1
	@rm -f _temp/list1.2

selfbuild: newlist build1 replace1 build2 combine
	extras/make.sh diff_1_and_2 || extras/make.sh revert

########################################
# Test suite:
########################################

suite:
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

combine:
	$(STABLE_TL) run extras/combine.tl

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
# force a recompile of the environment
	rm precompiler.lua

########################################
# Makefile administrivia
########################################

.PHONY: all build1 replace1 build2 selfbuild \
	suite bin binary cov revert cov cleantemp clean

