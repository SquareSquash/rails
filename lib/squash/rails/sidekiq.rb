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

module Squash

  # Sidekiq adapter for Squash. Reports all exceptions in Sidekiq to Squash,
  # then re-raises them for Sidekiq to manage.

  class Sidekiq
    # @private
    def call(worker, msg, queue)
      begin
        yield
      rescue => err
        Squash::Ruby.notify err,
                            :jid             => worker.jid,
                            :sidekiq_message => msg,
                            :queue           => queue
        raise
      end
    end
  end
end

::Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add ::Squash::Sidekiq
  end
end
