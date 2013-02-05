module Squash
  module Rails

    # Rack middleware that catches exceptions thrown outside the scope of
    # Rails's request processing. This middleware is automatically added to your
    # stack when you include the `squash_rails` gem.

    class Rack

      # Instantiates the middleware.
      #
      # @param [Array] app The middleware stack.

      def initialize(app)
        @app = app
      end

      # Rescues any exceptions thrown downstream, notifies Squash, then
      # re-raises them.
      #
      # @param [Hash] env The Rack environment.
      # @return [Hash] The Rack result to pass up the stack.

      def call(env)
        @env = env

        begin
          result = @app.call(env)
        rescue ::Exception => ex
          @env['squash.notified'] = ::Squash::Ruby.notify(ex, squash_rack_data)
          raise ex
        end

        result
      end

      # @abstract
      #
      # Override this method to implement filtering of sensitive data in the
      # headers, cookies, and rack hashes (see {#squash_rack_data}). The method
      # signature is the same as `Squash::Ruby#filter_for_squash`, but `kind`
      # can also be `:env` for the Rack environment hash.

      def filter_for_squash(data, kind)
        data
      end

      # @return [Hash<Symbol, Object>] The additional information this
      #   middleware gives to `Squash::Ruby.notify`.

      def squash_rack_data
        {
          :environment    => environment_name,
          :root           => root_path,

          :headers        => filter_for_squash(request_headers, :headers),
          :request_method => @env['REQUEST_METHOD'].to_s.upcase,
          :schema         => @env['rack.url_scheme'],
          :host           => @env['SERVER_NAME'],
          :port           => @env['SERVER_PORT'],
          :path           => @env['PATH_INFO'],
          :query          => @env['QUERY_STRING'],

          :params         => filter_for_squash(@env['action_dispatch.request.parameters'], :params),
          :session        => filter_for_squash(@env['rack.session'], :session),
          :flash          => filter_for_squash(@env[ActionDispatch::Flash::KEY], :flash),
          :cookies        => filter_for_squash(@env['rack.request.cookie_hash'], :cookies),

          :"rack.env"     => filter_for_squash(@env, :rack)
        }
      end

      private

      def environment_name
        if defined?(::Rails)
          ::Rails.env.to_s
        else
          ENV['RAILS_ENV'] || ENV['RACK_ENV']
        end
      end

      # Extract any rack key/value pairs where the key begins with HTTP_*
      def request_headers
        @env.select { |key, _| key[0, 5] == 'HTTP_' }
      end

      def root_path
        defined?(::Rails) ? ::Rails.root.to_s : ENV['RAILS_ROOT']
      end
    end
  end
end

