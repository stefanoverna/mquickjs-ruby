# mquickjs-ruby-native Quick Start

## Build

```bash
rake
```

## Usage

Pass data directly to your JavaScript code:

```ruby
require 'mquickjs'

sandbox = MQuickJS::Sandbox.new

# Set variables
sandbox.set_variable("user", { name: "Alice", age: 30 })
sandbox.set_variable("items", [1, 2, 3, 4, 5])

# Use them in JavaScript
result = sandbox.eval("user.name + ' is ' + user.age")
# => "Alice is 30"

result = sandbox.eval("items.reduce((sum, n) => sum + n, 0)")
# => 15
```

## Supported Types

- Primitives: `nil`, `true`, `false`, integers, floats, strings, symbols
- Arrays (including nested)
- Hashes (including nested)

## More Examples

See [test/set_variable_test.rb](test/set_variable_test.rb) for comprehensive usage examples.
