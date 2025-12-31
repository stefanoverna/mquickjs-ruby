# Claude Code Development Guide

This file contains important information for Claude Code when working on this project.

## Environment Setup

Before running any tests or Ruby code that uses mquickjs, you must build the native extension:

```bash
# Navigate to the extension directory
cd ext/mquickjs

# Run extconf.rb to generate the Makefile
ruby extconf.rb

# Compile the extension
make

# Copy the compiled extension to the lib directory
cp mquickjs_native.so ../../lib/mquickjs/
```

Alternatively, if bundler is working:
```bash
bundle exec rake compile
```

### Troubleshooting

**"cannot load such file -- mquickjs/mquickjs_native"**
- This error means the native extension hasn't been built. Follow the setup steps above.

**Bundler errors with CGI class variable**
- If you encounter `uninitialized class variable @@accept_charset in #<Class CGI>`, try updating bundler or using the manual compilation approach above.

## Running Tests

After building the extension:

```bash
# Run all tests
ruby -Ilib test/run_all_tests.rb

# Run a specific test file
ruby -Ilib test/mquickjs_test.rb
ruby -Ilib test/javascript_api_limitations_test.rb
```

## Project Structure

- `ext/mquickjs/` - C extension source files
  - `mquickjs.c` - Main MicroQuickJS engine
  - `mquickjs_ext.c` - Ruby binding layer
  - `mqjs_stdlib.c` - JavaScript standard library definitions
- `lib/mquickjs/` - Ruby source files
- `test/` - Test files

## JavaScript API Limitations

MQuickJS uses MicroQuickJS, an extremely minimal JavaScript engine. Key limitations:

### Date
- **Only `Date.now()` works** - no Date constructor, no instance methods

### ES6+ Syntax Not Supported
- No `let`/`const` (use `var`)
- No arrow functions (use `function() {}`)
- No template literals (use string concatenation)
- No destructuring (access properties individually)
- No spread operator (use `concat`)
- No classes (use constructor functions with prototypes)
- No async/await, generators, Promises

### Missing Built-in Objects
- No Symbol, Map, Set, WeakMap, WeakSet
- No Promise, Proxy, Reflect

### Arrays
- **No holes allowed** - `[1, , 3]` is a syntax error
- Missing ES6+ methods: find, findIndex, includes, flat, from, of, at

### Strings
- Missing: includes, startsWith, endsWith, repeat, padStart, padEnd
- **Unicode case folding is ASCII-only** - toUpperCase/toLowerCase won't work correctly for non-ASCII characters

### Objects
- Missing: values, entries, assign, freeze, seal, fromEntries

### Global Functions
- Missing: encodeURI, decodeURI, encodeURIComponent, decodeURIComponent, btoa, atob

### Strict Mode
- Always enforced - undeclared variables throw ReferenceError
- `with` statement not supported
- Value boxing not supported (`new Number`, `new String`, `new Boolean`)

See `test/javascript_api_limitations_test.rb` for comprehensive documentation with examples.
