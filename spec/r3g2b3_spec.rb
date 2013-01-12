require 'spec_helper'

sample("r3g2b3.png") do |fname|
  describe fname do
    it "contains hidden message" do
      cli(fname, "-c","r3g2b3").should include("astley.3gp")
    end
  end
end
