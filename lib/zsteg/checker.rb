require 'stringio'
require 'zlib'

module ZSteg
  class Checker
    attr_accessor :params, :channels, :verbose

    MIN_TEXT_LENGTH = 8

    # image can be either filename or ZPNG::Image
    def initialize image, params = {}
      @params = params
      @cache = {}
      @image = image.is_a?(ZPNG::Image) ? image : ZPNG::Image.load(image)
      @extractor = Extractor.new(@image, params)
      @channels = params[:channels] ||
        if @image.alpha_used?
          %w'r g b a rgb bgr rgba abgr'
        else
          %w'r g b rgb bgr'
        end
      @verbose = params[:verbose] || 0
      @file_cmd = FileCmd.new
    end

    def check
      @found_anything = false
      @file_cmd.start!

      check_extradata
      check_metadata

      case params[:order].to_s.downcase
      when /all/
        params[:order] = %w'xy yx XY YX Xy yX xY Yx'
      when /auto/
        params[:order] = @image.format == :bmp ? %w'bY xY' : 'xy'
      end

      Array(params[:order]).uniq.each do |order|
        Array(params[:bits]).uniq.each do |bits|
          if order[/b/i]
            # byte iterator does not need channels
            check_channels nil, @params.merge( :bits => bits, :order => order )
          else
            channels.each do |c|
              check_channels c, @params.merge( :bits => bits, :order => order )
            end
          end
        end
      end

      if @found_anything
        print "\r" + " "*20 + "\r" if @need_cr
      else
        puts "\r[=] nothing :(" + " "*20 # line cleanup
      end
    ensure
      @file_cmd.stop!
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

      title = ["#{params[:bits]}b",channels,params[:bit_order],params[:order]].compact.join(',')
      show_title title

      p1 = params.clone
      p1.delete :channel
      p1[:title] = title

      if channels
        p1[:channels] = channels.split('')
        @max_hidden_size = p1[:channels].size*@image.width
      elsif params[:order] =~ /b/i
        # byte extractor
        @max_hidden_size = @image.scanlines[0].decoded_bytes.size
      else
        raise "invalid params #{params.inspect}"
      end
      @max_hidden_size *= p1[:bits]*@image.height/8

      data = @extractor.extract p1

      @need_cr = !process_result(data, p1) # carriage return needed?
      @found_anything ||= !@need_cr
    end

    def show_title title, color = :gray
      printf "\r[.] %-14s.. ".send(color), title
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

      result = data2result data, params

      case verbose
      when -999..0
        # verbosity=0: only show result if anything interesting found
        if result && !result.is_a?(Result::OneChar)
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

      if data =~ /\A[\x20-\x7e\r\n\t]+\Z/
        # whole ASCII
        return Result::WholeText.new(data, 0)
      end

      if r = @file_cmd.check_data(data)
        return Result::FileCmd.new(r, data)
      end

      # http://blog.w3challs.com/index.php?post/2012/03/25/NDH2k12-Prequals-We-are-looking-for-a-real-hacker-Wallpaper-image
      # http://blog.w3challs.com/public/ndh2k12_prequalls/sp113.bmp
      if idx = data.index(/\x78[\x9c\xda\x01]/)
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
