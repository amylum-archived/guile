PACKAGE = guile
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz
PATH_FLAGS = --prefix=/usr --infodir=/tmp/trash
CONF_FLAGS =
CFLAGS =

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags | sed 's/v//')
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

LIBTOOL_VERSION = 2.4.6-2
LIBTOOL_URL = https://github.com/amylum/libtool/releases/download/$(LIBTOOL_VERSION)/libtool.tar.gz
LIBTOOL_TAR = /tmp/libtool.tar.gz
LIBTOOL_DIR = /tmp/libtool
LIBTOOL_PATH = --with-libltdl-prefix=$(LIBTOOL_DIR)/usr

GMP_VERSION = 6.1.0-3
GMP_URL = https://github.com/amylum/gmp/releases/download/$(GMP_VERSION)/gmp.tar.gz
GMP_TAR = /tmp/gmp.tar.gz
GMP_DIR = /tmp/gmp
GMP_PATH = --with-libgmp-prefix=$(GMP_DIR)/usr

LIBUNISTRING_VERSION = 0.9.6-2
LIBUNISTRING_URL = https://github.com/amylum/libunistring/releases/download/$(LIBUNISTRING_VERSION)/libunistring.tar.gz
LIBUNISTRING_TAR = /tmp/libunistring.tar.gz
LIBUNISTRING_DIR = /tmp/libunistring
LIBUNISTRING_PATH = --with-libunistring-prefix=$(LIBUNISTRING_DIR)/usr

GC_VERSION = 7.4.2-3
GC_URL = https://github.com/amylum/gc/releases/download/$(GC_VERSION)/gc.tar.gz
GC_TAR = /tmp/gc.tar.gz
GC_DIR = /tmp/gc
GC_PATH = -I$(GC_DIR)/usr/include -L$(GC_DIR)/usr/lib -lgc

LIBATOMIC_OPS_VERSION = 7.4.2-2
LIBATOMIC_OPS_URL = https://github.com/amylum/libatomic_ops/releases/download/$(LIBATOMIC_OPS_VERSION)/libatomic_ops.tar.gz
LIBATOMIC_OPS_TAR = /tmp/libatomic_ops.tar.gz
LIBATOMIC_OPS_DIR = /tmp/libatomic_ops
LIBATOMIC_OPS_PATH = -I$(LIBATOMIC_OPS_DIR)/usr/include -L$(LIBATOMIC_OPS_DIR)/usr/lib

LIBFFI_VERSION = 3.2.1-3
LIBFFI_URL = https://github.com/amylum/libffi/releases/download/$(LIBFFI_VERSION)/libffi.tar.gz
LIBFFI_TAR = /tmp/libffi.tar.gz
LIBFFI_DIR = /tmp/libffi
LIBFFI_PATH = -I$(LIBFFI_DIR)/usr/lib/libffi-$(word 1, $(subst -, ,$(LIBFFI_VERSION)))/include -L$(LIBFFI_DIR)/usr/lib -lffi

.PHONY : default submodule deps manual container deps build version push local

default: submodule container

submodule:
	git submodule update --init

manual: submodule
	./meta/launch /bin/bash || true

container:
	./meta/launch

deps:
	rm -rf $(LIBTOOL_DIR) $(LIBTOOL_TAR)
	mkdir $(LIBTOOL_DIR)
	curl -sLo $(LIBTOOL_TAR) $(LIBTOOL_URL)
	tar -x -C $(LIBTOOL_DIR) -f $(LIBTOOL_TAR)
	rm -rf $(GMP_DIR) $(GMP_TAR)
	mkdir $(GMP_DIR)
	curl -sLo $(GMP_TAR) $(GMP_URL)
	tar -x -C $(GMP_DIR) -f $(GMP_TAR)
	rm -rf $(LIBUNISTRING_DIR) $(LIBUNISTRING_TAR)
	mkdir $(LIBUNISTRING_DIR)
	curl -sLo $(LIBUNISTRING_TAR) $(LIBUNISTRING_URL)
	tar -x -C $(LIBUNISTRING_DIR) -f $(LIBUNISTRING_TAR)
	rm -rf $(GC_DIR) $(GC_TAR)
	mkdir $(GC_DIR)
	curl -sLo $(GC_TAR) $(GC_URL)
	tar -x -C $(GC_DIR) -f $(GC_TAR)
	rm /tmp/gc/usr/lib/libgc.la
	rm -rf $(LIBATOMIC_OPS_DIR) $(LIBATOMIC_OPS_TAR)
	mkdir $(LIBATOMIC_OPS_DIR)
	curl -sLo $(LIBATOMIC_OPS_TAR) $(LIBATOMIC_OPS_URL)
	tar -x -C $(LIBATOMIC_OPS_DIR) -f $(LIBATOMIC_OPS_TAR)
	rm -rf $(LIBFFI_DIR) $(LIBFFI_TAR)
	mkdir $(LIBFFI_DIR)
	curl -sLo $(LIBFFI_TAR) $(LIBFFI_URL)
	tar -x -C $(LIBFFI_DIR) -f $(LIBFFI_TAR)

build: submodule deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	sed -i 's/strcoll_l/strtol_l/g' $(BUILD_DIR)/configure.ac
	echo $(PACKAGE_VERSION) > $(BUILD_DIR)/.tarball-version
	cd $(BUILD_DIR) && autoreconf -i
	cd $(BUILD_DIR) && CC=musl-gcc CFLAGS='$(CFLAGS) $(LIBATOMIC_OPS_PATH)' BDW_GC_CFLAGS='$(GC_PATH)' BDW_GC_LIBS='$(GC_PATH)' LIBFFI_CFLAGS='$(LIBFFI_PATH)' LIBFFI_LIBS='$(LIBFFI_PATH)' ./configure $(PATH_FLAGS) $(CONF_FLAGS) $(LIBTOOL_PATH) $(GMP_PATH) $(LIBUNISTRING_PATH)
	cd $(BUILD_DIR) && make DESTDIR=$(RELEASE_DIR) install
	rm -rf $(RELEASE_DIR)/tmp
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp $(BUILD_DIR)/COPYING $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	@sleep 3
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

