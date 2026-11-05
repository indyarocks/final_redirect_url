# Changelog

All notable changes to this project will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.1.0] – 2026-11-05

### Fork Contributions Integrated
Analysed all six public forks. Two contained work worth considering:

- **counterfind/final_redirect_url** (9 commits ahead): introduced Nokogiri meta-refresh parsing,
  per-request timeouts, and HTTPS via `use_ssl`. The meta-refresh concept was adopted and
  rewritten from scratch (removed `pry`, removed `KNOWN_SHORTENERS`, eliminated the
  thread-unsafe module-level `@final_url`, fixed the deprecated `URI.regexp` call, replaced
  `rescue Exception`, and switched `uri.host` → `uri.to_s` to preserve ports). Architecture
  unchanged.
- **HowardSnowden/final_redirect_url** (4 commits ahead): extracted `get_response` as a named
  method and added explicit SSL cipher configuration. The pattern was incorporated into the
  new `fetch_response` method; the hardcoded cipher list was not adopted (unnecessary for
  modern Ruby/OpenSSL).
- **pilot34, mbv, ymow**: trivial (limit logging, version bump, no changes) — discarded.

### Added
- **`FinalRedirectUrl.trace(url, options)`** — returns `Array<Hop>` documenting every URL and
  HTTP status code visited in the redirect chain. Useful for debugging and link audits.
- **`FinalRedirectUrl::Hop`** struct with `url` (String) and `status` (Integer, nil when depth
  exhausted) attributes.
- **Custom headers** (`options[:headers]`) — pass any HTTP headers (e.g. `User-Agent`, `Accept`,
  `Authorization`) to bypass anti-bot blocks or authenticate requests.
- **Configurable timeouts** — `options[:open_timeout]` and `options[:read_timeout]` default to
  **60 seconds** (up from the previous 10 s hard-coded value).
- **`verify_ssl` option** (`true` by default) — set `verify_ssl: false` to bypass strict SSL
  certificate validation (e.g. for self-signed certificates in development).
- **Stateful cookie handling** — `Set-Cookie` headers from every 3xx response are captured and
  injected as `Cookie` headers into subsequent requests, enabling cookie-gated redirect chains
  to be followed correctly.
- **Meta-refresh parsing** (via Nokogiri, adapted from the `counterfind` fork) — when a 200 OK
  response contains `<meta http-equiv="refresh">`, the gem follows the redirect URL. Handles
  case-insensitive `HTTP-EQUIV`, quoted URLs, and malformed `content` attributes. Only fires
  for `text/html` responses.
- **nokogiri** added as a runtime dependency.

### Changed
- Switched from `HEAD` to `GET` requests. `GET` is required so that the response body is
  available for meta-refresh parsing; it also improves compatibility with servers that reject
  `HEAD` with 405.
- `final_redirect_url` now delegates to `trace` internally, eliminating duplicated logic.
- Default timeouts raised from 10 s to **60 s**.

### No Open Issues
All issues were resolved in v2.0.0. No new open issues exist at the time of this release.

---

## [2.0.0] – 2026-11-05

### Breaking Changes
- **Minimum Ruby version raised to 3.0.** Ruby 2.x is no longer supported.
- Private helper methods (`valid_url?`, `resolve_redirects`, `fetch_response`, `absolute_url`) are now
  truly private (defined inside `class << self` with `private`). Calling them from outside the module
  now raises `NoMethodError`. This was always the intended behaviour; previous versions accidentally
  exposed them as public singleton methods (fixes [#4][i4]).

### Added
- **GitHub Actions CI** replacing the removed Travis CI configuration. The matrix tests Ruby 3.0,
  3.1, 3.2, and 3.3 on every push and pull request.
- **WebMock** test dependency — the full test suite now runs without any real network connections.
- `CHANGELOG.md` (this file).
- Gem metadata fields (`homepage_uri`, `source_code_uri`, `changelog_uri`).

### Fixed
- **Port numbers are now preserved** in final URLs. For example,
  `final_redirect_url("http://localhost:3000/path")` now correctly returns
  `"http://localhost:3000/path"` instead of `"http://localhost/path"` (fixes [#6][i6]).
- **Redirect depth limit now works correctly.** When the hop limit was reached the gem previously
  returned a bare `String` to `url_string_from_uri`, causing a `NoMethodError`. The limit guard now
  returns the current `URI` object (fixes [#2][i2]).
- **Relative-path redirects now carry forward the original host's port.** The gem uses `URI.join`
  instead of manual string concatenation, so a redirect `Location: /new-path` from
  `http://localhost:3000/old-path` resolves to `http://localhost:3000/new-path`.
- **Non-redirect, non-200 responses** (403, 404, 500 …) are now handled gracefully: the gem returns
  the last reachable URL rather than crashing with a `TypeError` on a nil `Location` header.
- **HTTPS support** — connections now set `use_ssl = true` when the scheme is `https`. Previously
  only plain-HTTP URLs worked.
- **`URI::regexp` removed** — the old `is_valid_url?` used the deprecated (and Ruby-3.x-removed)
  `URI::regexp`. Replaced with `URI.parse` + `URI::HTTP` class check.
- **`rescue Exception`** replaced with `rescue StandardError` to avoid masking signals and other
  non-recoverable errors.
- **`$stdout`** used instead of bare `STDOUT` constant (style/frozen-string consistency).

### Changed
- Switched from `Net::HTTP.get_response` (GET) to explicit `Net::HTTP::Head` requests. HEAD is
  sufficient for redirect resolution and avoids downloading response bodies.
- Added `open_timeout` and `read_timeout` (10 s each) to prevent indefinite hangs.
- Added a `User-Agent` header so servers that require it don't return unexpected responses.

### Known Limitations
- JavaScript- and AMP-based redirects (e.g. certain Google News AMP URLs — [#3][i3]) require a
  headless browser and are outside the scope of this gem. The gem returns the last HTTP-level
  reachable URL in such cases.

[2.1.0]: https://github.com/indyarocks/final_redirect_url/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/indyarocks/final_redirect_url/compare/v0.1.1...v2.0.0
[i2]: https://github.com/indyarocks/final_redirect_url/issues/2
[i3]: https://github.com/indyarocks/final_redirect_url/issues/3
[i4]: https://github.com/indyarocks/final_redirect_url/issues/4
[i6]: https://github.com/indyarocks/final_redirect_url/issues/6
