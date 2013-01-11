require 'spec_helper'

sample("prime.png") do |fname|
  describe fname do
    it "contains prime-encoded message" do
      cli(fname, "--prime").should include("48300:TG9yZW0gaXBzdW")
    end
  end
end
