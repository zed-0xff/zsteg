require 'spec_helper'

describe "samples/plte1.png" do
  subject{ cli(sample("plte1.png")) }
  it { should include("Zip archive data") }

  describe "--extract" do
    it "should extract zip file from PLTE with type check" do
      r = cli(sample("plte1.png"), "--extract", "chunk:1:PLTE")
      md5(r).should == 'e125f0f322fd1e99050dba688968385c'
    end
    it "should extract zip file from PLTE without type check" do
      r = cli(sample("plte1.png"), "--extract", "chunk:1")
      md5(r).should == 'e125f0f322fd1e99050dba688968385c'
    end
  end
end
