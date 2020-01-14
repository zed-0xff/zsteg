#coding: binary
require 'optparse'
require 'stringio'
require 'set'

module ZSteg
  class CLI::Reflow
    DEFAULT_ACTIONS = %w'reflow'

    def initialize argv = ARGV
      @argv = argv
      @cache = {}
      @wasfiles = Set.new
    end

    def run
      @actions = []
      @options = {
        :verbose   => 0,
      }
      optparser = OptionParser.new do |opts|
        opts.banner = "Usage: #{File.basename($0)} [options] filename.png [param_string]"
        opts.separator ""

        opts.on( "-W", "--width X", "reflow to specified width(s)",
                                    "single value: '999', range: '100-200'",
                                    "or comma-separated: '100,200,300-350'"
        ) do |x|
#          if @options[:heights]
#            STDERR.puts "[!] width _OR_ height can be set".red
#            exit 1
#          end
          @options[:widths] = parse_dimension(x)
        end

        opts.on "-H", "--height X", "reflow to specified height(s)" do |x|
#          if @options[:widths]
#            STDERR.puts "[!] width _OR_ height can be set".red
#            exit 1
#          end
          @options[:heights] = parse_dimension(x)
        end

        opts.separator ""

        opts.on "-a", "--all", "try all possible sizes" do
          @options[:try_all] = true
        end

        opts.on "-r", "--rewrite", "just rewrite the header, keeping imagedata as-is" do
          @options[:rewrite] = true
        end

        opts.separator ""

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

    def parse_dimension s
      s.split(',').map do |x|
        case x
        when /\A\d+\Z/        # single value
          x.to_i
        when /-/              # range
          Range.new(*x.split('-').map(&:to_i)).to_a
        end
      end.flatten.uniq
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

    def reflow
      if @image.format != :bmp
        STDERR.puts "[!] only BMP format supported for now!"
        return
      end

      sl = @image.scanlines.first
      @bpp = sl.bpp
      @old_significant_sl_bytes = (sl.width*sl.bpp/8.0).ceil
      @old_total_sl_bytes       = sl.size

      if @options[:heights]
        @options[:heights].each do |h|
          t = 1.0*@image.width*@image.height/h
          t.floor.upto(t.ceil).each do |w|
            next if @options[:widths] && !@options[:widths].include?(w)
            _reflow w,h
          end
        end
      elsif @options[:widths]
        @options[:widths].each do |w|
          h = @image.width*@image.height/w
          _reflow w,h
        end
      elsif @options[:try_all]
        # enum all
        2.upto(@image.width*@image.height/2) do |w|
          h = @image.width*@image.height/w
          _reflow w,h
        end
      else
        # smart all
        w = 4
        loop do
          h = @image.width*@image.height/w
          break if h < 4
          _reflow w,h
          w += 1
        end
      end
    end

    private

    def _gen_fname w,h
      ext = @fname[/\.\w{3}$/].to_s
      fname = "%s.reflow_%05dx%05d%s" % [@fname.chomp(ext), w, h, ext]
      fname = File.join(@options[:dir], File.basename(fname)) if @options[:dir]
      fname
    end

    def _reflow w,h
      fname = @options[:outfile] || _gen_fname(w,h)
      raise "already written to #{fname}" if @wasfiles.include?(fname)
      @wasfiles << fname

      new_significant_sl_bytes = (w*@bpp/8.0).ceil
      padding = "\x00" * (4-new_significant_sl_bytes%4)
      padding = "" if padding.size == 4

#      p @old_significant_sl_bytes
#      p @old_total_sl_bytes
#      p new_significant_sl_bytes
#      p padding

      puts "[.] #{fname} .."
      File.open(@fname, "rb") do |fi|
        File.open(fname, "wb") do |fo|
          # 2 bytes - "BM" signature
          # 4 bytes - the size of the BMP file in bytes
          # 2 bytes - reserved
          # 2 bytes - reserved
          fo.write fi.read(2+4+2+2)

          # 4 bytes - imagedata offset
          data = fi.read(4)
          imagedata_offset = data.unpack('V').first
          fo.write data

          # 4 bytes - BITMAPINFOHEADER.biSize    (keep)
          # 4 bytes - BITMAPINFOHEADER.biWidth   (rewrite)
          # 4 bytes - BITMAPINFOHEADER.biHeight  (rewrite)
          data = fi.read(4+4+4)
          fo.write(data[0,4] + [w,h].pack("V2")) # write new size

          if @options[:rewrite]
            IO.copy_stream fi, fo
          else
            # copy remaining header bytes
            fo.write fi.read(imagedata_offset-fi.tell)

            # FIXME: if scanline sizes differ in BITS, not bytes...

            # scanline padding needs to be respected...
            imagedata = StringIO.new
            @image.height.times do
              data = fi.read @old_total_sl_bytes
              imagedata << data[0, @old_significant_sl_bytes]
              #p data[@old_significant_sl_bytes..-1]
            end
            imagedata << fi.read # read extradata, if any

            imagedata.rewind
            imagedata_start = fo.tell
            h.times do
              fo << imagedata.read(new_significant_sl_bytes)
              fo << padding
            end
            file_size = fo.tell
            imagedata_size = fo.tell - imagedata_start
            fo << imagedata.read # write extradata, if any

            # write new BITMAPFILEHEADER.bfSize
            fo.seek 2
            fo.write [file_size].pack('V')

            # write new BITMAPINFOHEADER.biSizeImage
            fo.seek 14+20 # BITMAPFILEHEADER::SIZE + 20
            fo.write [imagedata_size].pack('V')
          end
        end
      end
    end

  end
end
