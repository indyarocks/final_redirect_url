require 'final_redirect_url/version'
require 'net/http'
require 'logger'

module FinalRedirectUrl

  def self.final_redirect_url(url, options={})
    final_url = ''
    if is_valid_url?(url)
      begin
        redirect_lookup_depth = options[:depth].to_i > 0 ? options[:depth].to_i : 10
        response_uri = get_final_redirect_url(url, redirect_lookup_depth)
        final_url =  url_string_from_uri(response_uri)
      rescue Exception => ex
        logger = Logger.new(STDOUT)
        logger.error(ex.message)
      end
    end
    final_url
  end

  private
  def self.is_valid_url?(url)
    url.to_s =~ /\A#{URI::regexp(['http', 'https'])}\z/
  end

  def self.get_final_redirect_url(url, limit = 10)
    return url if limit <= 0
    uri = URI.parse(url)
    response = ::Net::HTTP.get_response(uri)
    if response.class == Net::HTTPOK
      return uri
    else
      redirect_location = response['location']
      location_uri = URI.parse(redirect_location)
      if location_uri.host.nil?
        redirect_location = uri.scheme + '://' + uri.host + redirect_location
      end
      warn "redirected to #{redirect_location}"
      get_final_redirect_url(redirect_location, limit - 1)
    end
  end

  def self.url_string_from_uri(uri)
    url_str = "#{uri.scheme}://#{uri.host}#{uri.request_uri}"
    if uri.fragment
      url_str = url_str + "##{uri.fragment}"
    end
    url_str
  end
end
