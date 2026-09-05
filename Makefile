# Cat Protector - common developer tasks.

APP      := build/Cat Protector.app
INSTALL  := /Applications

.PHONY: all build app universal dist icon test run install clean

all: app

## Compile a debug build (no bundle).
build:
	swift build

## Build the release .app bundle into ./build.
app:
	Scripts/build-app.sh

## Build a universal (Apple silicon + Intel) .app bundle.
universal:
	UNIVERSAL=1 Scripts/build-app.sh

## Zip the built app for distribution (build/Cat-Protector.zip).
dist:
	cd build && ditto -c -k --keepParent "Cat Protector.app" Cat-Protector.zip
	@echo "Wrote build/Cat-Protector.zip"

## Regenerate Resources/AppIcon.icns.
icon:
	swift Scripts/make-icon.swift

## Run the unit tests.
test:
	swift test

## Build the app bundle and launch it.
run: app
	open "$(APP)"

## Build and copy the app into /Applications.
install: app
	rm -rf "$(INSTALL)/Cat Protector.app"
	cp -R "$(APP)" "$(INSTALL)/"
	@echo "Installed to $(INSTALL)/Cat Protector.app"

clean:
	rm -rf .build build
