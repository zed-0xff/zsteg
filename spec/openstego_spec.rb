require 'spec_helper'

each_sample("openstego_*png") do |fname|
  describe fname do
    subject{ cli(fname) }

    it { should include("OpenStego") }
  end
end

# filenames of hidden files

describe "samples/openstego_q2.png" do
  subject{ cli(sample("openstego_q2.png")) }
  it { should include("flag.txt") }
end

describe "samples/openstego_send.png" do
  subject{ cli(sample("openstego_send.png")) }
  it { should include("secret.jpg") }
end
