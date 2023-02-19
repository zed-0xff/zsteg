require 'spec_helper'

# https://github.com/pedrooaugusto/steganography-png
each_sample("steganography-png/*.png") do |fname|
  describe fname do
    it "should reveal secret message" do
      r = cli fname, "--limit", "64", "-a", "--no-file"
      r.should include("SteganographyPNG")
      r.should include(ZSteg::Checker::SteganographyPNG::URL)
      r.should_not include("ZSteg::Checker::SteganographyPNG")
    end
  end
end
