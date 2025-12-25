# Building mquickjs-ruby-native

## Build & Test

```bash
rake
```

All mquickjs source files are included in the repository - no separate checkout needed.

This will:
- Clean previous builds
- Compile the extension
- Run all tests

## Requirements

- Ruby development headers (`ruby-dev` or similar)
- C compiler (`gcc` or `clang`)
- `make`

### Install on Ubuntu/Debian:
```bash
sudo apt-get install ruby-dev build-essential
```

### Install on macOS:
```bash
xcode-select --install
```

## Troubleshooting

If tests crash, try:

```bash
rake clean
rake
```
