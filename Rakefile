# frozen_string_literal: true

require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new
Rake.add_rakelib 'lib/tasks'

task default: %i[rubocop spec]
