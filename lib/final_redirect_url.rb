require "final_redirect_url/version"

module FinalRedirectUrl

  def self.final_redirect_url(url, options={})
    unless is_valid_url?(url)
      return ''
    else
      redirect_lookup_depth = options[:depth].to_i > 0 ? options[:depth].to_i : 10
      get_final_redirect_url(url, redirect_lookup_depth)
    end
  end

  private
  def self.is_valid_url?(url)
    # Validate URL
  end

  def get_final_redirect_url(url, limit = 10)
    uri = URI.parse(url)
    response = Net::HTTP.get_response(uri)
    if response.class == Net::HTTPOK
      return uri
    else
      redirect_location = response['location']
      location_uri = URI.parse(redirect_location)
      if location_uri.host.blank?
        redirect_location = uri.scheme + '://' + uri.host + redirect_location
      end
      warn "redirected to #{redirect_location}"
      get_final_redirect_url(redirect_location, limit - 1)
    end
  end
end
