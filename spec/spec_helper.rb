require 'rspec'
require 'traject'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
# Blacklight, again, make sure we're looking in the right place for em.
# Relative to HERE, NOT to Rails.root, which is off somewhere else.
Dir[Pathname.new(File.expand_path('support/**/*.rb', __FILE__))].each { |f| require f }

def file_fixture(fixture_name)
  file_fixture_path = File.join(__dir__, 'fixtures', 'files')
  path = Pathname.new(File.join(file_fixture_path, fixture_name))
  if path.exist?
    path
  else
    msg = "the directory '%s' does not contain a file named '%s'"
    raise ArgumentError, msg % [file_fixture_path, fixture_name]
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.shared_context_metadata_behavior = :apply_to_host_groups
end
