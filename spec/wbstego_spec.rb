require 'spec_helper'

each_sample("wbsteg*.bmp") do |fname|
  describe fname do
    subject{ cli(fname) }

    it { should include("wbStego") }
    it { should include("SuperSecretMessage") }
  end
end
