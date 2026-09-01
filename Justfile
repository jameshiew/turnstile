set shell := ["zsh", "-cu"]

default: verify

generate:
    xcodegen generate

format:
    xcrun swift format format --in-place --recursive Sources Tests scripts

lint:
    xcrun swift format lint --strict --recursive Sources Tests scripts

build: generate
    xcodebuild -project Turnstile.xcodeproj -scheme Turnstile -configuration Debug -derivedDataPath .build/DerivedData build

build-release: generate
    xcodebuild -project Turnstile.xcodeproj -scheme Turnstile -configuration Release -derivedDataPath .build/DerivedData build

run: build
    open .build/DerivedData/Build/Products/Debug/Turnstile.app

run-release: build-release
    open .build/DerivedData/Build/Products/Release/Turnstile.app

install: build-release
    rsync --archive --delete --extended-attributes .build/DerivedData/Build/Products/Release/Turnstile.app/ "$HOME/Applications/Turnstile.app/"

test: generate
    xcodebuild -project Turnstile.xcodeproj -scheme Turnstile -configuration Debug -derivedDataPath .build/DerivedData test

verify: lint test
