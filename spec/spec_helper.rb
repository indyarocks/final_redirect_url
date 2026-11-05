require 'bundler/setup'
require 'webmock/rspec'
require 'final_redirect_url'

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Disable all real network connections in the test suite.
  config.before(:suite) { WebMock.disable_net_connect! }
end
