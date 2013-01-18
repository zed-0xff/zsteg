require 'spec_helper'

sample("Steganography_original.png") do |fname|
  describe fname do
    it "extracts hidden image" do
      tname = "tmp/mask.tmp.png"
      File.unlink(tname) if File.exist?(tname)
      cli(:mask, fname, "-m 00000011 -O #{tname}")
      img1 = ZPNG::Image.load tname
      img2 = ZPNG::Image.load fname.sub(/\.png$/,".00000011.png")
      img1.should == img2
    end
  end
end
