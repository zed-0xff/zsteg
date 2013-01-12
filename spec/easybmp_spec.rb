require 'spec_helper'

sample("EasyBMP.bmp") do |fname|
  describe fname do
    it "contains hidden message" do
      cli(fname, "-o","xy").should include("EasyBMPstego")
    end
  end
end
