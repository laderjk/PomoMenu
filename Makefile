SHELL := /bin/bash
PROJECT := PomoMenu.xcodeproj
SCHEME  := PomoMenu
DEST    := platform=macOS
BUILD_DIR := build

.PHONY: all run build test release dmg clean open

all: build

## Build the Debug app and launch it.
run:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination '$(DEST)' -derivedDataPath $(BUILD_DIR)/DerivedData build
	@APP="$(BUILD_DIR)/DerivedData/Build/Products/Debug/PomoMenu.app"; \
	  if [ ! -d "$$APP" ]; then echo "Build succeeded but $$APP missing"; exit 1; fi; \
	  echo "→ Launching $$APP"; \
	  open "$$APP"

## Debug build.
build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination '$(DEST)' build

## Run the full test suite.
test:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination '$(DEST)' test

## Produce build/PomoMenu.app (Release, ad-hoc signed).
release:
	bash scripts/build-release.sh

## Produce build/PomoMenu-<version>.dmg from build/PomoMenu.app (invokes release if needed).
dmg: release
	bash scripts/make-dmg.sh

## Wipe build artifacts.
clean:
	rm -rf $(BUILD_DIR)

## Open the project in Xcode.
open:
	open $(PROJECT)
