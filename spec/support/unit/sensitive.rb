# rubocop:disable all
# This file is a direct copy of sensitive.rb file from rspec-puppet
# There is a problem with the way that bundler is downloading version 2.7.10
# of rspec-puppet that is causing that file to be missing from the gem you get
# in your bundle. Without this file it is difficult to creat Sensitive datatype
# values to give to the Sensitive parameters in the classes in this module for
# unit testing.
# Hopefully soon, when the bug in rspec-puppet is fixed, we can remove this file
# and directly load the gem's copy. In the meantime, this file is here to allow
# unit testing of our classes.
# https://github.com/rodjek/rspec-puppet/blob/93ea7f3cf8396ad79c1d45a125ae020dede4295e/lib/rspec-puppet/sensitive.rb
module RSpec::Puppet
  if defined?(::Puppet::Pops::Types::PSensitiveType::Sensitive)
    # A wrapper representing Sensitive data type, eg. in class params.
    class Sensitive < ::Puppet::Pops::Types::PSensitiveType::Sensitive
      # Create a new Sensitive object
      # @param [Object] value to wrap
      def initialize(value)
        @value = value
      end

      # @return the wrapped value
      def unwrap
        @value
      end

      # @return true
      def sensitive?
        true
      end

      # @return inspect of the wrapped value, inside Sensitive()
      def inspect
        "Sensitive(#{@value.inspect})"
      end

      # Check for equality with another value.
      # If compared to Puppet Sensitive type, it compares the wrapped values.

      # @param other [#unwrap, Object] value to compare to
      def == other
        if other.respond_to? :unwrap
          return unwrap == other.unwrap
        else
          super
        end
      end
    end
  else
    #:nocov:
    class Sensitive
      def initialize(value)
        raise 'The use of the Sensitive data type is not supported by this Puppet version'
      end
    end
    #:nocov:
  end
end
