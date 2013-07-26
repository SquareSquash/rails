# Copyright 2013 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'squash/ruby'
if defined?(Rails)
  require 'squash/ruby/controller_methods'
  require 'squash/ruby/railtie'
  Squash::Ruby::TOP_LEVEL_USER_DATA.concat %w( environment root xhr headers
                                               request_method schema host port
                                               path query controller action
                                               params session flash cookies )
end

module Squash::Ruby
  CONFIGURATION_DEFAULTS[:deploy_path] = "/api/1.0/deploy"

  # @private
  def self.failsafe_log(tag, message)
    logger = Rails.respond_to?(:logger) ? Rails.logger : RAILS_DEFAULT_LOGGER
    if (logger.respond_to?(:tagged))
      logger.tagged(tag) { logger.error message }
    else
      logger.error "[#{tag}]\t#{message}"
    end
  rescue Object => err
    $stderr.puts "Couldn't write to failsafe log (#{err.to_s}); writing to stderr instead."
    $stderr.puts "#{Time.now.to_s}\t[#{tag}]\t#{message}"
  end

  private

  def self.client_name() 'rails' end

  # Unwrap ActiveRecord::StatementInvalid, since it's "special"
  def self.exception_info_hash_with_rails(exception, *other_args)
    hsh = exception_info_hash_without_rails(exception, *other_args)

    if defined?(ActiveRecord::StatementInvalid) && exception.kind_of?(ActiveRecord::StatementInvalid)
      if hsh['message'] =~ /^([A-Za-z0-9:_]+?): /
        hsh['message'].sub! /^([A-Za-z0-9:_]+?): /, ''
        hsh['class_name'] = $1
      end
    end

    hsh
  end

  class << self
    alias_method_chain :exception_info_hash, :rails
  end
end
