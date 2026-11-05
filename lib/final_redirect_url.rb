require 'final_redirect_url/version'
require 'net/http'
require 'net/https'
require 'uri'
require 'logger'
require 'nokogiri'

module FinalRedirectUrl
  DEFAULT_DEPTH        = 10
  DEFAULT_OPEN_TIMEOUT = 60
  DEFAULT_READ_TIMEOUT = 60
  USER_AGENT = "FinalRedirectUrl/#{VERSION} (+https://github.com/indyarocks/final_redirect_url)".freeze

  # Value object representing one step in a redirect chain.
  #   hop.url    # => "http://example.com/"  (String)
  #   hop.status # => 301                    (Integer, or nil when depth limit reached)
  Hop = Struct.new(:url, :status, keyword_init: true)

  class << self
    # Resolves all HTTP/HTTPS redirects for the given URL and returns the final
    # destination as a String. Returns "" for invalid input or unrecoverable errors.
    #
    # @param url     [String]  starting URL (must include http:// or https://)
    # @param options [Hash]
    # @option options [Integer] :depth        max redirect hops          (default: 10)
    # @option options [Integer] :open_timeout TCP connect timeout in sec  (default: 60)
    # @option options [Integer] :read_timeout read timeout in sec         (default: 60)
    # @option options [Boolean] :verify_ssl   enforce SSL cert validation (default: true)
    # @option options [Hash]    :headers      extra HTTP request headers
    # @return [String]
    def final_redirect_url(url, options = {})
      hops = trace(url, options)
      hops.empty? ? '' : hops.last.url
    end

    # Follows all redirects and returns every hop as an Array of Hop structs.
    # Useful for debugging, link audits, or building redirect-aware tooling.
    #
    # @param url     [String]
    # @param options [Hash]  same keys as #final_redirect_url
    # @return [Array<Hop>]
    def trace(url, options = {})
      return [] unless valid_url?(url)

      limit   = positive_int(options[:depth], DEFAULT_DEPTH)
      hops    = []
      cookies = {}

      resolve(url, limit, options, hops, cookies)
      hops
    rescue StandardError => ex
      Logger.new($stdout).error(ex.message)
      hops
    end

    private

    def resolve(url, limit, options, hops, cookies)
      uri = URI.parse(url)

      if limit <= 0
        # Depth exhausted — record the pending URL without making a request.
        hops << Hop.new(url: uri.to_s, status: nil)
        return
      end

      response = fetch_response(uri, options, cookies)
      collect_cookies(response, cookies)

      case response
      when Net::HTTPOK
        if (meta_url = meta_refresh_url(response, uri))
          hops << Hop.new(url: uri.to_s, status: response.code.to_i)
          warn "meta-refresh to #{meta_url}"
          resolve(meta_url, limit - 1, options, hops, cookies)
        else
          hops << Hop.new(url: uri.to_s, status: response.code.to_i)
        end
      when Net::HTTPRedirection
        location = absolute_url(uri, response['location'])
        hops << Hop.new(url: uri.to_s, status: response.code.to_i)
        warn "redirected to #{location}"
        resolve(location, limit - 1, options, hops, cookies)
      else
        # Non-200, non-redirect (403, 404, 500 …): record and stop.
        hops << Hop.new(url: uri.to_s, status: response.code.to_i)
      end
    end

    def fetch_response(uri, options, cookies)
      http             = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl     = (uri.scheme == 'https')
      http.verify_mode = options.fetch(:verify_ssl, true) ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      http.open_timeout = positive_int(options[:open_timeout], DEFAULT_OPEN_TIMEOUT)
      http.read_timeout = positive_int(options[:read_timeout], DEFAULT_READ_TIMEOUT)

      # GET is required so we can read the body for meta-refresh detection.
      request = Net::HTTP::Get.new(uri.request_uri)
      request['User-Agent'] = USER_AGENT

      # Caller-supplied headers override defaults (including User-Agent).
      (options[:headers] || {}).each { |k, v| request[k.to_s] = v }

      # Inject accumulated cookies for cookie-gated redirect chains.
      request['Cookie'] = cookies.map { |k, v| "#{k}=#{v}" }.join('; ') unless cookies.empty?

      http.request(request)
    end

    # Harvests Set-Cookie values from a response into the shared cookie jar.
    def collect_cookies(response, cookies)
      Array(response.get_fields('set-cookie')).each do |cookie_str|
        name, value = cookie_str.split(';', 2).first.to_s.split('=', 2)
        cookies[name.to_s.strip] = value.to_s.strip
      end
    end

    # Parses <meta http-equiv="refresh"> from an HTML body and returns the
    # resolved absolute URL, or nil when no meta-refresh is present.
    # Inspired by the counterfind fork; rewritten for correctness and safety.
    def meta_refresh_url(response, base_uri)
      content_type = response['content-type'].to_s
      return nil unless content_type.empty? || content_type.include?('html')
      return nil if response.body.to_s.empty?

      doc  = Nokogiri::HTML.parse(response.body)
      meta = doc.at_xpath(
        "//meta[translate(@http-equiv," \
        "'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')='refresh']/@content"
      )
      return nil unless meta

      # Content examples:
      #   "0; url=https://final.example.com/"
      #   "5; URL='https://final.example.com/'"
      #   "0; https://final.example.com/"  (some malformed pages omit "url=")
      raw      = meta.value.to_s
      url_part = raw.split(/;\s*/i, 2).last.to_s
                    .sub(/\Aurl\s*=\s*/i, '')
                    .gsub(/['"]/, '')
                    .strip
      return nil if url_part.empty?

      absolute_url(base_uri, url_part)
    rescue StandardError
      nil
    end

    def valid_url?(url)
      uri = URI.parse(url.to_s)
      uri.is_a?(URI::HTTP)
    rescue URI::InvalidURIError
      false
    end

    def absolute_url(base_uri, location)
      URI.join(base_uri.to_s, location).to_s
    end

    def positive_int(value, default)
      return default if value.nil?
      v = value.to_i
      v.positive? ? v : default
    end
  end
end
