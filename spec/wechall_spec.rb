require 'spec_helper'

WECHALL = {
  'stegano1.bmp' => "Look what the hex-edit revealed: passwd:steganoI"
}

each_sample("wechall/*.bmp") do |fname|
  describe fname do
    subject{ cli(fname) }

    it { should include WECHALL[File.basename(fname)] }
  end
end

sample("wechall/5ZMGcCLxpcpsru03.png") do |fname|
  describe fname do
    it "extracts hidden image" do
      tname = "tmp/wechall.tmp.png"
      File.unlink(tname) if File.exist?(tname)
      cli(:mask, fname, "--green 00000010 -O #{tname}")
      img1 = ZPNG::Image.load tname
      img2 = ZPNG::Image.load fname.sub(/\.png$/,".g00000010.png")
      img1.should == img2
    end
  end
end
