INSTALL_DIR ?= /usr/local/bin
BINARY = tdd-guard-swift-test

.PHONY: build install uninstall clean

build:
	cd reporter && swift build -c release

install: build
	cp reporter/.build/release/$(BINARY) $(INSTALL_DIR)/$(BINARY)
	@echo "Installed $(BINARY) to $(INSTALL_DIR)/$(BINARY)"

uninstall:
	rm -f $(INSTALL_DIR)/$(BINARY)
	@echo "Removed $(BINARY)"

clean:
	cd reporter && swift package clean
