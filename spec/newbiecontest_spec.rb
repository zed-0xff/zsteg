require 'spec_helper'

# scanline extradata
sample("newbiecontest/alph1-surprise.bmp") do |fname|
  describe fname do
    subject{ cli(fname) }

    it { should include "PE32 executable" }
    it { should include "MS Windows" }
    it { should include "is program canno" }

    describe "--extract" do
      subject{ cli(fname, "--extract scanline") }

      it { should include "MessageBoxA" }
      it { should include "PVUAC PY HCHY UCYL AOPCISV WJHXY JDVYZJI YXH NIDSYRFBRCASVMFWVY" }
    end
  end
end
