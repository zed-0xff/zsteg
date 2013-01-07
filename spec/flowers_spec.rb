require 'spec_helper'

each_sample("flower_*.png") do |fname|
  describe fname do
    it "should reveal secret message" do
      cli(
        fname, "--limit", "64", "--bits", "1,2,3,4,5,6"
      ).should include("SuperSecretMessage")
    end
  end
end
