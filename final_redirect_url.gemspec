lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'final_redirect_url/version'

Gem::Specification.new do |spec|
  spec.name          = 'final_redirect_url'
  spec.version       = FinalRedirectUrl::VERSION
  spec.authors       = ['Chandan Jhunjhunwal']
  spec.email         = ['chandan.jhun@gmail.com']

  spec.summary       = 'Get the final redirect URL for any given URL.'
  spec.description   = 'Follows HTTP/HTTPS redirects (including meta-refresh, cookie-gated ' \
                       'redirects, relative paths, and non-standard ports) to resolve the ' \
                       'final destination URL. Provides a trace method for full hop inspection.'
  spec.homepage      = 'https://github.com/indyarocks/final_redirect_url'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.0'

  spec.metadata['homepage_uri']    = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri']   = "#{spec.homepage}/blob/master/CHANGELOG.md"
  spec.metadata['github_repo']     = spec.homepage

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'nokogiri', '~> 1.0'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake',    '~> 13.0'
  spec.add_development_dependency 'rspec',   '~> 3.0'
  spec.add_development_dependency 'webmock', '~> 3.0'
end
