# Claude Code Project Guide

This document contains essential information for working with the mquickjs-ruby project efficiently.

## Quick Start

This is a Ruby gem that provides JavaScript execution via MicroQuickJS. The project uses RuboCop for linting and Minitest for testing.

## Important Setup Notes

### Bundler Issues
- Running `bundle install` may fail due to running as root or bundler version issues
- **Solution**: Gems are already installed globally in the system. Use direct paths to executables instead.

### RuboCop Linting

RuboCop is already installed globally. To run linting:

```bash
# Run linting check
/opt/rbenv/versions/3.3.6/lib/ruby/gems/3.3.0/gems/rubocop-1.82.1/exe/rubocop

# Run with auto-correct
/opt/rbenv/versions/3.3.6/lib/ruby/gems/3.3.0/gems/rubocop-1.82.1/exe/rubocop --autocorrect-all
```

**Current Status**: The codebase is clean with no linting errors (as of commit bf2f359).

### Project Structure

```
.
├── lib/mquickjs/          # Ruby source files
│   ├── errors.rb          # Exception classes (excluded from OptionalBooleanParameter cop)
│   ├── version.rb         # Gem version
│   └── *.rb               # Other Ruby files
├── ext/mquickjs/          # C extension code
├── test/                  # Minitest tests
├── .rubocop.yml           # RuboCop configuration
├── Rakefile               # Rake tasks
└── Gemfile                # Dependencies
```

### Key Configuration Files

- **.rubocop.yml**: Linting rules
  - Uses double quotes for strings
  - Max line length: 120
  - Metrics disabled
  - Excludes: vendor/, ext/, tmp/, benchmark/
  - Special exclusion for errors.rb (OptionalBooleanParameter cop)

### Common Tasks

```bash
# Run tests
rake test

# Run linting (if rake/bundler works)
rake rubocop

# Build the native extension
rake compile

# Clean build artifacts
rake clean

# Default task (clean, compile, test)
rake
```

### Dependencies

Development dependencies (from Gemfile):
- bundler ~> 2.0
- minitest ~> 5.0
- minitest-reporters ~> 1.5
- rake ~> 13.0
- rake-compiler ~> 1.2
- rubocop ~> 1.50
- rubocop-minitest ~> 0.31
- rubocop-rake ~> 0.6

## Recent Work

- Linting was previously fixed in commit a4023a8
- Console output was added to all exception types
- JavaScriptError was renamed to JavascriptError (bf2f359)
- errors.rb was excluded from OptionalBooleanParameter cop (410e349)

## Known Issues

1. Bundle install fails with CGI class variable error - use globally installed gems instead
2. Running as root causes bundler warnings - this is expected in the current environment

## Tips for Future Sessions

1. Don't waste time trying to fix bundler - gems are already installed globally
2. Use the full path to rubocop executable shown above
3. The codebase is already lint-clean, so just verify with rubocop before claiming there are issues
4. The native extension is in ext/mquickjs/ and requires compilation with `rake compile`
5. Tests can be run directly if rake doesn't work: `ruby -Ilib:test test/[test_file].rb`
