require 'spec_helper'

RSpec.describe FinalRedirectUrl do
  # ---------------------------------------------------------------------------
  # Version
  # ---------------------------------------------------------------------------
  describe '::VERSION' do
    it 'is defined and not nil' do
      expect(FinalRedirectUrl::VERSION).not_to be_nil
    end

    it 'is 2.1.0' do
      expect(FinalRedirectUrl::VERSION).to eq('2.1.0')
    end
  end

  # ---------------------------------------------------------------------------
  # Hop struct
  # ---------------------------------------------------------------------------
  describe '::Hop' do
    it 'exposes url and status' do
      hop = FinalRedirectUrl::Hop.new(url: 'http://example.com/', status: 200)
      expect(hop.url).to eq('http://example.com/')
      expect(hop.status).to eq(200)
    end
  end

  # ---------------------------------------------------------------------------
  # Issue #4 – Private methods must not be callable from outside the module
  # ---------------------------------------------------------------------------
  describe 'private method visibility' do
    it 'does not expose valid_url? as a public singleton method' do
      expect { FinalRedirectUrl.valid_url?('http://example.com') }
        .to raise_error(NoMethodError)
    end

    it 'does not expose resolve as a public singleton method' do
      expect { FinalRedirectUrl.resolve('http://example.com', 5, {}, [], {}) }
        .to raise_error(NoMethodError)
    end

    it 'does not expose fetch_response as a public singleton method' do
      expect { FinalRedirectUrl.fetch_response(URI.parse('http://example.com'), {}, {}) }
        .to raise_error(NoMethodError)
    end
  end

  # ---------------------------------------------------------------------------
  # Input validation
  # ---------------------------------------------------------------------------
  describe '.final_redirect_url' do
    context 'with an invalid URL' do
      it 'returns "" for a bare hostname (no protocol)' do
        expect(FinalRedirectUrl.final_redirect_url('www.google.com')).to eq('')
      end

      it 'returns "" for nil input' do
        expect(FinalRedirectUrl.final_redirect_url(nil)).to eq('')
      end

      it 'returns "" for an empty string' do
        expect(FinalRedirectUrl.final_redirect_url('')).to eq('')
      end

      it 'returns "" for a non-HTTP scheme' do
        expect(FinalRedirectUrl.final_redirect_url('ftp://example.com')).to eq('')
      end
    end

    # -------------------------------------------------------------------------
    # No redirects
    # -------------------------------------------------------------------------
    context 'with no redirects (200 OK)' do
      before { stub_request(:get, 'http://example.com/').to_return(status: 200) }

      it 'returns the original URL unchanged' do
        expect(FinalRedirectUrl.final_redirect_url('http://example.com/')).to eq('http://example.com/')
      end
    end

    # -------------------------------------------------------------------------
    # Single redirect
    # -------------------------------------------------------------------------
    context 'with a single redirect' do
      before do
        stub_request(:get, 'http://short.ly/abc')
          .to_return(status: 301, headers: { 'Location' => 'http://final.example.com/page' })
        stub_request(:get, 'http://final.example.com/page').to_return(status: 200)
      end

      it 'returns the redirected URL' do
        expect(FinalRedirectUrl.final_redirect_url('http://short.ly/abc'))
          .to eq('http://final.example.com/page')
      end
    end

    # -------------------------------------------------------------------------
    # Multiple redirects
    # -------------------------------------------------------------------------
    context 'with multiple redirects' do
      before do
        stub_request(:get, 'http://hop1.example.com/')
          .to_return(status: 301, headers: { 'Location' => 'http://hop2.example.com/' })
        stub_request(:get, 'http://hop2.example.com/')
          .to_return(status: 302, headers: { 'Location' => 'http://final.example.com/' })
        stub_request(:get, 'http://final.example.com/').to_return(status: 200)
      end

      it 'follows all hops and returns the final URL' do
        expect(FinalRedirectUrl.final_redirect_url('http://hop1.example.com/'))
          .to eq('http://final.example.com/')
      end
    end

    # -------------------------------------------------------------------------
    # HTTP → HTTPS redirect
    # -------------------------------------------------------------------------
    context 'with an HTTP → HTTPS redirect' do
      before do
        stub_request(:get, 'http://example.com/secure')
          .to_return(status: 301, headers: { 'Location' => 'https://example.com/secure' })
        stub_request(:get, 'https://example.com/secure').to_return(status: 200)
      end

      it 'follows the HTTPS redirect' do
        expect(FinalRedirectUrl.final_redirect_url('http://example.com/secure'))
          .to eq('https://example.com/secure')
      end
    end

    # -------------------------------------------------------------------------
    # Issue #6 – Port preservation
    # -------------------------------------------------------------------------
    context 'with a non-standard port (issue #6)' do
      before do
        stub_request(:get, 'http://localhost:3000/items/abc-123').to_return(status: 200)
      end

      it 'preserves the port number in the returned URL' do
        expect(FinalRedirectUrl.final_redirect_url('http://localhost:3000/items/abc-123'))
          .to eq('http://localhost:3000/items/abc-123')
      end
    end

    context 'with a relative redirect from a non-standard-port host (issue #6)' do
      before do
        stub_request(:get, 'http://localhost:3000/old-path')
          .to_return(status: 301, headers: { 'Location' => '/new-path' })
        stub_request(:get, 'http://localhost:3000/new-path').to_return(status: 200)
      end

      it 'resolves the relative redirect while keeping the original port' do
        expect(FinalRedirectUrl.final_redirect_url('http://localhost:3000/old-path'))
          .to eq('http://localhost:3000/new-path')
      end
    end

    # -------------------------------------------------------------------------
    # Issue #2 – Depth limit
    # -------------------------------------------------------------------------
    context 'with the redirect depth exceeded (issue #2)' do
      before do
        stub_request(:get, 'http://hop1.example.com/')
          .to_return(status: 301, headers: { 'Location' => 'http://hop2.example.com/' })
        stub_request(:get, 'http://hop2.example.com/')
          .to_return(status: 301, headers: { 'Location' => 'http://hop3.example.com/' })
        stub_request(:get, 'http://hop3.example.com/').to_return(status: 200)
      end

      it 'stops at depth: 1 and returns hop2 without requesting hop3' do
        result = FinalRedirectUrl.final_redirect_url('http://hop1.example.com/', depth: 1)
        expect(result).to eq('http://hop2.example.com/')
        expect(WebMock).not_to have_requested(:get, 'http://hop3.example.com/')
      end

      it 'follows all hops with depth: 10' do
        expect(FinalRedirectUrl.final_redirect_url('http://hop1.example.com/', depth: 10))
          .to eq('http://hop3.example.com/')
      end
    end

    context 'with a non-redirect, non-200 response (issue #2 edge case)' do
      before { stub_request(:get, 'http://broken.example.com/').to_return(status: 403) }

      it 'returns the URL that produced the error response rather than raising' do
        expect(FinalRedirectUrl.final_redirect_url('http://broken.example.com/'))
          .to eq('http://broken.example.com/')
      end
    end

    # -------------------------------------------------------------------------
    # Issue #3 – Google News / AMP (documented limitation)
    # -------------------------------------------------------------------------
    context 'with a URL that uses non-HTTP (JS/AMP) redirects (issue #3)' do
      before do
        stub_request(:get, 'https://news.google.com/articles/abc123')
          .to_return(status: 200, headers: { 'Content-Type' => 'text/html' }, body: '<html></html>')
      end

      it 'returns the original URL when no HTTP or meta-refresh redirect is present' do
        expect(FinalRedirectUrl.final_redirect_url('https://news.google.com/articles/abc123'))
          .to eq('https://news.google.com/articles/abc123')
      end
    end

    # -------------------------------------------------------------------------
    # Query string preservation
    # -------------------------------------------------------------------------
    context 'with query parameters' do
      before do
        stub_request(:get, 'http://example.com/search?q=ruby&page=1').to_return(status: 200)
      end

      it 'preserves query parameters in the final URL' do
        result = FinalRedirectUrl.final_redirect_url('http://example.com/search?q=ruby&page=1')
        expect(result).to include('?q=ruby')
      end
    end

    # =========================================================================
    # NEW FEATURES
    # =========================================================================

    # -------------------------------------------------------------------------
    # Custom headers
    # -------------------------------------------------------------------------
    context 'with custom headers' do
      before do
        stub_request(:get, 'http://example.com/')
          .with(headers: { 'X-Custom-Header' => 'my-value', 'Accept' => 'text/html' })
          .to_return(status: 200)
      end

      it 'sends caller-supplied headers on every request' do
        result = FinalRedirectUrl.final_redirect_url(
          'http://example.com/',
          headers: { 'X-Custom-Header' => 'my-value', 'Accept' => 'text/html' }
        )
        expect(result).to eq('http://example.com/')
      end
    end

    context 'when overriding the default User-Agent via headers' do
      before do
        stub_request(:get, 'http://example.com/')
          .with(headers: { 'User-Agent' => 'MyBot/1.0' })
          .to_return(status: 200)
      end

      it 'uses the caller-supplied User-Agent instead of the default' do
        result = FinalRedirectUrl.final_redirect_url(
          'http://example.com/',
          headers: { 'User-Agent' => 'MyBot/1.0' }
        )
        expect(result).to eq('http://example.com/')
      end
    end

    # -------------------------------------------------------------------------
    # Stateful cookies
    # -------------------------------------------------------------------------
    context 'with cookie-gated redirects' do
      before do
        stub_request(:get, 'http://gated.example.com/')
          .to_return(
            status: 302,
            headers: {
              'Location'   => 'http://gated.example.com/destination',
              'Set-Cookie' => 'session=abc123; Path=/; HttpOnly'
            }
          )
        stub_request(:get, 'http://gated.example.com/destination')
          .with(headers: { 'Cookie' => 'session=abc123' })
          .to_return(status: 200)
      end

      it 'injects cookies from Set-Cookie into subsequent redirect requests' do
        result = FinalRedirectUrl.final_redirect_url('http://gated.example.com/')
        expect(result).to eq('http://gated.example.com/destination')
      end
    end

    context 'with multiple Set-Cookie headers across hops' do
      before do
        stub_request(:get, 'http://multi-cookie.example.com/')
          .to_return(
            status: 301,
            headers: {
              'Location'   => 'http://multi-cookie.example.com/step2',
              'Set-Cookie' => 'token=xyz; Path=/'
            }
          )
        stub_request(:get, 'http://multi-cookie.example.com/step2')
          .to_return(
            status: 302,
            headers: {
              'Location'   => 'http://multi-cookie.example.com/final',
              'Set-Cookie' => 'lang=en; Path=/'
            }
          )
        stub_request(:get, 'http://multi-cookie.example.com/final')
          .with(headers: { 'Cookie' => /token=xyz.*lang=en|lang=en.*token=xyz/ })
          .to_return(status: 200)
      end

      it 'accumulates cookies from every hop' do
        result = FinalRedirectUrl.final_redirect_url('http://multi-cookie.example.com/')
        expect(result).to eq('http://multi-cookie.example.com/final')
      end
    end

    # -------------------------------------------------------------------------
    # Timeouts
    # -------------------------------------------------------------------------
    context 'with custom timeouts' do
      before { stub_request(:get, 'http://slow.example.com/').to_return(status: 200) }

      it 'accepts open_timeout and read_timeout without raising' do
        result = FinalRedirectUrl.final_redirect_url(
          'http://slow.example.com/',
          open_timeout: 5,
          read_timeout: 30
        )
        expect(result).to eq('http://slow.example.com/')
      end
    end

    # -------------------------------------------------------------------------
    # verify_ssl
    # -------------------------------------------------------------------------
    context 'with verify_ssl: false' do
      before do
        stub_request(:get, 'https://self-signed.example.com/').to_return(status: 200)
      end

      it 'accepts verify_ssl: false without raising' do
        result = FinalRedirectUrl.final_redirect_url(
          'https://self-signed.example.com/',
          verify_ssl: false
        )
        expect(result).to eq('https://self-signed.example.com/')
      end
    end

    # -------------------------------------------------------------------------
    # Meta-refresh parsing (from counterfind fork concept)
    # -------------------------------------------------------------------------
    context 'with a meta-refresh redirect' do
      before do
        stub_request(:get, 'http://meta.example.com/')
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'text/html; charset=utf-8' },
            body: <<~HTML
              <html>
                <head>
                  <meta http-equiv="refresh" content="0; url=http://final.example.com/">
                </head>
                <body>Redirecting...</body>
              </html>
            HTML
          )
        stub_request(:get, 'http://final.example.com/').to_return(status: 200)
      end

      it 'follows the meta-refresh URL and returns the final destination' do
        expect(FinalRedirectUrl.final_redirect_url('http://meta.example.com/'))
          .to eq('http://final.example.com/')
      end
    end

    context 'with a case-insensitive META http-equiv="REFRESH"' do
      before do
        stub_request(:get, 'http://meta-upper.example.com/')
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'text/html' },
            body: '<html><head><META HTTP-EQUIV="REFRESH" CONTENT="5; URL=http://upper-final.example.com/"></head></html>'
          )
        stub_request(:get, 'http://upper-final.example.com/').to_return(status: 200)
      end

      it 'handles uppercase http-equiv and URL= attributes' do
        expect(FinalRedirectUrl.final_redirect_url('http://meta-upper.example.com/'))
          .to eq('http://upper-final.example.com/')
      end
    end

    context 'with a meta-refresh and a quoted URL' do
      before do
        stub_request(:get, 'http://meta-quoted.example.com/')
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'text/html' },
            body: "<html><head><meta http-equiv='refresh' content=\"0; url='http://quoted-final.example.com/'\"></head></html>"
          )
        stub_request(:get, 'http://quoted-final.example.com/').to_return(status: 200)
      end

      it 'strips surrounding quotes from the meta-refresh URL' do
        expect(FinalRedirectUrl.final_redirect_url('http://meta-quoted.example.com/'))
          .to eq('http://quoted-final.example.com/')
      end
    end

    context 'with a 200 OK page that has no meta-refresh' do
      before do
        stub_request(:get, 'http://normal.example.com/')
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'text/html' },
            body: '<html><head><title>No refresh</title></head><body>Hello</body></html>'
          )
      end

      it 'returns the URL as-is when there is no meta-refresh' do
        expect(FinalRedirectUrl.final_redirect_url('http://normal.example.com/'))
          .to eq('http://normal.example.com/')
      end
    end
  end

  # ===========================================================================
  # .trace
  # ===========================================================================
  describe '.trace' do
    context 'with an invalid URL' do
      it 'returns an empty array' do
        expect(FinalRedirectUrl.trace('not-a-url')).to eq([])
      end
    end

    context 'with a single 200 OK' do
      before { stub_request(:get, 'http://example.com/').to_return(status: 200) }

      it 'returns one Hop with status 200' do
        hops = FinalRedirectUrl.trace('http://example.com/')
        expect(hops.length).to eq(1)
        expect(hops.first).to eq(FinalRedirectUrl::Hop.new(url: 'http://example.com/', status: 200))
      end
    end

    context 'with two redirects before 200 OK' do
      before do
        stub_request(:get, 'http://a.example.com/')
          .to_return(status: 301, headers: { 'Location' => 'http://b.example.com/' })
        stub_request(:get, 'http://b.example.com/')
          .to_return(status: 302, headers: { 'Location' => 'http://c.example.com/' })
        stub_request(:get, 'http://c.example.com/').to_return(status: 200)
      end

      it 'records every hop with its status code' do
        hops = FinalRedirectUrl.trace('http://a.example.com/')
        expect(hops.map(&:url)).to    eq(%w[http://a.example.com/ http://b.example.com/ http://c.example.com/])
        expect(hops.map(&:status)).to eq([301, 302, 200])
      end
    end

    context 'when depth is exhausted mid-chain' do
      before do
        stub_request(:get, 'http://a.example.com/')
          .to_return(status: 301, headers: { 'Location' => 'http://b.example.com/' })
        stub_request(:get, 'http://b.example.com/').to_return(status: 200)
      end

      it 'records the depth-limited hop with status nil' do
        hops = FinalRedirectUrl.trace('http://a.example.com/', depth: 1)
        expect(hops.length).to eq(2)
        expect(hops.first.status).to eq(301)
        expect(hops.last.url).to    eq('http://b.example.com/')
        expect(hops.last.status).to be_nil
      end
    end

    context 'with a meta-refresh followed by a 200 OK' do
      before do
        stub_request(:get, 'http://meta.example.com/')
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'text/html' },
            body: '<html><head><meta http-equiv="refresh" content="0; url=http://dest.example.com/"></head></html>'
          )
        stub_request(:get, 'http://dest.example.com/').to_return(status: 200)
      end

      it 'includes the meta-refresh origin hop with status 200' do
        hops = FinalRedirectUrl.trace('http://meta.example.com/')
        expect(hops.map(&:url)).to    eq(%w[http://meta.example.com/ http://dest.example.com/])
        expect(hops.map(&:status)).to eq([200, 200])
      end
    end

    context 'with cookie-gated redirect' do
      before do
        stub_request(:get, 'http://gate.example.com/')
          .to_return(
            status: 302,
            headers: { 'Location' => 'http://gate.example.com/ok', 'Set-Cookie' => 'sid=s1; Path=/' }
          )
        stub_request(:get, 'http://gate.example.com/ok')
          .with(headers: { 'Cookie' => 'sid=s1' })
          .to_return(status: 200)
      end

      it 'records the full trace including the cookie-gated final hop' do
        hops = FinalRedirectUrl.trace('http://gate.example.com/')
        expect(hops.map(&:url)).to    eq(%w[http://gate.example.com/ http://gate.example.com/ok])
        expect(hops.map(&:status)).to eq([302, 200])
      end
    end
  end
end
