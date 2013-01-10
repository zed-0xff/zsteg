require 'spec_helper'

each_sample("wbstego/*") do |fname|
  describe fname do
    subject{
      if fname['.png']
        cli(fname, "1b,lsb", "-o", "all")
      else
        cli(fname, "1b,lsb")
      end
    }

    it { should include("wbStego") }
    it { should include("SuperSecretMessage") } if fname['noenc']
    if fname['even']
      it { should include("even=true") }
    else
      it { should include("even=false") }
    end

    %w'blowfish twofish cast128 rijndael'.each do |enc|
      it { should match(/#{enc}/i) } if fname[enc]
    end

    it { should include("mix=true") } if fname['mix']
    it { should include("enc=\"wbSteg") } if fname['enc'] && !fname['noenc']
  end
end
