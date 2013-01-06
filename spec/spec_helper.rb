$:.unshift(File.expand_path("../lib", File.dirname(__FILE__)))
require 'pngsteg'
require 'pngsteg/cli'

SAMPLES_DIR = File.expand_path("../samples", File.dirname(__FILE__))

def each_sample
  Dir[File.join(SAMPLES_DIR, "*_*.png")].each do |fname|
    yield fname.sub(Dir.pwd+'/','')
  end
end
