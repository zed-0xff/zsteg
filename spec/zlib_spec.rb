require 'spec_helper'

describe "samples/ndh2k12_sp113.bmp" do
  subject{ cli(sample("ndh2k12_sp113.bmp"), "-o", "all") }
  it { should include("%PDF-1.4") }
end
