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
  # Disable automatic plugin loading to avoid conflicts with globally installed gems
  t.options = '--no-plugins'
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

# Default: clean, compile, test
task default: [:clean, :compile, :test]
