require 'spec_helper'

sample('polictf2012_f200.bmp') do |fname|
  describe fname do
    it "should detect hidden BMP" do
      cli(fname).should include("PC bitmap, Windows 3.x format, 500 x 277 x 24")
    end

    describe "hidden BMP #1" do
      before(:all) do
        @data = cli(fname, "--extract", "4b,lsb,bY")
      end

      it "should be 416816 bytes" do
        @data.size.should == 416816
      end

      it "should have BMP header" do
        @data[0,2].should == "BM"
      end

      it "should have 7zip after BMP" do
        @data.index("7z").should == 2005
      end

      describe "deeper" do
        before(:all) do
          @tname = File.join("tmp", File.basename(fname) + ".bmp")
          File.open(@tname, "wb"){ |f| f<<@data }
        end

        it "should detect 7z & BMP" do
          out = cli(@tname)
          out.should include('7-zip archive')
          out.should include('PC bitmap, Windows 3.x format, 100 x 55 x 24')
        end

        describe "hidden BMP #2" do
          before(:all) do
            @data2 = cli(@tname, "--extract", "2b,lsb,bY")
          end

          it "should be 103875 bytes" do
            @data2.size.should == 103875
          end

          describe "deeper" do
            before(:all) do
              @tname2 = File.join("tmp", File.basename(@tname) + ".bmp")
              File.open(@tname2, "wb"){ |f| f<<@data2 }
            end

            it "should detect text" do
              out = cli(@tname2)
              out.should include('sticazziantanieancoraunavoltacomesefossestato')
            end
          end
        end
      end
    end
  end
end
