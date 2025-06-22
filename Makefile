LUA ?=

ifeq ($(OS), Windows_NT)
	BUSTED = busted.bat --suppress-pending --exclude-tags=unix
else
	BUSTED = busted --suppress-pending
endif

PRECOMPILED = teal/precompiled/default_env.lua
SOURCES = teal/debug.tl teal/attributes.tl teal/errors.tl teal/lexer.tl teal/util.tl teal/embed/prelude.tl teal/embed/stdlib.tl teal/types.tl teal/facts.tl teal/parser.tl teal/traversal.tl teal/gen/lua_generator.tl teal/variables.tl teal/type_reporter.tl teal/type_errors.tl teal/environment.tl teal/checker/checker.tl teal/checker/type_checker.tl teal/checker/file_checker.tl teal/checker/string_checker.tl teal/checker/require_file.tl tl.tl

all: selfbuild suite

precompiler.lua: precompiler.tl
	$(LUA) ./tl gen $< -o $@ || { rm $@; exit 1; }

teal/precompiled/default_env.lua: precompiler.lua teal/embed/prelude.tl teal/embed/stdlib.tl tl.tl
	lua precompiler.lua > teal/precompiled/default_env.lua || { rm $@; exit 1; }

_temp/%.lua.bak: %.lua
	cp $< $@

_temp/%.lua.1: %.tl $(PRECOMPILED)
	mkdir -p `dirname $@`
	$(LUA) ./tl gen --check --gen-target=5.1 $< -o $@ || { rm $@; exit 1; }

_temp/%.lua.2: %.tl _temp/%.lua.1 $(PRECOMPILED)
	$(LUA) ./tl gen --check --gen-target=5.1 $< -o $@ || { for bak in $$(find _temp -name '*.lua.bak'); do cp $$bak `echo "$$bak" | sed 's,^_temp/\(.*\).bak$$,\1,'`; done; for l in `find _temp -name '*.lua.1'`; do mv $$l $$l.err; done; exit 1 ;}

build1: $(addprefix _temp/,$(addsuffix .lua.1,$(basename $(SOURCES))))

replace1:
	for f in $$(find _temp -name '*.lua.1'); do l=`echo "$$f" | sed 's,^_temp/\(.*\).1$$,\1,'`; cp $$l _temp/$$l.bak; cp $$f $$l; done

build2: $(addprefix _temp/,$(addsuffix .lua.2,$(basename $(SOURCES))))

selfbuild: build1 replace1 build2
	for f in $$(find _temp -name '*.lua.1'); do l=`echo "$$f" | sed 's,^_temp/\(.*\).1$$,\1,'`; diff $$f _temp/$$l.2 || { for bak in $$(find _temp -name '*.lua.bak'); do cp $$bak `echo "$$bak" | sed 's,^_temp/\(.*\).bak$$,\1,'`; done; for l in `find . -name '*.lua.1'`; do mv $$l _temp/$$l.err; done; exit 1 ;}; done

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
