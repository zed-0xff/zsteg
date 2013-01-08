require 'spec_helper'

each_sample("camouflage*.png") do |fname|
  describe fname do
    it "should detect Camouflage" do
      cli(fname).should include("Camouflage")
    end
  end
end
