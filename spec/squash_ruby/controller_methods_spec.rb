# Copyright 2012 Square Inc.
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

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'ostruct'

# Fake Rails-in-a-box
module Railsish
  ::Rails = OpenStruct.new(:env => 'RAILS_ENV', :root => 'RAILS_ROOT')

  def request
    @request ||= OpenStruct.new(
        :xhr?                => true,
        :headers             => {'SOME' => 'Headers'},
        :request_method      => :get,
        :protocol            => 'https://',
        :host                => 'www.example.com',
        :port                => 443,
        :path                => '/example',
        :query_string        => 'some=example&here=also',
        :filtered_parameters => {'some' => 'params'})
  end

  def session()
    {'some' => 'session'}
  end

  def flash()
    fl             = ActionDispatch::Flash::FlashHash.new
    fl[:some]      = 'hash'
    fl.now[:other] = 'key'
    fl
  end

  def cookies()
    jar = Object.new
    jar.send :instance_variable_set, :@cookies, {'some' => 'cookies'}
    jar
  end

  def controller_name() 'controller_name' end
  def action_name() 'action_name' end
end

describe Squash::Ruby::ControllerMethods do
  include Squash::Ruby::ControllerMethods
  include Railsish

  describe "#notify_squash" do
    before :each do
      begin
        raise ArgumentError, "Sploops!"
      rescue => err
        @exception = err
      end
    end

    it "should call Squash::Ruby.notify with additional Rails information" do
      Squash::Ruby.should_receive(:notify).once.with(@exception,
                                                     :headers        => {'SOME' => 'Headers'},
                                                     :request_method => 'GET',
                                                     :schema         => 'https',
                                                     :host           => 'www.example.com',
                                                     :port           => 443,
                                                     :path           => '/example',
                                                     :query          => 'some=example&here=also',
                                                     :params         => {'some' => 'params'},
                                                     :session        => {'some' => 'session'},
                                                     :flash          => {'some' => 'hash', 'other' => 'key'},
                                                     :cookies        => {'some' => 'cookies'},
                                                     :environment    => 'RAILS_ENV',
                                                     :root           => 'RAILS_ROOT',
                                                     :controller     => 'controller_name',
                                                     :action         => 'action_name')
      notify_squash @exception
    end

    it "should add user data" do
      Squash::Ruby.should_receive(:notify).once.with(anything, hash_including(:user => 'data'))
      notify_squash @exception, :user => 'data'
    end

    it "should filter out Rack headers" do
      request.stub!(:headers).and_return('rack.onething' => 'foo', 'OTHER_THING' => 'bar')
      Squash::Ruby.should_receive(:notify).once.with(anything, hash_including(:headers => {'OTHER_THING' => 'bar'}))
      notify_squash @exception
    end

    it "should filter the HTTP-Authorization header" do
      request.stub!(:headers).and_return('HTTP_AUTHORIZATION' => 'foo', 'http-authorization' => 'bar')
      Squash::Ruby.should_receive(:notify).once.with(anything, hash_including(:headers => {}))
      notify_squash @exception
    end

    it "should filter the RAW_POST_DATA header" do
      request.stub!(:headers).and_return('RAW_POST_DATA' => 'foo')
      Squash::Ruby.should_receive(:notify).once.with(anything, hash_including(:headers => {}))
      notify_squash @exception
    end

    it "should apply the user's header filters" do
      def filter_for_squash(data, kind)
        kind == :headers ? data.delete_if { |k, _| k =='DELETE_ME' } : data
      end

      Squash::Ruby.should_receive(:notify).once.with(anything, hash_including(:headers => {'DONT_DELETE' => 'keep'}))
      request.stub!(:headers).and_return('DELETE_ME' => 'delete', 'DONT_DELETE' => 'keep')
      notify_squash @exception
    end

    it "should apply the user's params filters" do
      def filter_for_squash(data, kind)
        kind == :params ? data.delete_if { |k, _| k =='deleteme' } : data
      end

      Squash::Ruby.should_receive(:notify).once.with(anything, hash_including(:params => {'dontdelete' => 'keep'}))
      request.stub!(:filtered_parameters).and_return('deleteme' => 'delete', 'dontdelete' => 'keep')
      request.stub!(:filtered_parameters).and_return('deleteme' => 'delete', 'dontdelete' => 'keep')
      notify_squash @exception
    end

    it "should apply the user's session filters" do
      def filter_for_squash(data, kind)
        kind == :session ? data.delete_if { |k, _| k =='deleteme' } : data
      end

      Squash::Ruby.should_receive(:notify).once.with(anything, hash_including(:session => {'dontdelete' => 'keep'}))
      stub!(:session).and_return('deleteme' => 'delete', 'dontdelete' => 'keep')
      notify_squash @exception
    end

    it "should apply the user's flash filters" do
      def filter_for_squash(data, kind)
        kind == :flash ? data.delete_if { |k, _| k =='deleteme' } : data
      end

      Squash::Ruby.should_receive(:notify).once.with(anything, hash_including(:flash => {'dontdelete' => 'keep'}))
      fl               = ActionDispatch::Flash::FlashHash.new
      fl['deleteme']   = 'delete'
      fl['dontdelete'] = 'keep'
      stub!(:flash).and_return(fl)
      notify_squash @exception
    end

    it "should apply the user's cookies filters" do
      def filter_for_squash(data, kind)
        kind == :cookies ? data.delete_if { |k, _| k =='deleteme' } : data
      end

      Squash::Ruby.should_receive(:notify).once.with(anything, hash_including(:cookies => {'dontdelete' => 'keep'}))
      jar = Object.new; jar.send(:instance_variable_set, :@cookies, {'deleteme' => 'delete', 'dontdelete' => 'keep'})
      stub!(:cookies).and_return(jar)
      notify_squash @exception
    end
  end

  describe "#record_to_squash" do
    before :each do
      @railsish = {:headers        => {'SOME' => 'Headers'},
                   :request_method => 'GET',
                   :schema         => 'https',
                   :host           => 'www.example.com',
                   :port           => 443,
                   :path           => '/example',
                   :query          => 'some=example&here=also',
                   :params         => {'some' => 'params'},
                   :session        => {'some' => 'session'},
                   :flash          => {'some' => 'hash', 'other' => 'key'},
                   :cookies        => {'some' => 'cookies'},
                   :environment    => 'RAILS_ENV',
                   :root           => 'RAILS_ROOT',
                   :controller     => 'controller_name',
                   :action         => 'action_name'}
    end

    it "should call Squash::Ruby.record with additional Rails information (exception, message, user data)" do
      Squash::Ruby.should_receive(:record).with(ArgumentError, "foobar", hash_including(@railsish.merge(:user => 'data')))
      record_to_squash ArgumentError, 'foobar', :user => 'data'
    end

    it "should call Squash::Ruby.record with additional Rails information (exception, message)" do
      Squash::Ruby.should_receive(:record).with(ArgumentError, "foobar", hash_including(@railsish))
      record_to_squash ArgumentError, 'foobar'
    end

    it "should call Squash::Ruby.record with additional Rails information (message, user data)" do
      Squash::Ruby.should_receive(:record).with(StandardError, "foobar", hash_including(@railsish.merge(:user => 'data')))
      record_to_squash 'foobar', :user => 'data'
    end

    it "should call Squash::Ruby.record with additional Rails information (message)" do
      Squash::Ruby.should_receive(:record).with(StandardError, "foobar", hash_including(@railsish))
      record_to_squash 'foobar'
    end
  end
end

describe Squash::Ruby::ControllerMethods::ClassMethods do
  include Squash::Ruby::ControllerMethods::ClassMethods
  include Railsish

  describe "#enable_squash_client" do
    it "should set an around_filter" do
      # steal the block that's passed to prepend_around_filter
      @filter = nil
      def prepend_around_filter(filter, options={})
        @filter = filter
        @options = options
      end

      enable_squash_client
      @filter.should eql(:_squash_around_filter)
    end

    it "should pass options through" do
      # steal the block that's passed to prepend_around_filter
      @filter = nil
      def prepend_around_filter(filter, options={})
        @filter = filter
        @options = options
      end

      enable_squash_client :only => :foo
      @options.should eql(:only => :foo)
    end
  end
end
