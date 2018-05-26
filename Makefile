PREFIX?=/usr/local
SWIFT_LIB_FILES = .build/release/libIBLinterKit.dylib .build/release/*.swiftmodule
C_LIB_DIRS = .build/release/CYaml.build

build:
		swift build --disable-sandbox -c release --static-swift-stdlib

clean_build:
		rm -rf .build
		make build

portable_zip: build
		rm -rf portable_iblinter
		mkdir portable_iblinter
		mkdir portable_iblinter/lib
		mkdir portable_iblinter/bin
		cp -f .build/release/iblinter portable_iblinter/bin
		cp -rf $(C_LIB_DIRS) $(SWIFT_LIB_FILES) "portable_iblinter/lib"
		cp -f LICENSE portable_iblinter
		zip -yr - portable_iblinter  > "./portable_iblinter.zip"
		rm -rf portable_iblinter

install: build
		mkdir -p "$(PREFIX)/bin"
		mkdir -p "$(PREFIX)/lib/iblinter"
		cp -f ".build/release/iblinter" "$(PREFIX)/bin/iblinter"
		cp -rf $(C_LIB_DIRS) $(SWIFT_LIB_FILES) "$(PREFIX)/lib/iblinter"

publish: clean_build
		brew update && brew bump-formula-pr --tag=$(shell git describe --tags) --revision=$(shell git rev-parse HEAD) iblinter
		pod trunk push IBLinter.podspec
