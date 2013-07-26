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

# `ActionController::Base` mixin that provides Rails-specific Squash support.
#
# @example
#   class MyController < ActionController::Base
#     include Squash::Ruby::ControllerMethods
#     enable_squash_client
#   end

module Squash::Ruby::ControllerMethods
  # Request headers that typically contain sensitive information. As an
  # alternative to appending to this constant, you can also override the
  # {#filter_for_squash} method.
  FILTERED_HEADERS = %w(HTTP_AUTHORIZATION RAW_POST_DATA)

  # @private
  def self.included(base)
    base.extend ClassMethods
  end

  protected

  # Notifies Squash of an exception. Unlike `Squash::Ruby.notify`, this method
  # annotates the exception with Rails-specific information (see
  # {#squash_rails_data}).
  #
  # @param [Object] exception The exception. Must at least duck-type an
  #   `Exception` subclass.
  # @param [Hash] user_data Any additional context-specific information about
  #   the exception.
  # @return [true, false] Whether the exception was reported to Squash. (Some
  #   exceptions are ignored and not reported to Squash.)

  def notify_squash(exception, user_data={})
    exception.instance_variable_set :@_squash_controller_notified, true
    Squash::Ruby.notify exception, user_data.merge(squash_rails_data)
  end

  # Creates an exception, notifies Squash, then swallows the exception. Unlike
  # `Squash::Ruby.record`, this method annotates the exception with
  # Rails-specific information (see {#squash_rails_data}).
  #
  # @overload record_to_squash(exception_class, message, user_data={})
  #   Specify both the exception class and the message.
  #   @param [Class] exception_class The exception class to raise.
  #   @param [String] message The exception message.
  #   @param [Hash] user_data Additional information to give to {.notify}.
  # @overload record_to_squash(message, user_data={})
  #   Specify only the message. The exception class will be `StandardError`.
  #   @param [String] message The exception message.
  #   @param [Hash] user_data Additional information to give to {.notify}.

  def record_to_squash(exception_class_or_message, message_or_options=nil, data=nil)
    if message_or_options && data
      exception_class = exception_class_or_message
      message         = message_or_options
      data            ||= {}
    elsif message_or_options.kind_of?(String)
      message         = message_or_options
      exception_class = exception_class_or_message
      data            ||= {}
    elsif message_or_options.kind_of?(Hash)
      data            = message_or_options
      message         = exception_class_or_message
      exception_class = StandardError
    elsif message_or_options.nil?
      message         = exception_class_or_message
      exception_class = StandardError
      data            ||= {}
    else
      raise ArgumentError
    end

    Squash::Ruby.record exception_class, message, data.merge(squash_rails_data)
  end

  # @return [Hash<Symbol, Object>] The additional information that
  #   {#notify_squash} gives to `Squash::Ruby.notify`.

  def squash_rails_data
    flash_hash      = flash.to_hash.stringify_keys
    filtered_params = request.respond_to?(:filtered_parameters) ? request.filtered_parameters : filter_parameters(params)
    headers         = Hash.new
    request.headers.each { |key, value| headers[key] = value }

    {
        :environment    => Rails.env.to_s,
        :root           => Rails.root.to_s,

        :headers        => filter_for_squash(_filter_for_squash(headers, :headers), :headers),
        :request_method => request.request_method.to_s.upcase,
        :schema         => request.protocol.sub('://', ''),
        :host           => request.host,
        :port           => request.port,
        :path           => request.path,
        :query          => request.query_string,

        :controller     => controller_name,
        :action         => action_name,
        :params         => filter_for_squash(filtered_params, :params),
        :session        => filter_for_squash(session.to_hash, :session),
        :flash          => filter_for_squash(flash_hash, :flash),
        :cookies        => filter_for_squash(cookies.instance_variable_get(:@cookies) || {}, :cookies)
    }
  end

  # @abstract
  #
  # Override this method to implement filtering of sensitive data in the
  # `params`, `session`, `flash`, and `cookies` hashes before they are
  # transmitted to Squash. The `params` hash is already filtered according to
  # the project's `filter_parameters` configuration option; if you need any
  # additional filtering, override this method.
  #
  # @param [Hash] data The hash of user data to be filtered.
  # @param [Symbol] kind Either `:params`, `:session`, `:flash`, `:cookies`, or
  #   `:headers`.
  # @return [Hash] A copy of `data` with sensitive data removed or replaced.

  def filter_for_squash(data, kind)
    data
  end

  private

  def _squash_around_filter
    begin
      yield
    rescue Object => err
      handler_err = err.respond_to?(:original_exception) ? err.original_exception : err
      notify_squash(err) unless handler_for_rescue(handler_err)
      raise
    end
  end

  module ClassMethods
    protected

    # Prepends an `around_filter` that catches any exceptions and notifies
    # Squash. Exceptions are then re-raised.
    #
    # @param [Hash] options Additional options to pass to
    #   `prepend_around_filter`, such as `:only` or `:except`.

    def enable_squash_client(options={})
      prepend_around_filter :_squash_around_filter, options
    end
  end

  private

  def _filter_for_squash(data, kind)
    case kind
      when :headers
        data.reject { |key, _| key !~ /^[A-Z0-9_]+$/ || FILTERED_HEADERS.include?(key) }
      else
        data
    end
  end
end
