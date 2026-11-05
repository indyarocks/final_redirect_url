require 'spec_helper'

RSpec.describe FinalRedirectUrl do
  describe '::VERSION' do
    it 'is defined and not nil' do
      expect(FinalRedirectUrl::VERSION).not_to be_nil
    end

    it 'is 2.0.0' do
      expect(FinalRedirectUrl::VERSION).to eq('2.0.0')
    end
  end

  # -------------------------------------------------------------------------
  # Issue #4 – Private methods must not be callable from outside the module
  # -------------------------------------------------------------------------
  describe 'private method visibility' do
    it 'does not expose valid_url? as a public singleton method' do
      expect { FinalRedirectUrl.valid_url?('http://example.com') }
        .to raise_error(NoMethodError)
    end

    it 'does not expose resolve_redirects as a public singleton method' do
      expect { FinalRedirectUrl.resolve_redirects('http://example.com', 5) }
        .to raise_error(NoMethodError)
    end

    it 'does not expose fetch_response as a public singleton method' do
      expect { FinalRedirectUrl.fetch_response(URI.parse('http://example.com')) }
        .to raise_error(NoMethodError)
    end
  end

  # -------------------------------------------------------------------------
  # Input validation
  # -------------------------------------------------------------------------
  describe '.final_redirect_url' do
    context 'with an invalid URL' do
      it 'returns an empty string for a bare hostname (no protocol)' do
        expect(FinalRedirectUrl.final_redirect_url('www.google.com')).to eq('')
      end

      it 'returns an empty string for nil input' do
        expect(FinalRedirectUrl.final_redirect_url(nil)).to eq('')
      end

      it 'returns an empty string for an empty string' do
        expect(FinalRedirectUrl.final_redirect_url('')).to eq('')
      end

      it 'returns an empty string for a non-HTTP scheme' do
        expect(FinalRedirectUrl.final_redirect_url('ftp://example.com')).to eq('')
      end
    end

    # -----------------------------------------------------------------------
    # No redirects
    # -----------------------------------------------------------------------
    context 'with no redirects (200 OK response)' do
      before do
        stub_request(:head, 'http://example.com/')
          .to_return(status: 200, headers: {})
      end

      it 'returns the original URL unchanged' do
        expect(FinalRedirectUrl.final_redirect_url('http://example.com/')).to eq('http://example.com/')
      end
    end

    # -----------------------------------------------------------------------
    # Single redirect
    # -----------------------------------------------------------------------
    context 'with a single redirect' do
      before do
        stub_request(:head, 'http://short.ly/abc')
          .to_return(status: 301, headers: { 'Location' => 'http://final.example.com/page' })
        stub_request(:head, 'http://final.example.com/page')
          .to_return(status: 200, headers: {})
      end

      it 'returns the redirected URL' do
        expect(FinalRedirectUrl.final_redirect_url('http://short.ly/abc'))
          .to eq('http://final.example.com/page')
      end
    end

    # -----------------------------------------------------------------------
    # Multiple redirects
    # -----------------------------------------------------------------------
    context 'with multiple redirects' do
      before do
        stub_request(:head, 'http://hop1.example.com/')
          .to_return(status: 301, headers: { 'Location' => 'http://hop2.example.com/' })
        stub_request(:head, 'http://hop2.example.com/')
          .to_return(status: 302, headers: { 'Location' => 'http://final.example.com/' })
        stub_request(:head, 'http://final.example.com/')
          .to_return(status: 200, headers: {})
      end

      it 'follows all hops and returns the final URL' do
        expect(FinalRedirectUrl.final_redirect_url('http://hop1.example.com/'))
          .to eq('http://final.example.com/')
      end
    end

    # -----------------------------------------------------------------------
    # HTTPS redirect
    # -----------------------------------------------------------------------
    context 'with an HTTP → HTTPS redirect' do
      before do
        stub_request(:head, 'http://example.com/secure')
          .to_return(status: 301, headers: { 'Location' => 'https://example.com/secure' })
        stub_request(:head, 'https://example.com/secure')
          .to_return(status: 200, headers: {})
      end

      it 'follows the HTTPS redirect and returns the HTTPS URL' do
        expect(FinalRedirectUrl.final_redirect_url('http://example.com/secure'))
          .to eq('https://example.com/secure')
      end
    end

    # -----------------------------------------------------------------------
    # Issue #6 – Port must be preserved
    # -----------------------------------------------------------------------
    context 'with a non-standard port (issue #6)' do
      before do
        stub_request(:head, 'http://localhost:3000/items/abc-123')
          .to_return(status: 200, headers: {})
      end

      it 'preserves the port number in the returned URL' do
        result = FinalRedirectUrl.final_redirect_url('http://localhost:3000/items/abc-123')
        expect(result).to eq('http://localhost:3000/items/abc-123')
      end
    end

    context 'with a redirect from a non-standard-port host to a relative path (issue #6)' do
      before do
        stub_request(:head, 'http://localhost:3000/old-path')
          .to_return(status: 301, headers: { 'Location' => '/new-path' })
        stub_request(:head, 'http://localhost:3000/new-path')
          .to_return(status: 200, headers: {})
      end

      it 'resolves the relative redirect while keeping the original port' do
        result = FinalRedirectUrl.final_redirect_url('http://localhost:3000/old-path')
        expect(result).to eq('http://localhost:3000/new-path')
      end
    end

    # -----------------------------------------------------------------------
    # Issue #2 – Depth / hop limit must be respected
    # -----------------------------------------------------------------------
    context 'with the redirect depth exceeded (issue #2)' do
      before do
        # Three hops, but we set depth: 2 — the gem should stop at hop 2.
        stub_request(:head, 'http://hop1.example.com/')
          .to_return(status: 301, headers: { 'Location' => 'http://hop2.example.com/' })
        stub_request(:head, 'http://hop2.example.com/')
          .to_return(status: 301, headers: { 'Location' => 'http://hop3.example.com/' })
        stub_request(:head, 'http://hop3.example.com/')
          .to_return(status: 200, headers: {})
      end

      it 'stops following redirects when depth is exhausted and returns the URL at that depth' do
        # With depth: 1 we follow only 1 hop, so we stop at hop2 without requesting hop3.
        result = FinalRedirectUrl.final_redirect_url('http://hop1.example.com/', depth: 1)
        expect(result).to eq('http://hop2.example.com/')
        # hop3 must NOT have been requested.
        expect(WebMock).not_to have_requested(:head, 'http://hop3.example.com/')
      end

      it 'accepts a custom depth that follows more hops' do
        result = FinalRedirectUrl.final_redirect_url('http://hop1.example.com/', depth: 10)
        expect(result).to eq('http://hop3.example.com/')
      end
    end

    context 'with a non-redirect, non-200 response (edge case for issue #2)' do
      before do
        stub_request(:head, 'http://broken.example.com/')
          .to_return(status: 403, headers: {})
      end

      it 'returns the URL that produced the error response rather than raising' do
        expect(FinalRedirectUrl.final_redirect_url('http://broken.example.com/'))
          .to eq('http://broken.example.com/')
      end
    end

    # -----------------------------------------------------------------------
    # Issue #3 – Google News / AMP URLs
    # Gem can only follow HTTP-level redirects. AMP/JS-based redirects
    # require a headless browser and are intentionally out of scope.
    # We document the limitation here and verify that the gem still returns
    # the last HTTP-reachable URL rather than crashing.
    # -----------------------------------------------------------------------
    context 'with a URL that uses non-HTTP (JS/AMP) redirects (issue #3)' do
      before do
        stub_request(:head, 'https://news.google.com/articles/abc123')
          .to_return(status: 200, headers: {})
      end

      it 'returns the original URL when no HTTP redirect is present' do
        result = FinalRedirectUrl.final_redirect_url('https://news.google.com/articles/abc123')
        expect(result).to eq('https://news.google.com/articles/abc123')
      end
    end

    # -----------------------------------------------------------------------
    # Query string and fragment preservation
    # -----------------------------------------------------------------------
    context 'with query parameters' do
      before do
        stub_request(:head, 'http://example.com/search?q=ruby&page=1')
          .to_return(status: 200, headers: {})
      end

      it 'preserves query parameters in the final URL' do
        result = FinalRedirectUrl.final_redirect_url('http://example.com/search?q=ruby&page=1')
        expect(result).to include('?q=ruby')
      end
    end
  end
end
