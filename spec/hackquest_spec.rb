require 'spec_helper'

sample("hackquest/square.bmp") do |fname|
  describe fname do
    subject{ cli(fname, "-b 10") }

    it { should include "thesecretpasswordis:jedimaster" }
  end
end

sample("hackquest/crypt.bmp") do |fname|
  describe fname do
    subject{ cli(fname, "-b 10") }

    it { should include "111Hello" }
  end
end

