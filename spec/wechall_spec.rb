require 'spec_helper'

WECHALL = {
  'stegano1.bmp' => "Look what the hex-edit revealed: passwd:steganoI"
}

each_sample("wechall/*") do |fname|
  describe fname do
    subject{ cli(fname) }

    it { should include WECHALL[File.basename(fname)] }
  end
end
