# FinalRedirectUrl

[![CI](https://github.com/indyarocks/final_redirect_url/actions/workflows/ci.yml/badge.svg)](https://github.com/indyarocks/final_redirect_url/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/final_redirect_url.svg)](https://badge.fury.io/rb/final_redirect_url)

Ruby gem that follows HTTP/HTTPS redirects and returns the final destination URL.

## Requirements

- Ruby >= 3.0

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'final_redirect_url'
```

Then run:

```
$ bundle install
```

Or install directly:

```
$ gem install final_redirect_url
```

## Usage

The input URL **must** include the `http://` or `https://` scheme.

```ruby
require 'final_redirect_url'

# Simple redirect following
FinalRedirectUrl.final_redirect_url('http://google.com')
# => "https://www.google.com/"

# Ports are preserved
FinalRedirectUrl.final_redirect_url('http://localhost:3000/items/42')
# => "http://localhost:3000/items/42"

# Custom redirect depth (default: 10)
FinalRedirectUrl.final_redirect_url('http://example.com', depth: 5)
# => "http://final.example.com/"

# Invalid / missing protocol → empty string
FinalRedirectUrl.final_redirect_url('www.example.com')
# => ""
```

## Limitations

- **JavaScript / AMP redirects** (e.g. some Google News AMP URLs) are not followed. These require a
  headless browser. The gem returns the last HTTP-reachable URL in such cases.
- Redirects are followed using HTTP `HEAD` requests. Servers that reject `HEAD` with `405 Method Not Allowed`
  may not resolve correctly.

## Contributing

Bug reports and pull requests are welcome on GitHub at <https://github.com/indyarocks/final_redirect_url>.
This project is intended to be a safe, welcoming space for collaboration, and contributors are expected
to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
