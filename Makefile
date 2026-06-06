.PHONY: build test run app logo-assets clean

APP_NAME := Little Swan
EXECUTABLE_NAME := LittleSwan
MENUBAR_TEMPLATE_ICON := LittleSwanMenuBarTemplate.png
BUILD_CONFIG ?= release
EXECUTABLE := .build/$(shell uname -m)-apple-macosx/$(BUILD_CONFIG)/$(EXECUTABLE_NAME)
APP_DIR := $(APP_NAME).app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources

build:
	swift build -c $(BUILD_CONFIG)

test:
	swift run LittleSwanSmokeTests

run:
	swift run $(EXECUTABLE_NAME)

app: build
	rm -rf "$(APP_DIR)"
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	cp "$(EXECUTABLE)" "$(MACOS_DIR)/$(EXECUTABLE_NAME)"
	cp Packaging/Info.plist "$(CONTENTS_DIR)/Info.plist"
	cp Design/LittleSwan.icns "$(RESOURCES_DIR)/LittleSwan.icns"
	cp Design/little-swan-menubar-template.png "$(RESOURCES_DIR)/$(MENUBAR_TEMPLATE_ICON)"
	chmod +x "$(MACOS_DIR)/$(EXECUTABLE_NAME)"
	codesign --force --sign - "$(APP_DIR)"

logo-assets:
	python3 Design/generate_logo_assets.py

clean:
	rm -rf .build "$(APP_DIR)"
