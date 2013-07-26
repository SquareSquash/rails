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
require 'active_record/errors'

describe Squash::Ruby do
  describe "#notify" do
    it "should report the client type as 'rails'" do
      Squash::Ruby.client_name.should eql('rails')
    end

    it "should unwrap ActiveRecord::StatementInvalid errors" do
      begin
        raise ActiveRecord::StatementInvalid, "Mysql2::Error: foobar"
      rescue => err
      end

      hsh = Squash::Ruby.send(:exception_info_hash, err, Time.now, {}, [])
      hsh['class_name'].should eql('Mysql2::Error')
      hsh['message'].should eql('foobar')
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
      Rails.stub(:logger).and_return(@logger)
      @logger.should_receive(:tagged).once.with('tag').and_yield
      Squash::Ruby.failsafe_log 'tag', 'message'
      @logger.error_messages.should eql([['message']])
    end

    it "should be Rails 2 compatible" do
      Rails.stub(:logger).and_return(@logger)
      Squash::Ruby.failsafe_log 'tag', 'message'
      @logger.error_messages.should eql([["[tag]\tmessage"]])
    end

    it "should be Rails 1 compatible" do
      Rails = OpenStruct.new(:env => 'RAILS_ENV', :root => 'RAILS_ROOT', :version => '3.2.0')
      ::RAILS_DEFAULT_LOGGER = @logger
      Squash::Ruby.failsafe_log 'tag', 'message'
      @logger.error_messages.should eql([["[tag]\tmessage"]])
    end

    it "should failsafe itself to stderr" do
      Rails.stub(:logger).and_return(@logger)
      @logger.should_receive(:error).once.and_raise(ArgumentError)
      $stderr.should_receive(:puts).any_number_of_times
      lambda { Squash::Ruby.failsafe_log 'tag', 'message' }.should_not raise_error
    end
  end
end
