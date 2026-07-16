.PHONY: build test run app verify-app archive notarize release logo-assets clean

APP_NAME := Little Swan
EXECUTABLE_NAME := LittleSwan
MENUBAR_TEMPLATE_ICON := LittleSwanMenuBarTemplate.png
BUILD_CONFIG ?= release
APP_VERSION ?= $(shell tr -d '[:space:]' < VERSION)
BUILD_NUMBER ?= 1
GIT_COMMIT ?= $(shell git rev-parse HEAD 2>/dev/null || printf 'unknown')
GIT_COMMIT_DATE ?= $(shell git show -s --format=%cI HEAD 2>/dev/null || true)
GIT_DIRTY ?= $(shell test -z "$$(git status --porcelain 2>/dev/null)" && printf false || printf true)
ARCHS ?=
ARCH_FLAGS := $(foreach arch,$(ARCHS),--arch $(arch))
BIN_PATH = $(shell swift build -c $(BUILD_CONFIG) $(ARCH_FLAGS) --show-bin-path)
SIGNING_IDENTITY ?= -
NOTARY_PROFILE ?=
APP_DIR := $(APP_NAME).app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
DIST_DIR := dist
ARCHIVE_NAME := Little-Swan-$(APP_VERSION).zip
ARCHIVE_PATH := $(DIST_DIR)/$(ARCHIVE_NAME)

build:
	swift build -c $(BUILD_CONFIG) $(ARCH_FLAGS)

test:
	swift run LittleSwanSmokeTests

run:
	swift run $(EXECUTABLE_NAME)

app: build
	test -n "$(APP_VERSION)"
	rm -rf "$(APP_DIR)"
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	cp "$(BIN_PATH)/$(EXECUTABLE_NAME)" "$(MACOS_DIR)/$(EXECUTABLE_NAME)"
	cp Packaging/Info.plist "$(CONTENTS_DIR)/Info.plist"
	cp Design/LittleSwan.icns "$(RESOURCES_DIR)/LittleSwan.icns"
	cp Design/little-swan-menubar-template.png "$(RESOURCES_DIR)/$(MENUBAR_TEMPLATE_ICON)"
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(APP_VERSION)" "$(CONTENTS_DIR)/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD_NUMBER)" "$(CONTENTS_DIR)/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :LittleSwanGitCommit $(GIT_COMMIT)" "$(CONTENTS_DIR)/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :LittleSwanGitCommitDate $(GIT_COMMIT_DATE)" "$(CONTENTS_DIR)/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :LittleSwanGitDirty $(GIT_DIRTY)" "$(CONTENTS_DIR)/Info.plist"
	chmod +x "$(MACOS_DIR)/$(EXECUTABLE_NAME)"
	@if [ "$(SIGNING_IDENTITY)" = "-" ]; then \
		codesign --force --sign - "$(APP_DIR)"; \
	else \
		codesign --force --options runtime --timestamp --sign "$(SIGNING_IDENTITY)" "$(APP_DIR)"; \
	fi

verify-app:
	codesign --verify --deep --strict --verbose=2 "$(APP_DIR)"
	/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$(CONTENTS_DIR)/Info.plist" | grep -Fx "$(APP_VERSION)"
	/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$(CONTENTS_DIR)/Info.plist" | grep -Fx "$(BUILD_NUMBER)"
	/usr/libexec/PlistBuddy -c "Print :LittleSwanGitCommit" "$(CONTENTS_DIR)/Info.plist" | grep -Fx "$(GIT_COMMIT)"

archive: app verify-app
	mkdir -p "$(DIST_DIR)"
	rm -f "$(ARCHIVE_PATH)"
	ditto -c -k --sequesterRsrc --keepParent "$(APP_DIR)" "$(ARCHIVE_PATH)"
	shasum -a 256 "$(ARCHIVE_PATH)"

notarize: archive
	test "$(SIGNING_IDENTITY)" != "-"
	test -n "$(NOTARY_PROFILE)"
	xcrun notarytool submit "$(ARCHIVE_PATH)" --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple "$(APP_DIR)"
	xcrun stapler validate "$(APP_DIR)"
	codesign --verify --deep --strict --verbose=2 "$(APP_DIR)"
	spctl --assess --type execute --verbose=4 "$(APP_DIR)"
	rm -f "$(ARCHIVE_PATH)"
	ditto -c -k --sequesterRsrc --keepParent "$(APP_DIR)" "$(ARCHIVE_PATH)"
	shasum -a 256 "$(ARCHIVE_PATH)"

release: test archive

logo-assets:
	swift Design/generate_logo_assets.swift

clean:
	rm -rf .build "$(APP_DIR)" "$(DIST_DIR)"
