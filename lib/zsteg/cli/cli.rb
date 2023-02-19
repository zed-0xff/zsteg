require 'optparse'

module ZSteg
  class CLI::Cli
    DEFAULT_ACTIONS = %w'check'

    def initialize argv = ARGV
      @argv = argv
    end

    def run
      @actions = []
      @options = {
        verbose: 0,
        limit: Checker::DEFAULT_LIMIT,
        order: Checker::DEFAULT_ORDER,
        step: 1, 
        ystep: 1, 
      }
      optparser = OptionParser.new do |opts|
        opts.banner = "Usage: zsteg [options] filename.png [param_string]"
        opts.separator ""

        opts.on "-a", "--all", "try all known methods" do
          @options[:prime] = :all
          @options[:order] = :all
          @options[:pixel_align] = :all
          @options[:bits]  = (1..8).to_a
          # specifying --all on command line explicitly enables extra checks
          @options[:extra_checks] = true
        end

        opts.on "-E", "--extract NAME", "extract specified payload, NAME is like '1b,rgb,lsb'" do |x|
          @options[:verbose] = -2 # silent ZPNG warnings
          @actions << [:extract, x]
        end

        #################################################################################
        opts.separator "\nIteration/extraction params:"
        #################################################################################

        opts.on("-o", "--order X", /all|auto|[bxy,]+/i,
                "pixel iteration order (default: '#{@options[:order]}')",
                "valid values: ALL,xy,yx,XY,YX,xY,Xy,bY,...",
        ){ |x| @options[:order] = x.split(',') }

        opts.on("-c", "--channels X", /[rgba,1-8]+/,
                "channels (R/G/B/A) or any combination, comma separated",
                "valid values: r,g,b,a,rg,bgr,rgba,r3g2b3,..."
        ) do |x|
          @options[:channels] = x.split(',')
          # specifying channels on command line disables extra checks
          @options[:extra_checks] = false
        end

        opts.on("-b", "--bits N", "number of bits, single int value or '1,3,5' or range '1-8'",
                "advanced: specify individual bits like '00001110' or '0x88'"
        ) do |x|
          a = []
          if x[-1] == 'p'
            @options[:pixel_align] = true
            x = x[0..-2]
          end
          x = '1-8' if x == 'all'
          x.split(',').each do |x1|
            if x1['-']
              t = x1.split('-')
              a << Range.new(parse_bits(t[0]), parse_bits(t[1])).to_a
            else
              a << parse_bits(x1)
            end
          end
          @options[:bits] = a.flatten.uniq
          # specifying bits on command line disables extra checks
          @options[:extra_checks] = false
        end

        opts.on "--lsb", "least significant bit comes first" do
          @options[:bit_order] = :lsb
        end
        opts.on "--msb", "most significant bit comes first" do
          @options[:bit_order] = :msb
        end

        opts.on "-P", "--prime", "analyze/extract only prime bytes/pixels" do
          @options[:prime] = true
          # specifying prime on command line disables extra checks
          @options[:extra_checks] = false
        end

        opts.on("--shift N", Integer, "prepend N zero bits"){ |x| @options[:shift] = x }
        #opts.on("--step N",  Integer, "step")               { |x| @options[:step] = x }
        opts.on("--invert", "invert bits (XOR 0xff)")       { @options[:invert] = true }

        opts.on "--pixel-align", "pixel-align hidden data" do
          @options[:pixel_align] = true
        end

        #################################################################################
        opts.separator "\nAnalysis params:"
        #################################################################################

        opts.on("-l", "--limit N", Integer, "limit bytes checked, 0 = no limit (default: #{@options[:limit]})"){ |n| @options[:limit] = n }

        opts.separator ""

        opts.on "--[no-]file", "use 'file' command to detect data type (default: YES)" do |x|
          @options[:file] = x
        end

        # TODO
