set shell := ["zsh", "-cu"]

default: verify

format:
    swift format format --in-place --recursive Sources Tests scripts Package.swift

lint:
    swift format lint --strict --recursive Sources Tests scripts Package.swift

build:
    swift scripts/bundle-app.swift debug

build-release:
    swift scripts/bundle-app.swift release

clean:
    swift package reset

run: build
    open .build/apps/debug/Turnstile.app

run-release: build-release
    open .build/apps/release/Turnstile.app

install: build-release
    rsync --archive --delete --extended-attributes .build/apps/release/Turnstile.app/ "$HOME/Applications/Turnstile.app/"

test:
    swift test --enable-code-coverage

verify: lint test build
