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

require 'ostruct'
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

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
      expect(Squash::Ruby).to receive(:notify).once.with(@exception,
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

    it "should set the controller-notified flag on the exception" do
      expect(Squash::Ruby).to receive(:notify).once do |exception, _options|
        expect(exception.instance_variable_get(:@_squash_controller_notified)).to be_true
      end
      notify_squash @exception
    end

    it "should add user data" do
      expect(Squash::Ruby).to receive(:notify).once.with(anything, hash_including(:user => 'data'))
      notify_squash @exception, :user => 'data'
    end

    it "should filter out Rack headers" do
      allow(request).to receive(:headers).and_return('rack.onething' => 'foo', 'OTHER_THING' => 'bar')
      expect(Squash::Ruby).to receive(:notify).once.with(anything, hash_including(:headers => {'OTHER_THING' => 'bar'}))
      notify_squash @exception
    end

    it "should filter the HTTP-Authorization header" do
      allow(request).to receive(:headers).and_return('HTTP_AUTHORIZATION' => 'foo', 'http-authorization' => 'bar')
      expect(Squash::Ruby).to receive(:notify).once.with(anything, hash_including(:headers => {}))
      notify_squash @exception
    end

    it "should filter the RAW_POST_DATA header" do
      allow(request).to receive(:headers).and_return('RAW_POST_DATA' => 'foo')
      expect(Squash::Ruby).to receive(:notify).once.with(anything, hash_including(:headers => {}))
      notify_squash @exception
    end

    it "should apply the user's header filters" do
      def filter_for_squash(data, kind)
        kind == :headers ? data.delete_if { |k, _| k =='DELETE_ME' } : data
      end

      expect(Squash::Ruby).to receive(:notify).once.with(anything, hash_including(:headers => {'DONT_DELETE' => 'keep'}))
      allow(request).to receive(:headers).and_return('DELETE_ME' => 'delete', 'DONT_DELETE' => 'keep')
      notify_squash @exception
    end

    it "should apply the user's params filters" do
      def filter_for_squash(data, kind)
        kind == :params ? data.delete_if { |k, _| k =='deleteme' } : data
      end

      expect(Squash::Ruby).to receive(:notify).once.with(anything, hash_including(:params => {'dontdelete' => 'keep'}))
      allow(request).to receive(:filtered_parameters).and_return('deleteme' => 'delete', 'dontdelete' => 'keep')
      allow(request).to receive(:filtered_parameters).and_return('deleteme' => 'delete', 'dontdelete' => 'keep')
      notify_squash @exception
    end

    it "should apply the user's session filters" do
      def filter_for_squash(data, kind)
        kind == :session ? data.delete_if { |k, _| k =='deleteme' } : data
      end

      expect(Squash::Ruby).to receive(:notify).once.with(anything, hash_including(:session => {'dontdelete' => 'keep'}))
      allow(self).to receive(:session).and_return('deleteme' => 'delete', 'dontdelete' => 'keep')
      notify_squash @exception
    end

    it "should apply the user's flash filters" do
      def filter_for_squash(data, kind)
        kind == :flash ? data.delete_if { |k, _| k =='deleteme' } : data
      end

      expect(Squash::Ruby).to receive(:notify).once.with(anything, hash_including(:flash => { 'dontdelete' => 'keep' }))
      fl               = if defined?(ActionDispatch)
                           ActionDispatch::Flash::FlashHash.new
                         else
                           ActionController::Flash::FlashHash.new
                         end
      fl['deleteme']   = 'delete'
      fl['dontdelete'] = 'keep'
      allow(self).to receive(:flash).and_return(fl)
      notify_squash @exception
    end

    it "should apply the user's cookies filters" do
      def filter_for_squash(data, kind)
        kind == :cookies ? data.delete_if { |k, _| k =='deleteme' } : data
      end

      expect(Squash::Ruby).to receive(:notify).once.with(anything, hash_including(:cookies => {'dontdelete' => 'keep'}))
      jar = Object.new; jar.send(:instance_variable_set, :@cookies, {'deleteme' => 'delete', 'dontdelete' => 'keep'})
      allow(self).to receive(:cookies).and_return(jar)
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
      expect(Squash::Ruby).to receive(:record).with(ArgumentError, "foobar", hash_including(@railsish.merge(:user => 'data')))
      record_to_squash ArgumentError, 'foobar', :user => 'data'
    end

    it "should call Squash::Ruby.record with additional Rails information (exception, message)" do
      expect(Squash::Ruby).to receive(:record).with(ArgumentError, "foobar", hash_including(@railsish))
      record_to_squash ArgumentError, 'foobar'
    end

    it "should call Squash::Ruby.record with additional Rails information (message, user data)" do
      expect(Squash::Ruby).to receive(:record).with(StandardError, "foobar", hash_including(@railsish.merge(:user => 'data')))
      record_to_squash 'foobar', :user => 'data'
    end

    it "should call Squash::Ruby.record with additional Rails information (message)" do
      expect(Squash::Ruby).to receive(:record).with(StandardError, "foobar", hash_including(@railsish))
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
      expect(@filter).to eql(:_squash_around_filter)
    end

    it "should pass options through" do
      # steal the block that's passed to prepend_around_filter
      @filter = nil
      def prepend_around_filter(filter, options={})
        @filter = filter
        @options = options
      end

      enable_squash_client :only => :foo
      expect(@options).to eql(:only => :foo)
    end
  end
end
