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

require 'logger'
require 'bundler'
Bundler.require :default, :development
require 'active_support/core_ext/object'
require 'active_support/core_ext/array'
require 'active_support/core_ext/module'

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')
$LOAD_PATH.unshift File.dirname(__FILE__)

require 'action_controller'
require 'active_record'
require 'active_record/base'

# Fake Rails-in-a-box
Rails = OpenStruct.new(:env => 'RAILS_ENV', :root => 'RAILS_ROOT') unless defined?(Rails)

module Railsish
  def request
    @request ||= OpenStruct.new(
        :xhr?                => true,
        :headers             => { 'SOME' => 'Headers' },
        :request_method      => :get,
        :protocol            => 'https://',
        :host                => 'www.example.com',
        :port                => 443,
        :path                => '/example',
        :query_string        => 'some=example&here=also',
        :filtered_parameters => { 'some' => 'params' })
  end

  def session()
    { 'some' => 'session' }
  end

  def flash
    fl             = if defined?(ActionDispatch)
                       ActionDispatch::Flash::FlashHash.new
                     else
                       ActionController::Flash::FlashHash.new
                     end
    fl[:some]      = 'hash'
    fl.now[:other] = 'key'
    fl
  end

  def cookies
    jar = Object.new
    jar.send :instance_variable_set, :@cookies, {'some' => 'cookies'}
    jar
  end

  def controller_name() 'controller_name' end
  def action_name() 'action_name' end
end

require 'squash/rails'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|

end
