# FinalRedirectUrl

[![CI](https://github.com/indyarocks/final_redirect_url/actions/workflows/ci.yml/badge.svg)](https://github.com/indyarocks/final_redirect_url/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/final_redirect_url.svg)](https://badge.fury.io/rb/final_redirect_url)

Ruby gem that follows HTTP/HTTPS redirects — including `<meta http-equiv="refresh">` and
cookie-gated chains — and returns the final destination URL.

## Requirements

- Ruby >= 3.0
- [Nokogiri](https://nokogiri.org) (bundled as a runtime dependency for meta-refresh parsing)

## Installation

### From RubyGems.org (recommended)

```ruby
gem 'final_redirect_url'
```

```
$ bundle install
```

or

```
$ gem install final_redirect_url
```

### From GitHub Packages

```ruby
# Gemfile
source "https://rubygems.pkg.github.com/indyarocks" do
  gem 'final_redirect_url'
end
```

Authenticate with a GitHub token that has `read:packages` scope:

```
$ bundle config https://rubygems.pkg.github.com/indyarocks USERNAME:GITHUB_TOKEN
```

## Basic usage

```ruby
require 'final_redirect_url'

FinalRedirectUrl.final_redirect_url('http://google.com')
# => "https://www.google.com/"

# Invalid / missing protocol → empty string
FinalRedirectUrl.final_redirect_url('www.example.com')
# => ""
```

## Options

All options are passed as a second argument hash:

| Option         | Type    | Default | Description |
|----------------|---------|---------|-------------|
| `:depth`        | Integer | `10`    | Maximum redirect hops to follow |
| `:open_timeout` | Integer | `60`    | TCP connect timeout in seconds |
| `:read_timeout` | Integer | `60`    | Read timeout in seconds |
| `:verify_ssl`   | Boolean | `true`  | Enforce SSL certificate validation |
| `:headers`      | Hash    | `{}`    | Extra HTTP headers sent with every request |

```ruby
# Limit redirect depth
FinalRedirectUrl.final_redirect_url('http://example.com', depth: 5)

# Custom timeouts (seconds)
FinalRedirectUrl.final_redirect_url('http://slow.example.com', open_timeout: 5, read_timeout: 30)

# Bypass SSL certificate verification (e.g. self-signed certs in development)
FinalRedirectUrl.final_redirect_url('https://self-signed.local', verify_ssl: false)

# Custom headers — override User-Agent or add Authorization / Accept
FinalRedirectUrl.final_redirect_url(
  'http://bot-protected.example.com',
  headers: {
    'User-Agent' => 'Mozilla/5.0 (compatible; MyApp/1.0)',
    'Accept'     => 'text/html'
  }
)
```

## Redirect trace

`FinalRedirectUrl.trace` returns every hop in the chain as an array of `Hop` structs.
Each `Hop` has a `url` (String) and a `status` (Integer, or `nil` when the depth limit is
reached before a request is made).

```ruby
hops = FinalRedirectUrl.trace('http://hop1.example.com')

hops.each { |hop| puts "#{hop.status}  #{hop.url}" }
# 301  http://hop1.example.com/
# 302  http://hop2.example.com/
# 200  https://final.example.com/

hops.last.url    # => "https://final.example.com/"
hops.last.status # => 200
```

`trace` accepts the same options as `final_redirect_url`.

## Meta-refresh support

When the gem reaches a `200 OK` response whose body contains a
`<meta http-equiv="refresh" content="N; url=...">` tag, it follows that URL as if it were an
HTTP redirect. Case-insensitive attribute matching and quoted URL values are both handled.

```ruby
# Page at http://meta.example.com/ contains:
#   <meta http-equiv="refresh" content="0; url=http://final.example.com/">
FinalRedirectUrl.final_redirect_url('http://meta.example.com/')
# => "http://final.example.com/"
```

## Cookie-gated redirects

`Set-Cookie` headers from every `3xx` response are captured and re-sent as `Cookie` headers on
all subsequent requests in the same chain, allowing the gem to follow redirects that require an
active session cookie.

## Limitations

- **JavaScript / AMP redirects** (e.g. some Google News AMP URLs) require a headless browser
  and are outside the scope of this gem. The gem returns the last HTTP-reachable URL in such
  cases.
- Servers that reject `HEAD` requests with `405 Method Not Allowed` are handled correctly
  because the gem uses `GET` for all requests.

## Contributing

Bug reports and pull requests are welcome on GitHub at
<https://github.com/indyarocks/final_redirect_url>. Contributors are expected to adhere to the
[Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

Available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
