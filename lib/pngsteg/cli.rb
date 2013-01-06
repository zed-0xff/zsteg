require 'optparse'
require 'awesome_print'

module PNGSteg
  class CLI
    DEFAULT_ACTIONS = %w'check'
    DEFAULT_LIMIT   = 256

    def initialize argv = ARGV
      @argv = argv
    end

    def run
      @actions = []
      @options = { :verbose => 0, :limit => DEFAULT_LIMIT, :bits => [1,2,3,4,5,6] }
      optparser = OptionParser.new do |opts|
        opts.banner = "Usage: pngsteg [options] filename.png"
        opts.separator ""

        opts.on("-C", "--channels X", /[rgba,]+/,
                "channels (R/G/B/A) or any combination, comma separated",
                "valid values: r,g,b,a,rg,rgb,bgr,rgba,..."
        ){ |x| @options[:channels] = x.split(',') }

        opts.on("-L", "--limit N", Integer,
                "limit bytes checked, 0 = no limit (default: #{DEFAULT_LIMIT})"
        ){ |n| @options[:limit] = n }

        opts.on("-b", "--bits N", /[\d,]+/,
                "number of bits (1..8), single value or comma separated"
        ){ |n| @options[:bits] = n.split(',').map(&:to_i) }

        opts.separator ""
        opts.on "-v", "--verbose", "Run verbosely (can be used multiple times)" do |v|
          @options[:verbose] += 1
        end
        opts.on "-q", "--quiet", "Silent any warnings (can be used multiple times)" do |v|
          @options[:verbose] -= 1
        end
      end

      if (argv = optparser.parse(@argv)).empty?
        puts optparser.help
        return
      end

      @actions = DEFAULT_ACTIONS if @actions.empty?

      argv.each_with_index do |fname,idx|
        if argv.size > 1 && @options[:verbose] >= 0
          puts if idx > 0
          puts "[.] #{fname}".color(:green)
        end
        @fname = fname

        @actions.each do |action|
          if action.is_a?(Array)
            self.send(*action) if self.respond_to?(action.first)
          else
            self.send(action) if self.respond_to?(action)
          end
        end
      end
    rescue Errno::EPIPE
      # output interrupt, f.ex. when piping output to a 'head' command
      # prevents a 'Broken pipe - <STDOUT> (Errno::EPIPE)' message
    end

    def check
      puts "[.] #@fname".green
      Checker.new(@fname, @options).check
    end

  end
end
