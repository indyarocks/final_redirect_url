require 'final_redirect_url/version'
require 'net/http'
require 'net/https'
require 'uri'
require 'logger'

module FinalRedirectUrl
  DEFAULT_DEPTH = 10
  USER_AGENT = "FinalRedirectUrl/#{VERSION} (+https://github.com/indyarocks/final_redirect_url)".freeze

  class << self
    # Resolves all HTTP/HTTPS redirects for the given URL and returns the final
    # destination as a string. Returns an empty string for invalid input or on
    # unrecoverable network errors.
    #
    # @param url [String] the starting URL (must include http:// or https://)
    # @param options [Hash]
    # @option options [Integer] :depth maximum redirect hops (default: 10)
    # @return [String]
    def final_redirect_url(url, options = {})
      return '' unless valid_url?(url)

      limit = options.fetch(:depth, DEFAULT_DEPTH).to_i
      limit = DEFAULT_DEPTH unless limit.positive?

      resolve_redirects(url, limit).to_s
    rescue StandardError => ex
      Logger.new($stdout).error(ex.message)
      ''
    end

    private

    # Returns true only for syntactically valid HTTP/HTTPS URLs.
    # Fixes issue #4: private via class << self so the method is genuinely
    # inaccessible from outside the module.
    def valid_url?(url)
      uri = URI.parse(url.to_s)
      uri.is_a?(URI::HTTP)
    rescue URI::InvalidURIError
      false
    end

    # Recursively follows redirects up to +limit+ hops.
    # Fixes issue #2: when the hop limit is reached, returns the current URI
    # (a proper URI object, not a bare string) so url_string_from_uri never
    # receives a plain String.
    # Fixes issue #6: uses URI.join to build absolute redirect targets, which
    # preserves non-standard ports from the base URI (e.g. localhost:3000).
    def resolve_redirects(url, limit)
      uri = URI.parse(url)
      return uri if limit <= 0

      response = fetch_response(uri)

      case response
      when Net::HTTPOK
        uri
      when Net::HTTPRedirection
        location = response['location']
        warn "redirected to #{location}"
        resolve_redirects(absolute_url(uri, location), limit - 1)
      else
        # Non-redirect, non-200 response (e.g. 404, 403, 500): return the
        # current URI rather than trying to follow a missing Location header.
        uri
      end
    end

    # Opens an HTTP/HTTPS connection and fires a HEAD request.
    # HEAD is sufficient for redirect resolution and avoids downloading bodies.
    def fetch_response(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl     = (uri.scheme == 'https')
      http.open_timeout = 10
      http.read_timeout = 10

      request = Net::HTTP::Head.new(uri.request_uri)
      request['User-Agent'] = USER_AGENT

      http.request(request)
    end

    # Converts a potentially relative +location+ into an absolute URL,
    # keeping the scheme, host, and port of +base_uri+.
    def absolute_url(base_uri, location)
      URI.join(base_uri.to_s, location).to_s
    end
  end
end
