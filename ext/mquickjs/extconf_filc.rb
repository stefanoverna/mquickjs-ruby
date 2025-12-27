# frozen_string_literal: true

# Fil-C build configuration for MQuickJS
# This builds the extension with fil-c for memory safety
#
# Usage:
#   FILC_HOME=/path/to/filc-0.677-linux-x86_64 ruby extconf_filc.rb
#   make
#
# Prerequisites:
#   - fil-c installed (https://fil-c.org/)
#   - FILC_HOME environment variable set to the extracted fil-c directory

require 'mkmf'
require 'fileutils'

# Configuration
MQUICKJS_DIR = File.expand_path('.', __dir__)
FILC_HOME = ENV['FILC_HOME']

# Determine fil-c compiler path
filc_cc = if FILC_HOME && !FILC_HOME.empty?
  File.join(FILC_HOME, 'build', 'bin', 'clang')
else
  # Try finding filc-clang in PATH
  `which filc-clang 2>/dev/null`.strip
end

# Verify fil-c is available
if filc_cc.empty? || !File.executable?(filc_cc)
  abort <<~ERROR
    fil-c compiler not found!

    Please install fil-c from https://fil-c.org/:

      1. Download: curl -LO https://github.com/pizlonator/fil-c/releases/download/v0.677/filc-0.677-linux-x86_64.tar.xz
      2. Extract:  tar xf filc-0.677-linux-x86_64.tar.xz
      3. Setup:    cd filc-0.677-linux-x86_64 && ./setup.sh
      4. Build:    FILC_HOME=/path/to/filc-0.677-linux-x86_64 ruby extconf_filc.rb

    Example:
      FILC_HOME=/tmp/filc-0.677-linux-x86_64 ruby extconf_filc.rb
  ERROR
end

puts "Using fil-c compiler: #{filc_cc}"

# Step 1: Generate mqjs_stdlib.h using the HOST compiler (not fil-c)
# The stdlib generator is a build tool, not the runtime, so it doesn't
# need memory safety instrumentation
stdlib_header = File.join(MQUICKJS_DIR, 'mqjs_stdlib.h')
stdlib_generator_src = File.join(MQUICKJS_DIR, 'mqjs_stdlib.c')

if File.exist?(stdlib_generator_src)
  puts "Generating mqjs_stdlib.h (using host compiler)..."

  generator_exe = File.join(MQUICKJS_DIR, 'mqjs_stdlib_gen')
  generator_sources = %w[mqjs_stdlib.c mquickjs_build.c cutils.c].map { |f| File.join(MQUICKJS_DIR, f) }

  # Use host compiler for the generator (not fil-c)
  host_cc = ENV['HOST_CC'] || 'cc'
  cflags = '-std=c99 -O0 -D_POSIX_C_SOURCE=200809L -I' + MQUICKJS_DIR

  compile_cmd = "#{host_cc} #{cflags} -o #{generator_exe} #{generator_sources.join(' ')} -lm"
  puts compile_cmd

  unless system(compile_cmd)
    abort "Failed to compile stdlib generator"
  end

  generate_cmd = "#{generator_exe} -m64 > #{stdlib_header}"
  puts generate_cmd

  unless system(generate_cmd)
    abort "Failed to generate mqjs_stdlib.h"
  end

  FileUtils.rm_f(generator_exe)
  puts "Generated #{stdlib_header}"
end

# Step 2: Configure the build to use fil-c
# Override the C compiler
RbConfig::MAKEFILE_CONFIG['CC'] = filc_cc
RbConfig::CONFIG['CC'] = filc_cc

# Add mquickjs include directory
$INCFLAGS << " -I#{MQUICKJS_DIR}"

# Add mquickjs source directory to search path
$VPATH << MQUICKJS_DIR

# Check for required headers
unless find_header('mquickjs.h', MQUICKJS_DIR)
  abort "mquickjs.h not found in #{MQUICKJS_DIR}"
end

# Fil-c compatible compilation flags
# Note: fil-c may not support all gcc/clang flags
$CFLAGS << ' -std=c99'

# Fil-c specific: disable optimizations that might interfere with safety checks
# and enable maximum safety
$CFLAGS << ' -O0' # fil-c works best without aggressive optimizations

# Create Makefile with fil-c as the compiler
create_makefile('mquickjs/mquickjs_native')

# Post-process Makefile to ensure fil-c is used
makefile_path = File.join(MQUICKJS_DIR, 'Makefile')
if File.exist?(makefile_path)
  content = File.read(makefile_path)

  # Ensure CC is set to fil-c
  content.gsub!(/^CC\s*=.*$/, "CC = #{filc_cc}")

  # Add a comment indicating this is a fil-c build
  header = <<~HEADER
    # Fil-C Memory-Safe Build
    # This Makefile was generated for building with fil-c
    # for memory safety instrumentation.
    #
    # Fil-C catches memory safety violations at runtime:
    # - Buffer overflows
    # - Use-after-free
    # - Double free
    # - Out-of-bounds access
    #
    # See https://fil-c.org/ for more information.

  HEADER

  content = header + content

  File.write(makefile_path, content)
  puts "\nMakefile configured for fil-c build"
  puts "Run 'make' to build the memory-safe extension"
end
