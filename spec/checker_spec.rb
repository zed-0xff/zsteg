require 'spec_helper'

include ZSteg

describe Checker do
  each_sample do |fname|
    describe fname do
      describe "#check" do
        before :all do
          @checker = Checker.new(fname)
          orig_stdout, @out = $stdout, ""
          begin
            $stdout = StringIO.new(@out)
            @results = @checker.check
          ensure
            $stdout = orig_stdout
          end
        end

#        it "should be quiet by default" do
#          @out.should == ""
#        end

        it "returned results should be equal to #results" do
          @results.should == @checker.results
        end

        it "should return array of results" do
          @results.should be_instance_of(Array)
        end

        describe "results" do
          it "should not have text results shorter than #{Checker::DEFAULT_MIN_STR_LEN}" do
            @results.each do |result|
              case result
              when Result::WholeText
                result.text.size.should(be >= Checker::DEFAULT_MIN_STR_LEN-2, result.inspect)
              when Result::Text
                result.text.size.should(be >= Checker::DEFAULT_MIN_STR_LEN, result.inspect)
              end
            end
          end
        end
      end
    end
  end
end
