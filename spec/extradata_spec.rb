require 'spec_helper'

describe "samples/extradata.png" do
  subject{ cli(sample("extradata.png")) }
  it { should include("foobar1") }
  it { should include("foobar2") }
  it { should include("foobar3") }

  describe "--extract" do
    before do
      @out = subject
    end
    it "should extract all" do
      keys = []
      @out.split(/[\r\n]+/).each do |line|
        if line[/foobar\d/]
          keys << line.split.first
        end
      end
      keys.size.should == 3
      r = cli(sample("extradata.png"), *keys.map{|k| "--extract #{k}"} )
      r.should include("foobar1")
      r.should include("foobar2")
      r.should include("foobar3")
      r.size.should == 7*3
    end
  end
end
