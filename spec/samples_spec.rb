require 'spec_helper'

each_sample do |fname|
  describe fname do
    it "should pew-pew" do
      orig_stdout, out = $stdout, ""
      begin
        $stdout = StringIO.new(out)
        lambda{
          PNGSteg::CLI.new([fname, "--limit", "64"]).run
        }.should_not raise_error
      ensure
        $stdout = orig_stdout
      end
      out.should include("SuperSecret")
    end
  end
end
