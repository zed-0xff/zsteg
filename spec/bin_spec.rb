require 'spec_helper'

Dir['bin/*'].each do |fname|
  describe fname do
    it "should run" do
      system "#{fname} > /dev/null"
      $?.should be_success
    end
  end
end
