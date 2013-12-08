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

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/class/delegating_attributes'
require 'active_support/core_ext/class/inheritable_attributes'
require 'active_support/core_ext/blank'
require 'active_support/core_ext/array'
require 'active_record'
require 'active_record/base'
require 'action_controller'

describe Squash::Ruby do
  describe "#notify" do
    it "should report the client type as 'rails'" do
      expect(Squash::Ruby.client_name).to eql('rails')
    end

    it "should unwrap ActiveRecord::StatementInvalid errors" do
      begin
        raise ActiveRecord::StatementInvalid, "Mysql2::Error: foobar"
      rescue => err
      end

      hsh = Squash::Ruby.send(:exception_info_hash, err, Time.now, {}, [])
      expect(hsh['class_name']).to eql('Mysql2::Error')
      expect(hsh['message']).to eql('foobar')
    end
  end

  describe "#failsafe_logger" do
    before :each do
      @logger = Logger.new(STDOUT)
      class << @logger
        attr_reader :error_messages
        def error(*args) (@error_messages ||= []) << args end
      end
    end

    it "should log to the Rails logger" do
      allow(Rails).to receive(:logger).and_return(@logger)
      expect(@logger).to receive(:tagged).once.with('tag').and_yield
      Squash::Ruby.failsafe_log 'tag', 'message'
      expect(@logger.error_messages).to eql([['message']])
    end

    it "should be Rails 2 compatible" do
      allow(Rails).to receive(:logger).and_return(@logger)
      Squash::Ruby.failsafe_log 'tag', 'message'
      expect(@logger.error_messages).to eql([["[tag]\tmessage"]])
    end

    it "should be Rails 1 compatible" do
      Rails = OpenStruct.new(:env => 'RAILS_ENV', :root => 'RAILS_ROOT', :version => '3.2.0')
      ::RAILS_DEFAULT_LOGGER = @logger
      Squash::Ruby.failsafe_log 'tag', 'message'
      expect(@logger.error_messages).to eql([["[tag]\tmessage"]])
    end

    it "should failsafe itself to stderr" do
      allow(Rails).to receive(:logger).and_return(@logger)
      expect(@logger).to receive(:error).once.and_raise(ArgumentError)
      allow($stderr).to receive(:puts)
      expect { Squash::Ruby.failsafe_log 'tag', 'message' }.not_to raise_error
    end
  end
end
