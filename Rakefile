# frozen_string_literal: true

require 'rake/extensiontask'
require 'rake/testtask'

# Build the native extension
Rake::ExtensionTask.new('mquickjs_native') do |ext|
  ext.lib_dir = 'lib/mquickjs'
  ext.ext_dir = 'ext/mquickjs'
end

# Test task
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
end

# Clean task
task :clean do
  sh 'cd ext/mquickjs && make clean' if File.exist?('ext/mquickjs/Makefile')
  rm_f 'lib/mquickjs/mquickjs_native.so'
  rm_f Dir.glob('ext/mquickjs/*.o')
  rm_f 'ext/mquickjs/Makefile'
end

# Benchmark task
desc 'Run benchmarks'
task :benchmark => :compile do
  ruby 'benchmark/runner.rb'
end

# Individual benchmark tasks
namespace :benchmark do
  desc 'Run simple operations benchmark'
  task :simple => :compile do
    ruby 'benchmark/simple_operations.rb'
  end

  desc 'Run computation benchmark'
  task :computation => :compile do
    ruby 'benchmark/computation.rb'
  end

  desc 'Run JSON operations benchmark'
  task :json => :compile do
    ruby 'benchmark/json_operations.rb'
  end

  desc 'Run array operations benchmark'
  task :array => :compile do
    ruby 'benchmark/array_operations.rb'
  end

  desc 'Run sandbox overhead benchmark'
  task :overhead => :compile do
    ruby 'benchmark/sandbox_overhead.rb'
  end

  desc 'Run memory limits benchmark'
  task :memory => :compile do
    ruby 'benchmark/memory_limits.rb'
  end

  desc 'Run console output benchmark'
  task :console => :compile do
    ruby 'benchmark/console_output.rb'
  end
end

# Fil-C memory-safe build tasks
# See https://fil-c.org/ for more information about fil-c
namespace :filc do
  desc 'Build MQuickJS C library with fil-c for memory safety'
  task :build do
    cd 'ext/mquickjs' do
      sh 'make -f Makefile.filc'
    end
  end

  desc 'Run memory safety tests with fil-c'
  task :test do
    cd 'ext/mquickjs' do
      sh 'make -f Makefile.filc test'
    end
  end

  desc 'Build Ruby extension with fil-c (requires FILC_PATH)'
  task :compile do
    cd 'ext/mquickjs' do
      ruby 'extconf_filc.rb'
      sh 'make'
    end
    cp 'ext/mquickjs/mquickjs_native.so', 'lib/mquickjs/' if File.exist?('ext/mquickjs/mquickjs_native.so')
  end

  desc 'Clean fil-c build artifacts'
  task :clean do
    cd 'ext/mquickjs' do
      sh 'make -f Makefile.filc clean' if File.exist?('Makefile.filc')
    end
  end

  desc 'Show fil-c build help'
  task :help do
    puts <<~HELP
      Fil-C Memory-Safe Build for MQuickJS
      =====================================

      Fil-C is a memory-safe C compiler that catches:
        - Buffer overflows
        - Use-after-free
        - Double free
        - Out-of-bounds access

      Available tasks:
        rake filc:build    - Build the C library with fil-c
        rake filc:test     - Run memory safety tests
        rake filc:compile  - Build Ruby extension with fil-c
        rake filc:clean    - Clean fil-c build artifacts

      Prerequisites:
        1. Install fil-c from https://fil-c.org/
        2. Set FILC_PATH environment variable (optional if in PATH)

      Example:
        FILC_PATH=/opt/fil-c/bin rake filc:test

      Note: fil-c builds are slower but provide runtime memory safety.
      Use for development, testing, and security-critical deployments.
    HELP
  end
end

# Default: clean, compile, test
task default: [:clean, :compile, :test]
