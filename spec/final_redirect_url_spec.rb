require "spec_helper"

RSpec.describe FinalRedirectUrl do
  it "has a version number" do
    expect(FinalRedirectUrl::VERSION).not_to be nil
  end

  context "with invalid url" do
    it "returns error" do
      # If invalid URL, returns 404 Not Found
    end
  end

  context "with no redirects" do
    it "returns the original url" do
      # expect(false).to eq(true)
    end
  end

  context 'with single redirect' do
    it 'returns the redirected url' do
      # The returned url should not respond with 301
    end
  end

  context 'with multiple redirects' do
    it 'returns the final redirected url' do
      # The returned url should not respond with 301
    end
  end
end
