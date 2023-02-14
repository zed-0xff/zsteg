# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'juwelier'
Juwelier::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "zsteg"
  gem.homepage = "http://github.com/zed-0xff/zsteg"
  gem.license = "MIT"
  gem.summary = %Q{Detect stegano-hidden data in PNG & BMP files.}
  #gem.description = %Q{TODO: longer description of your gem}
  gem.email = "zed.0xff@gmail.com"
  gem.authors = ["Andrey \"Zed\" Zaikin"]
  #gem.executables = %w'zsteg'
  gem.files.include "lib/**/*.rb"
  gem.files.include "bin/*"
  gem.files.exclude "samples/**/*"
  # dependencies defined in Gemfile
end
Juwelier::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :default => :spec

desc "build readme"
task :readme do
  require 'erb'
  tpl = File.read('README.md.tpl').gsub(/^%\s+(.+)/) do |x|
    x.sub! /^%/,''
    "<%= run(\"#{x}\") %>"
  end
  def run cmd
    cmd.strip!
    puts "[.] #{cmd} ..."
    r = "    # #{cmd}\n\n"
    cmd.sub! /^zsteg/,"../bin/zsteg"
    lines = `#{cmd}`.sub(/\A\n+/m,'').split("\n")
    lines.map!{ |l| l.split("\r").last } # emulate CR's
    lines = lines[0,25] + ['...'] if lines.size > 50
    r << lines.map{|x| "    #{x}"}.join("\n").rstrip
    r << "\n"
  end
  Dir.chdir 'samples'
  result = ERB.new(tpl,nil,'%>').result
  Dir.chdir '..'
  File.open('README.md','w'){ |f| f << result }
end

Rake::Task[:console].clear

# from /usr/local/lib64/ruby/gems/1.9.1/gems/jeweler-1.8.4/lib/jeweler/tasks.rb
desc "Start IRB with all runtime dependencies loaded"
task :console, [:script] do |t,args|
  dirs = ['./ext', './lib'].select { |dir| File.directory?(dir) }

  original_load_path = $LOAD_PATH

  cmd = if File.exist?('Gemfile')
          require 'bundler'
          Bundler.setup(:default)
        end

  # add the project code directories
  $LOAD_PATH.unshift(*dirs)

  # clear ARGV so IRB is not confused
  ARGV.clear

  require 'irb'

  # ZZZ actually added only these 2 lines
  require 'zsteg'
  include ZSteg

  # set the optional script to run
  IRB.conf[:SCRIPT] = args.script
  IRB.start

  # return the $LOAD_PATH to it's original state
  $LOAD_PATH.reject! { |path| !(original_load_path.include?(path)) }
end