#        opts.on "--[no-]binwalk", "use 'binwalk' command to detect data type (default: NO)" do |x|
#          @options[:binwalk] = x
#        end

        opts.on "--no-strings", "disable ASCII strings finding (default: enabled)" do |x|
          @options[:strings] = false
        end
        opts.on "-s", "--strings X", %w'first all longest none no',
          "ASCII strings find mode: first, all, longest, none",
          "(default: first)" do |x|
          @options[:strings] = x[0] == 'n' ? false : x.downcase.to_sym
        end
        opts.on "-n", "--min-str-len X", Integer,
          "minimum string length (default: #{Checker::DEFAULT_MIN_STR_LEN})" do |x|
          @options[:min_str_len] = x
        end

        opts.separator ""
        opts.on "-v", "--verbose", "Run verbosely (can be used multiple times)" do |v|
          @options[:verbose] += 1
        end
        opts.on "-q", "--quiet", "Silent any warnings (can be used multiple times)" do |v|
          @options[:verbose] -= 1
        end
        opts.on "-C", "--[no-]color", "Force (or disable) color output (default: auto)" do |x|
          if defined?(Rainbow) && Rainbow.respond_to?(:enabled=)
            Rainbow.enabled = x
          else
            Sickill::Rainbow.enabled = x
          end
        end
        opts.separator "\nPARAMS SHORTCUT\n"+
          "\tzsteg fname.png 2b,b,lsb,xy  ==>  --bits 2 --channel b --lsb --order xy"
      end

      if (argv = optparser.parse(@argv)).empty?
        puts optparser.help
        return
      end

      @actions = DEFAULT_ACTIONS if @actions.empty?

      argv.each do |arg|
        if arg[','] && !File.exist?(arg)
          @options.merge!(decode_param_string(arg))
          argv.delete arg
        end
      end

      argv.each_with_index do |fname,idx|
        if argv.size > 1 && @options[:verbose] >= 0
          puts if idx > 0
          puts "[.] #{fname}".green
        end
        next unless @img=load_image(@fname=fname)

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

    def load_image fname
      if File.directory?(fname)
        puts "[?] #{fname} is a directory".yellow
      else
        ZPNG::Image.load(fname, :verbose => @options[:verbose]+1)
      end
    rescue ZPNG::Exception, Errno::ENOENT
      puts "[!] #{$!.inspect}".red
    end

    def parse_bits x
      case x
        when '1', 1             # catch NOT A BINARY MASK early
          1
        when /^0x[0-9a-f]+$/i   # hex,     mask
          0x100 + x.to_i(16)
        when /^(?:0b)?[01]+$/i  # binary,  mask
          0x100 + x.to_i(2)
        when /^\d+$/            # decimal, number of bits
          x.to_i
        else
          raise "invalid bits value: #{x.inspect}"
      end
    end

    def decode_param_string s
      h = {}
      s.split(',').each do |x|
        case x
        when 'lsb'
          h[:bit_order] = :lsb
        when 'msb'
          h[:bit_order] = :msb
        when /^(\d)b$/, /^b(\d+)$/
          h[:bits] = parse_bits($1)
        when /^(\d)bp$/, /^b(\d+)p$/
          h[:bits] = parse_bits($1)
          h[:pixel_align] = true
        when /\A[rgba]+\Z/
          h[:channels] = [x]
        when /\Axy|yx|yb|by\Z/i
          h[:order] = x
        when 'prime'
          h[:prime] = true
        when 'zlib'
          h[:zlib] = true
        else
          raise "uknown param #{x.inspect}"
        end
      end
      h
    end

    def _extract_data name
      case name
      when /scanline/
        Checker::ScanlineChecker.check_image @img
      when /extradata:imagedata/
        @img.imagedata[@img.scanlines.map(&:size).inject(&:+)..-1]
      when /extradata:(\d+)/
        # accessing imagedata implicitly unpacks zlib stream
        # zlib stream may contain extradata
        @img.imagedata
        @img.extradata[$1.to_i]
      when /imagedata/
        @img.imagedata
      else
        h = decode_param_string name
        h[:limit] = @options[:limit] if @options[:limit] != Checker::DEFAULT_LIMIT
        Extractor.new(@img, @options).extract(h)
      end
    end

    ###########################################################################
    # actions

    def check
      Checker.new(@img, @options).check
    end

    def extract name
      data = _extract_data(name)
      if name['zlib']
        if r = Checker::Zlib.check_data(data)
          data = r.data
        else
          raise "cannot decompress with zlib"
        end
      end
      print data
    end

  end
end
