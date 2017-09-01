CDP_NAME=$(shell cat ABOUT | grep "^Name" | sed "s/.*:\ *//")
CDP_FULL_NAME=$(shell cat ABOUT | grep "^FullName" | sed "s/.*:\ *//")
CDP_PACKAGE_NAME=$(shell cat ABOUT | grep "^PackageName" | sed "s/.*:\ *//")
CDP_VERSION=$(shell cat ABOUT | grep "^Version" | sed "s/.*:\ *//")
CDP_DIST_NAME=$(CDP_PACKAGE_NAME)-$(CDP_VERSION)


all: help

help:
	@printf "Makefile of $(CDP_DIST_NAME)\n"
	@printf "Usage: make build|clean|dist|dist-clean\n"

deps:
	make -C lib

deps-clean:
	make -C lib clean


compile: init
	make -C build/src

init: clean deps
	mkdir -p build
	cp -r src lib build/

clean:
	rm -rf build/src build/lib

build: compile
	mkdir -p build/$(CDP_DIST_NAME)
	cp -f build/src/hadoop-ctl build/$(CDP_DIST_NAME)/
	cp -f build/src/install-cdp-hadoop build/$(CDP_DIST_NAME)/
	cp -f build/src/download-packages build/$(CDP_DIST_NAME)/
	mkdir -p build/$(CDP_DIST_NAME)/packages
	cp -f packages/.packages.ini.dist build/$(CDP_DIST_NAME)/packages/.packages.ini
	cp -rf etc build/$(CDP_DIST_NAME)/

dist: build
	bash build/src/download-packages build/$(CDP_DIST_NAME)/packages

dist-clean: clean deps-clean
	rm -rf build
