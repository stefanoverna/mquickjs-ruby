# frozen_string_literal: true

require 'mkmf'
require 'fileutils'

# Configuration
MQUICKJS_DIR = File.expand_path('.', __dir__)

# Step 1: Generate mqjs_stdlib.h if needed
stdlib_header = File.join(MQUICKJS_DIR, 'mqjs_stdlib.h')
stdlib_generator_src = File.join(MQUICKJS_DIR, 'mqjs_stdlib.c')

if File.exist?(stdlib_generator_src)
  puts "Generating mqjs_stdlib.h..."

  # Compile the stdlib generator
  generator_exe = File.join(MQUICKJS_DIR, 'mqjs_stdlib_gen')

  # Source files for the generator
  generator_sources = %w[mqjs_stdlib.c mquickjs_build.c cutils.c].map { |f| File.join(MQUICKJS_DIR, f) }

  # Use the host compiler to build the generator
  cc = ENV['CC'] || 'cc'
  cflags = '-std=c99 -O0 -D_POSIX_C_SOURCE=200809L -I' + MQUICKJS_DIR

  compile_cmd = "#{cc} #{cflags} -o #{generator_exe} #{generator_sources.join(' ')} -lm"
  puts compile_cmd

  unless system(compile_cmd)
    abort "Failed to compile stdlib generator"
  end

  # Run the generator to create the header (use -m64 for 64-bit pointers)
  generate_cmd = "#{generator_exe} -m64 > #{stdlib_header}"
  puts generate_cmd

  unless system(generate_cmd)
    abort "Failed to generate mqjs_stdlib.h"
  end

  # Clean up generator executable
  FileUtils.rm_f(generator_exe)

  puts "Generated #{stdlib_header}"
end

# Step 2: Build the Ruby extension

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
