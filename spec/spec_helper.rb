#coding: binary
$:.unshift(File.expand_path("../lib", File.dirname(__FILE__)))
require 'zsteg'

SAMPLES_DIR = File.expand_path("../samples", File.dirname(__FILE__))

def each_sample glob="*.png"
  Dir[File.join(SAMPLES_DIR, glob)].each do |fname|
    yield fname.sub(Dir.pwd+'/','')
  end
end

def sample fname
  fname = File.join(SAMPLES_DIR, fname)
  if block_given?
    yield fname.sub(Dir.pwd+'/','')
  end

  fname
end

def cli *args
  @cli_cache ||= {}
  args.map! do |arg|
    if arg.is_a?(String) && arg[' ']
      # split strings with spaces into arrays
      arg.split(' ')
    else
      arg
    end
  end
  args.flatten!
  @cli_cache[args.inspect] ||=
    begin
      klass =
        if args.first.is_a?(Symbol)
          cli_name = args.shift.to_s
          require "zsteg/cli/#{cli_name}"
          ZSteg::CLI.const_get(cli_name.capitalize)
        else
          ZSteg::CLI
        end
      args << "-qqq"
      args << "--no-color" unless args.any?{|x| x['color']}
      orig_stdout, out = $stdout, ""
      begin
        $stdout = StringIO.new(out)
        klass.new(args).run
      ensure
        $stdout = orig_stdout
      end
      out
    end
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
  config.before :suite do
    Dir[File.join(SAMPLES_DIR, "**", "*.7z")].each do |fname|
      next if File.exist?(fname.sub(/\.7z$/,''))
      system "7z", "x", fname, "-o#{File.dirname(fname)}"
    end
  end
end
