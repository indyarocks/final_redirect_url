# FinalRedirectUrl

Ruby gem to get a final redirect url for any given url.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'final_redirect_url'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install final_redirect_url

## Usage
NOTE: The input url must start with http/https protocol.

```ruby
FinalRedirectUrl.final_redirect_url('http://www.google.com')
```

From IRB:
```ruby
2.4.0 :001 > require 'final_redirect_url'
 => true
 
# No protocol provided
2.4.0 :002 > FinalRedirectUrl.final_redirect_url('www.google.com')
 => ""

# With valid protocol
2.4.0 :003 > FinalRedirectUrl.final_redirect_url('http://google.com')
redirected to http://www.google.co.in/?gfe_rd=cr&ei=J-cOWYKhCKb98wfOsb2ADA
 => "http://www.google.co.in/?gfe_rd=cr&ei=J-cOWYKhCKb98wfOsb2ADA"

# URI with invalid response
2.4.0 :004 > FinalRedirectUrl.final_redirect_url('http://api.google.com')
E, [2017-05-07T14:52:39.497203 #1358] ERROR -- : bad URI(is not URI?):
 => ""
```

Usually the gem checks for redirect upto 10 depth level. However you can pass `{depth: 20}` to check redirects upto `20` depth.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/indyarocks/final_redirect_url. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

