Squash Client Library: Ruby on Rails
====================================

This client library reports exceptions to Squash, the Squarish exception
reporting and management system. It's compatible with both pure-Ruby and Ruby on
Rails projects.

Documentation
-------------

Comprehensive documentation is written in YARD- and Markdown-formatted comments
throughout the source. To view this documentation as an HTML site, run
`rake doc`.

For an overview of the various components of Squash, see the website
documentation at https://github.com/SquareSquash/web.

Compatibility
-------------

This library is compatible with Ruby 1.8.6 and later, including Ruby Enterprise
Edition, and with Rails 2.0 and later.

Requirements
------------

The only dependency is the `squash_ruby` gem and its dependencies. For more
information, consult the `squash_ruby` gem documentation:
https://github.com/SquareSquash/ruby

Usage
-----

Add this gem and the Squash Ruby gem to your Gemfile:

```` ruby
gem 'squash_ruby', :require => 'squash/ruby'
gem 'squash_rails', :require => 'squash/rails'
````

See the `squash_ruby` gem for configuration instructions. Note that it is no
longer necessary to set the `:environment` configuration option; the Rails
client library automatically sets that to the Rails environment.

You can use the usual `Squash::Ruby.notify` method in your Rails projects, but
you will miss out on some Rails-specific information in your exception logs. You
can automatically have the Squash client send along request and Rails
information by using the client's `around_filter`:

```` ruby
class ApplicationController < ActionController::Base
  include Squash::Ruby::ControllerMethods
  enable_squash_client
end
````

Now any exception raised in the course of processing a request will be annotated
with Rails specific information. The exception is then re-raised for normal
Rails exception handling.

There may be situations where other parts of the code "eat up" an exception
before it reaches this filter; the most common example would be exceptions that
are handled by a `rescue_from` statement elsewhere in your controller.  You can
use the {Squash::Ruby::ControllerMethods#notify_squash} method to still send
these exceptions to Squash:

```` ruby
class ApplicationController < ActionController::Base
  include Squash::Ruby::ControllerMethods
  rescue_from(ActiveRecord::RecordInvalid) do |error|
    notify_squash error
    render :file => "public/422.html", :status => :unprocessable_entity
  end
end
````

**Important note:** Some versions of Rails (below 3.0) do not automatically run
the `rails/init.rb` within the gem. You will need to call
`require 'squash/rails/configure'` in a `config/initializers` file in order to
apply the Rails configuration defaults. You'll also need to add
`load 'squash/rails/tasks.rake'` to your Rakefile.

There are many additional features you can take advantage of; see **Additional
Features** in the `squash_ruby` documentation.

#### Filtering Sensitive Information

By default, `notify_squash` uses the filtered parameter list generated according
to your `config.filter_parameters` setting. If you need to further filter your
request parameters, or if you are storing sensitive information in your session,
headers, or other fields transmitted to Squash, override the
{Squash::Ruby::ControllerMethods#filter_for_squash} method in your controller.

Deploys
-------

Squash works best when you notify it if your web app's deploys. If you're using
Capistrano, this is easy. For **Capistrano 2**, just add
`require 'squash/rails/capistrano2'` to your `config/deploy.rb` file. Everything
else should be taken care of. For **Capistrano 3**, just add
`require 'squash/rails/capistrano3'` to your `Capfile`.

If you do not deploy to a live Git directory, you will need to write a
`REVISION` file to your app root. To do this, include the following in your
`config/deploy.rb` file in Capistrano 2 or 3:

```` ruby
before 'deploy:compile_assets', 'squash:write_revision'
````

or in Capistrano 2:

```` ruby
before 'deploy:assets:precompile', 'squash:write_revision'
````

If you're not using Capistrano, you will need to configure your deploy script
so that it runs the `squash:notify` Rake task on every deploy target. This Rake
task requires two environment variables to be set: `REVISION` (the current
revision of the source code) and `DEPLOY_ENV` (the environment this server is
hosting).

Additional Configuration Options
--------------------------------

The Squash Rails gem adds the following configuration options:

* `deploy_path`: The path to post new deploys to. By default it's set to
  `/api/1.0/deploy`.
