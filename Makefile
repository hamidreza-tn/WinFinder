PROJECT := WinFinder.xcodeproj
SCHEME := WinFinder
CONFIGURATION ?= Debug
DERIVED_DATA ?= .build
DESTINATION ?= platform=macOS
APP := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/WinFinder.app
INSTALL_DIR ?= /Applications
INSTALLED_APP := $(INSTALL_DIR)/WinFinder.app

# Release builds produce a universal binary (Apple Silicon + Intel); Debug
# builds stay on the host architecture for fast local iteration.
ifeq ($(CONFIGURATION),Release)
UNIVERSAL_SETTINGS := ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO
else
UNIVERSAL_SETTINGS :=
endif

.PHONY: validate test-logic build test archive install dmg clean

validate:
	./scripts/validate_project.py

# CODE_SIGN_IDENTITY=- ad-hoc signs the app: the binary is consistently
# identified by macOS (TCC permissions, SMAppService) instead of being
# completely unsigned. For distribution, sign with a Developer ID instead.
build: validate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) \
		-destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) \
		build CODE_SIGN_IDENTITY=- $(UNIVERSAL_SETTINGS)

# Offline verification: validation plus logic unit tests plus a local Xcode
# build, with no package fetches.
test-logic: validate
	./scripts/test_project.py

test: test-logic build

archive: validate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) \
		-archivePath $(DERIVED_DATA)/WinFinder.xcarchive \
		archive CODE_SIGN_IDENTITY=- $(UNIVERSAL_SETTINGS)

install: build
	@test -d "$(APP)"
	@test -d "$(INSTALL_DIR)" || (echo "Install directory does not exist: $(INSTALL_DIR)"; exit 1)
	-@pkill -x WinFinder 2>/dev/null || true
	rm -rf "$(INSTALLED_APP)"
	ditto "$(APP)" "$(INSTALLED_APP)"

# Drag-to-Install DMG with the branded background. Requires the background
# artwork (scripts/dmg/background.png); regenerate it with
# `swift scripts/make_dmg_background.swift scripts/dmg/background.png`.
dmg: CONFIGURATION = Release
dmg: build
	bash scripts/build_dmg.sh "$(APP)"

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED_DATA) clean
