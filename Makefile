# Build the Wayland worker and install everything into the user's home.
PREFIX  ?= $(HOME)/.local
CC      ?= cc
CFLAGS  ?= -O2
CFLAGS  += -Wall -Wextra -Werror -std=c11
PROTO    = protocol/wlr-virtual-pointer-unstable-v1.xml
GEN      = build/virtual-pointer-client.h build/virtual-pointer-protocol.c
WORKER   = build/autoclicker-worker

.PHONY: all test check install uninstall clean

all: $(WORKER)

build/virtual-pointer-client.h: $(PROTO)
	@mkdir -p build
	wayland-scanner client-header $< $@

build/virtual-pointer-protocol.c: $(PROTO)
	@mkdir -p build
	wayland-scanner private-code $< $@

$(WORKER): src/autoclicker.c $(GEN)
	$(CC) $(CFLAGS) -Ibuild src/autoclicker.c build/virtual-pointer-protocol.c \
	  $$(pkg-config --cflags --libs wayland-client) -o $@

test: $(WORKER)
	python3 -m unittest discover -s tests -v
	tests/test_worker.sh $(WORKER)
	tests/test_install.sh

check: test
	shellcheck bin/autoclicker install.sh uninstall.sh tests/*.sh

install: $(WORKER)
	PREFIX="$(PREFIX)" ./install.sh --no-build

uninstall:
	PREFIX="$(PREFIX)" ./uninstall.sh

clean:
	rm -rf build
