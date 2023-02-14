require 'spec_helper'

sample("ndh2k12_sp113.bmp") do |fname|
  describe fname do
    subject{ cli(fname, "-o", "all") }
    it { should include("%PDF-1.4") }

    describe "--extract" do
      subject{ cli(fname, "--extract b1,rgb,lsb,yx") }

      it { should_not include "%PDF-1.4" }
      it { subject.size.should == 546750 }
    end

    describe "--extract zlib" do
      subject{ cli(fname, "--extract b1,rgb,lsb,yx,zlib") }

      it { should include "%PDF-1.4" }
      it { subject.size.should == 202386 }
    end
  end
end
