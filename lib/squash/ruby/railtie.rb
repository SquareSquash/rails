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

# Automatically configures the Squash environment to be equal to the Rails
# environment. This code is executed for Rails 3.0 and newer; for older Rails
# versions, see `rails/init.rb`.

class Squash::Ruby::Railtie < Rails::Railtie
  initializer "squash_client.configure_rails_initialization" do
    Squash::Ruby.configure :environment     => Rails.env.to_s,
                           :project_root    => Rails.root.to_s,
                           :repository_root => Rails.root.to_s,
                           :failsafe_log    => Rails.root.join('log', 'squash.failsafe.log').to_s
  end

  rake_tasks { load 'squash/rails/tasks.rake' }
end if defined?(Rails::Railtie)
