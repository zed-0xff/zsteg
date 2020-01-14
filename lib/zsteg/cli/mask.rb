require 'optparse'
require 'set'
require 'digest/md5'

module ZSteg
  class CLI::Mask
    DEFAULT_ACTIONS = %w'mask'

    COMMON_MASKS = [
      0b0000_0001, 0b0000_0011, 0b0000_0111, 0b0000_1111,
                   0b0000_0010, 0b0000_0100, 0b0000_1000,
      0b0001_0000, 0b0010_0000, 0b0100_0000, 0b1000_0000,
    ]

    CHANNELS = [:r, :g, :b, :a]

    def initialize argv = ARGV
      @argv = argv
      @wasfiles = Set.new
      @cache = {}
    end

    def run
      @actions = []
      @options = {
        :verbose   => 0,
        :masks     => Hash.new{|k,v| k[v] = [] },
        :normalize => true
      }
      optparser = OptionParser.new do |opts|
        opts.banner = "Usage: zsteg-mask [options] filename.png [param_string]"
        opts.separator ""

        opts.on("-m", "--mask M", "apply mask to all channels",
                "mask: 0-255 OR 0x00-0xff OR 00000000-11111111",
                "OR 'all' for all common masks"
        ){ |x| @options[:masks][:all] << parse_mask(x) }

        opts.on("-R", "--red M", "red channel mask"){ |x|
          @options[:masks][:r] << parse_mask(x) }

        opts.on("-G", "--green M", "green channel mask"){ |x|
          @options[:masks][:g] << parse_mask(x) }

        opts.on("-B", "--blue M", "blue channel mask"){ |x|
          @options[:masks][:b] << parse_mask(x) }

        opts.on("-A", "--alpha M", "alpha channel mask"){ |x|
          @options[:masks][:a] << parse_mask(x) }

        opts.separator ""

        opts.on "-a", "--all", "try all common masks (default)" do
          @options[:try_all] = true
        end

        opts.separator ""

        opts.on "-N", "--[no-]normalize", "normalize color value after applying mask",
          "(default: normalize)" do |x|
          @options[:normalize] = x
        end

        opts.on "-O", "--outfile FILENAME", "output single result to specified file" do |x|
          @options[:outfile] = x
        end

        opts.on "-D", "--dir DIRNAME", "output multiple results to specified dir" do |x|
          @options[:dir] = x
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
      end

      if (argv = optparser.parse(@argv)).empty?
        puts optparser.help
        return
      end

      # default :all mask if none specified
      if @options[:masks].empty?
        @options[:try_all] = true
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
        next unless @image=load_image(@fname=fname)

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

    def parse_mask x
      case x
      when /0x/i
        x.to_i(16)
      when /^[01]{8}$/
        x.to_i(2)
      when /^\d{1,3}$/
        x.to_i
      when /^all$/
        COMMON_MASKS
      else raise "invalid mask #{x.inspect}"
      end
    end

    def load_image fname
      if File.directory?(fname)
        puts "[?] #{fname} is a directory".yellow
      else
        ZPNG::Image.load(fname)
      end
    rescue ZPNG::Exception, Errno::ENOENT
      puts "[!] #{$!.inspect}".red
    end

    ###########################################################################
    # actions

    def mask
      masks = @options[:masks]
      masks.each{ |k,v| v.flatten!; v.uniq! }

      if @options[:try_all]
        # try all common masks
        masks = masks[:all] || []
        masks = COMMON_MASKS if masks.empty?
        masks.each{ |x| run_masker x,x,x,x    }
        masks.each{ |x| run_masker x,0,0,0xff }
        masks.each{ |x| run_masker 0,x,0,0xff }
        masks.each{ |x| run_masker 0,0,x,0xff }
        if @image.alpha_used?
          masks.each{ |x| run_masker 0,0,0,x    }
        end

      elsif CHANNELS.all?{ |c| !masks[c] || masks[c].empty? }
        # no specific channels
        masks[:all].each do |x|
          run_masker x,x,x,x
        end

      else
        # specific channels
        CHANNELS.each{ |x| masks[x] = [x==:a ? 0xff : 0] if !masks[x] || masks[x].empty? }
        masks[:r].each do |r|
          masks[:g].each do |g|
            masks[:b].each do |b|
              if @image.alpha_used?
                masks[:a].each do |a|
                  run_masker r,g,b,a
                end
              else
                run_masker r,g,b,0xff
              end
            end
          end
        end
      end
    end

    private

    def _all_pixels_same img
      sl0 = img.scanlines.first
      return false if sl0.pixels.to_a.uniq.size != 1

      db0 = sl0.decoded_bytes
      img.scanlines[1..-1].each do |sl|
        return false if sl.decoded_bytes != db0
      end
      true
    end

    def run_masker r,g,b,a
      params = @options.dup
      params[:masks] = params[:masks].merge( :r => r, :g => g, :b => b, :a => a)
      fname,color = @options[:outfile],nil
      fname,color = masks2fname(params[:masks]) unless fname

      print "[.] #{fname.send(color||:to_s)} .. "

      raise "already written to #{fname}" if @wasfiles.include?(fname)
      @wasfiles << fname

      dst = Masker.new(@image, params).mask

      if _all_pixels_same(dst)
        puts "all pixels = #{dst[0,0].inspect}".gray
        return
      end

      data = dst.export

      md5 = Digest::MD5.hexdigest(data)
      if @cache[md5]
        puts "same as #{File.basename(@cache[md5])}".gray
        return
      end
      @cache[md5] = fname

      File.open(fname, "wb"){ |f| f<<data }
      printf "%6d bytes\n".green, File.size(fname)
    end

    def masks2fname masks
      masks = masks.dup.delete_if{ |k,v| !CHANNELS.include?(k) }
      ext   = File.extname(@fname)
      bname = @fname.chomp(ext)
      color = nil
      raise "TODO" if masks.values.all?(&:nil?)
      if masks.values.uniq.size == 1
        tail = "%08b" % masks.values.first
      else
        a = []
        masks.each do |c,mask|
          a << "%s%08b" % [c,mask] if mask && mask != 0
        end
        raise "TODO" if a.empty?
        a -= ['a11111111'] if a.size > 1 # fully opaque alpha is OK
        if a.size == 1
          color =
            case a[0][0,1]
            when 'r'; :red
            when 'g'; :green
            when 'b'; :blue
            when 'a'; :gray
            else nil
            end
        end
        tail = a.join("_")
      end

      # we always export as PNG
      fname = [bname, "mask_#{tail}", "png"].join('.')
      fname = File.join(@options[:dir], File.basename(fname)) if @options[:dir]
      [fname, color]
    end

  end
end
