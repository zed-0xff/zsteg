require 'stringio'
require 'zlib'
require 'set'

module ZSteg
  class Checker
    attr_accessor :params, :channels, :verbose, :results

    MIN_TEXT_LENGTH      = 8
    MIN_WHOLETEXT_LENGTH = 6           # when entire data is a text
    DEFAULT_BITS         = [1,2,3,4]
    DEFAULT_ORDER        = 'auto'
    DEFAULT_LIMIT        = 256         # number of checked bytes, 0 = no limit

    # image can be either filename or ZPNG::Image
    def initialize image, params = {}
      @params = params
      @cache = {}; @wastitles = Set.new
      @image = image.is_a?(ZPNG::Image) ? image : ZPNG::Image.load(image)
      @extractor = Extractor.new(@image, params)
      @channels = params[:channels] ||
        if @image.alpha_used?
          %w'r g b a rgb bgr rgba abgr'
        else
          %w'r g b rgb bgr'
        end
      @verbose = params[:verbose] || -2
      @file_cmd = FileCmd.new
      @results = []

      @params[:bits]  ||= DEFAULT_BITS
      @params[:order] ||= DEFAULT_ORDER
      @params[:limit] ||= DEFAULT_LIMIT
    end

    private

    # catch Kernel#print for easier verbosity handling
    def print *args
      Kernel.print(*args) if @verbose >= 0
    end

    # catch Kernel#printf for easier verbosity handling
    def printf *args
      Kernel.printf(*args) if @verbose >= 0
    end

    # catch Kernel#puts for easier verbosity handling
    def puts *args
      Kernel.puts(*args) if @verbose >= 0
    end

    public

    def check
      @found_anything = false
      @file_cmd.start!

      check_extradata
      check_metadata
      check_imagedata

      if @image.format == :bmp
        case params[:order].to_s.downcase
        when /all/
          params[:order] = %w'bY xY xy yx XY YX Xy yX Yx'
        when /auto/
          params[:order] = %w'bY xY'
        end
      else
        case params[:order].to_s.downcase
        when /all/
          params[:order] = %w'xy yx XY YX Xy yX xY Yx'
        when /auto/
          params[:order] = 'xy'
        end
      end

      Array(params[:order]).uniq.each do |order|
        (params[:prime] == :all ? [false,true] : [params[:prime]]).each do |prime|
          Array(params[:bits]).uniq.each do |bits|
            p1 = @params.merge :bits => bits, :order => order, :prime => prime
            if order[/b/i]
              # byte iterator does not need channels
              check_channels nil, p1
            else
              channels.each{ |c| check_channels c, p1 }
            end
          end
        end
      end

      if @found_anything
        print "\r" + " "*20 + "\r" if @need_cr
      else
        puts "\r[=] nothing :(" + " "*20 # line cleanup
      end

      @results
    ensure
      @file_cmd.stop!
    end

    def check_imagedata
      h = { :title => "imagedata", :show_title => true }
      process_result @image.imagedata, h
    end

    def check_extradata
      if @image.extradata
        @found_anything = true
        title = "data after IEND"
        show_title title, :bright_red
        process_result @image.extradata, :special => true, :title => title
      end
    end

    def check_metadata
      @image.metadata.each do |k,v|
        @found_anything = true
        show_title(title = "meta #{k}")
        process_result v, :special => true, :title => title
      end
    end

    def check_channels channels, params
      unless params[:bit_order]
        check_channels(channels, params.merge(:bit_order => :lsb))
        check_channels(channels, params.merge(:bit_order => :msb))
        return
      end

      p1 = params.clone

      # number of bits
      # equals to params[:bits] if in range 1..8
      # otherwise equals to number of 1's, like 0b1000_0001
      nbits = p1[:bits] <= 8 ? p1[:bits] : (p1[:bits]&0xff).to_s(2).count("1")

      show_bits = true
      # channels is a String
      if channels
        p1[:channels] =
          if channels[1] && channels[1] =~ /\A\d\Z/
            # 'r3g2b3'
            a=[]
            cbits = 0
            (channels.size/2).times do |i|
              a << (t=channels[i*2,2])
              cbits += t[1].to_i
            end
            show_bits = false
            @max_hidden_size = cbits * @image.width
            a
          else
            # 'rgb'
            a = channels.chars.to_a
            @max_hidden_size = a.size * @image.width * nbits
            a
          end
        # p1[:channels] is an Array
      elsif params[:order] =~ /b/i
        # byte extractor
        @max_hidden_size = @image.scanlines[0].decoded_bytes.size * nbits
      else
        raise "invalid params #{params.inspect}"
      end
      @max_hidden_size *= @image.height/8

      bits_tag =
        if show_bits
          if params[:bits] > 0x100
            if params[:bits].to_s(2) =~ /(1{1,8})$/
              # mask => number of bits
              "b#{$1.size}"
            else
              # mask
              "b#{(params[:bits]&0xff).to_s(2)}"
            end
          else
            # number of bits
            "b#{params[:bits]}"
          end
        end

      title = [
        bits_tag,
        channels,
        params[:bit_order],
        params[:order],
        params[:prime] ? 'prime' : nil
      ].compact.join(',')

      return if @wastitles.include?(title)
      @wastitles << title

      show_title title

      p1[:title] = title
      data = @extractor.extract p1

      @need_cr = !process_result(data, p1) # carriage return needed?
      @found_anything ||= !@need_cr
    end

    def show_title title, color = :gray
      printf "\r%-20s.. ".send(color), title
      $stdout.flush
    end

    # returns true if was any output
    def process_result data, params
      verbose = params[:special] ? [@verbose,1.5].max : @verbose

      if @cache[data]
        if verbose > 1
          puts "[same as #{@cache[data].inspect}]".gray
          return true
        else
          # silent return
          return false
        end
      end

      # TODO: store hash of data for large datas
      @cache[data] = params[:title]

      if result = data2result(data, params)
        @results << result
      end

      case verbose
      when -999..0
        # verbosity=0: only show result if anything interesting found
        if result && !result.is_a?(Result::OneChar)
          show_title params[:title] if params[:show_title]
          puts result
          return true
        else
          return false
        end
      when 1
        # verbosity=1: if anything interesting found show result & hexdump
        return false unless result
      end

      # verbosity>1: always show hexdump
      show_title params[:title] if params[:show_title]

      if params[:special]
        puts result.is_a?(Result::PartialText) ? nil : result
      else
        puts result
      end
      if data.size > 0 && !result.is_a?(Result::OneChar) && !result.is_a?(Result::WholeText)
        print ZPNG::Hexdump.dump(data){ |x| x.prepend(" "*4) }
      end
      true
    end

    def data2result data, params
      if one_char?(data)
        return Result::OneChar.new(data[0,1], data.size)
      end

      if idx = data.index('OPENSTEGO')
        io = StringIO.new(data)
        io.seek(idx+9)
        return Result::OpenStego.read(io)
      end

      if data[0,2] == "\x00\x00" && data[3,3] == "\xed\xcd\x01"
        return Result::Camouflage.new(data)
      end

      # only BMP & 1-bit-per-channel
      if params[:bits] == 1 && params[:bit_order] == :lsb
        if x = WBStego.check(data, params.merge(
                                                :image => @image,
                                                :max_hidden_size => @max_hidden_size
                            ))
          return x
        end
      end

      if data.size >= MIN_WHOLETEXT_LENGTH && data =~ /\A[\x20-\x7e\r\n\t]+\Z/
        # whole ASCII
        return Result::WholeText.new(data, 0)
      end

      # XXX TODO refactor params hack
      if !params.key?(:no_check_file) && (r = @file_cmd.data2result(data))
        return r
      end

      # try to find zlib
      # http://blog.w3challs.com/index.php?post/2012/03/25/NDH2k12-Prequals-We-are-looking-for-a-real-hacker-Wallpaper-image
      # http://blog.w3challs.com/public/ndh2k12_prequalls/sp113.bmp
      # XXX TODO refactor params hack
      if !params.key?(:no_check_zlib) && (idx = data.index(/\x78[\x9c\xda\x01]/))
        begin
#          x = Zlib::Inflate.inflate(data[idx,4096])
          zi = Zlib::Inflate.new(Zlib::MAX_WBITS)
          x = zi.inflate data[idx..-1]
          # decompress OK
          return Result::Zlib.new x, idx if x.size > 2
        rescue Zlib::BufError
          # tried to decompress, but got EOF - need more data
          return Result::Zlib.new x, idx
        rescue Zlib::DataError, Zlib::NeedDict
          # not a zlib
        ensure
          zi.close if zi && !zi.closed?
        end
      end

      if (r=data[/[\x20-\x7e\r\n\t]{#{MIN_TEXT_LENGTH},}/])
        return Result::PartialText.new(r, data.index(r))
      end
    end

    private

    # returns true if String s consists of one repeating character
    # performance-optimized
    # 16Mb string = 0.7s on Core i5 1.7GHz
    def one_char? s
      (s =~ /\A(.)\1+\Z/m) == 0
    end
  end
end
