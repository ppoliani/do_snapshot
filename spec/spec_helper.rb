# $LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'coveralls'
Coveralls.wear! do
  add_filter '/spec/*'
  add_filter '/bin/*'
  add_filter '/lib/*/mail.rb'
  add_filter '/lib/*/version.rb'
  add_filter '/lib/*/core_ext/hash.rb'
  add_filter '/lib/*/hash.rb'
end

require 'do_snapshot/cli'
require 'webmock/rspec'
require 'digitalocean'
require 'shared/api_helpers'
require 'shared/uri_helpers'
require 'shared/environment'
require 'shared/uri_helpers'
require 'do_snapshot/core_ext/hash'

RSpec.configure do |config|
  # Pretty tests
  config.color = true

  config.order = :random
  config.mock_with :rspec do |mocks|
    mocks.verify_doubled_constant_names = true
  end
end

def project_path
  File.expand_path('../..', __FILE__)
end

def fixture(fixture_name)
  File.new(project_path + "/spec/fixtures/#{fixture_name}.json")
end

Dir[File.expand_path(File.join(File.dirname(__FILE__), 'support', '**', '*.rb'))].each { |f| require f }