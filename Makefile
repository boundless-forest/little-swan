.PHONY: build test run app clean

APP_NAME := ExpressBridge
BUILD_CONFIG ?= release
EXECUTABLE := .build/$(shell uname -m)-apple-macosx/$(BUILD_CONFIG)/$(APP_NAME)
APP_DIR := $(APP_NAME).app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources

build:
	swift build -c $(BUILD_CONFIG)

test:
	swift run ExpressBridgeSmokeTests

run:
	swift run $(APP_NAME)

app: build
	rm -rf $(APP_DIR)
	mkdir -p $(MACOS_DIR) $(RESOURCES_DIR)
	cp $(EXECUTABLE) $(MACOS_DIR)/$(APP_NAME)
	cp Packaging/Info.plist $(CONTENTS_DIR)/Info.plist
	chmod +x $(MACOS_DIR)/$(APP_NAME)

clean:
	rm -rf .build $(APP_DIR)
