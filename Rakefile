require 'rake/testtask'
require 'rubygems/package_task'

Rake::TestTask.new do |t|
  t.libs << 'lib'
  t.test_files = FileList.new('test/**/*_test.rb')
end

s = Gem::Specification.load("sidekiq_workflows.gemspec")

Gem::PackageTask.new s do end

task default: %w[test]
