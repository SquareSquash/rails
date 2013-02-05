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
