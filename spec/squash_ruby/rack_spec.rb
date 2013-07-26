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

require 'spec_helper'
require 'squash/rails/rack'

describe Squash::Rails::Rack do
  let(:app) { double("app") }
  let(:env) { {} }
  let(:result) { [ 200, {}, ""] }

  subject { described_class.new(app) }

  describe '#call' do

    context 'when app raises an error' do
      it 'notifies squash and re-raises the error' do
        app.should_receive(:call).and_raise("Downstream error")

        Squash::Ruby.should_receive(:notify) do |ex, user_data|
          ex.message.should match(/Downstream error/)
        end

        expect {
          subject.call(env)
        }.to raise_error(/Downstream error/)

        env.should have_key('squash.notified')
      end
      
      it "should not notify Squash if the controller already did so" do
        error = StandardError.new("Downstream error")
        error.instance_variable_set :@_squash_controller_notified, true
        app.should_receive(:call).and_raise(error)

        Squash::Ruby.should_not_receive(:notify)

        expect {
          subject.call(env)
        }.to raise_error(/Downstream error/)

        env.should_not have_key('squash.notified')
      end
    end

    context 'when app does not raise an error' do
      it 'does not notify squash' do
        app.should_receive(:call).with(env) { result }
        Squash::Ruby.should_not_receive(:notify)

        expect {
          subject.call(env).should eq result
        }.to_not raise_error
      end
    end

  end

end
