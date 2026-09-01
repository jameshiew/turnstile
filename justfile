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

test: generate
    xcodebuild -project Turnstile.xcodeproj -scheme Turnstile -configuration Debug -derivedDataPath .build/DerivedData test

verify: lint test
