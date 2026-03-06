ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module Rails
  module LineFiltering
    def run(*args)
      if args.length == 3
        super(*args)
      else
        reporter = args[0]
        options = args[1] || {}
        options = options.merge(filter: Rails::TestUnit::Runner.compose_filter(self, options[:filter]))
        super(reporter, options)
      end
    end

    def run_suite(reporter, options = {})
      options = options.merge(filter: Rails::TestUnit::Runner.compose_filter(self, options[:filter]))
      super(reporter, options)
    end
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # parallelize(workers: :number_of_processors, with: :threads)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all if ENV["LOAD_ALL_FIXTURES"] == "true"

    # Add more helper methods to be used by all tests here...
  end
end
