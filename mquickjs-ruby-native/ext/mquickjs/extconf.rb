# frozen_string_literal: true

require 'mkmf'

# Configuration
# Use current directory for mquickjs source files
MQUICKJS_DIR = File.expand_path('.', __dir__)

# Add mquickjs include directory
$INCFLAGS << " -I#{MQUICKJS_DIR}"

# Add mquickjs source directory to search path
$VPATH << MQUICKJS_DIR

# Check for required headers
unless find_header('mquickjs.h', MQUICKJS_DIR)
  abort "mquickjs.h not found in #{MQUICKJS_DIR}"
end

# Add compilation flags
$CFLAGS << ' -std=c99 -Wall -Wextra'

# Create Makefile
create_makefile('mquickjs/mquickjs_native')
