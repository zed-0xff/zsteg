require 'stringio'
require 'zlib'

module PNGSteg
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
    end

    def check
      @found_anything = false

      check_extradata
      check_metadata

      if params[:order].to_s.downcase['all']
        params[:order] = %w'xy yx XY YX Xy yX xY Yx'
      end

      Array(params[:order]).uniq.each do |order|
        Array(params[:bits]).uniq.each do |bits|
          channels.each do |c|
            check_channels c, @params.merge( :bits => bits, :order => order )
          end
        end
      end

      if @found_anything
        print "\r" + " "*20 + "\r" if @need_cr
      else
        puts "\r[=] nothing :(" + " "*20 # line cleanup
      end
    end

    def check_extradata
      if @image.extradata
        @found_anything = true
        title = "data after IEND"
        puts "[.] #{title}: ".red
        process_result @image.extradata, :allow_raw => true, :title => title
      end
    end

    def check_metadata
      @image.metadata.each do |k,v|
        @found_anything = true
        show_title(title = "meta #{k}")
        process_result v, :allow_raw => true, :title => title
      end
    end

    def check_channels channels, params
      unless params[:bit_order]
        check_channels(channels, params.merge(:bit_order => :lsb))
        check_channels(channels, params.merge(:bit_order => :msb))
        return
      end

      title = "#{params[:bits]}b,#{channels},#{params[:bit_order]},#{params[:order]}"
      show_title title

      p1 = params.clone
      p1.delete :channel
      p1[:channels] = channels.split('')
      p1[:title] = title
      data = @extractor.extract p1

      @need_cr = !process_result(data, p1) # carriage return needed?
      @found_anything ||= !@need_cr
    end

    def show_title title
      printf "\r[.] %-14s.. ", title
      $stdout.flush
    end

    # returns true if was any output
    def process_result data, params
      verbose = params[:allow_raw] ? [@verbose,1.5].max : @verbose

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

      result = data2result data

      case verbose
      when -999..0
        # verbosity=0: only show result if anything interesting found
        if result
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

      if one_char?(data)
        printf " = #{data.size} bytes, each = %s (0x%02x)\n".gray,
          data[0].inspect, data[0].ord
        return true
      else
        #puts " = #{data.size} bytes"
        if result
          puts result
          return true if verbose == 1.5
        end
        if data.size > 0
          if data =~ /\A[\x20-\x7e\r\n\t]\Z/
            # text-only data
            p data
          else
            # binary data
            s = ZPNG::Hexdump.dump(data){ |x| x.prepend(" "*4) }
            print s
            #print params[:allow_raw] ? s.red : s
          end
        end
      end
      true
    end

    def data2result data
      if idx = data.index('OPENSTEGO')
        io = StringIO.new(data)
        io.seek(idx+9)
        return Result::OpenStego.read(io)
      end

      # http://blog.w3challs.com/index.php?post/2012/03/25/NDH2k12-Prequals-We-are-looking-for-a-real-hacker-Wallpaper-image
      # http://blog.w3challs.com/public/ndh2k12_prequalls/sp113.bmp
      if idx = data.index(/\x78[\x9c\xda\x01]/)
        begin
#          x = Zlib::Inflate.inflate(data[idx,4096])
          zi = Zlib::Inflate.new(Zlib::MAX_WBITS)
          x = zi.inflate data[idx..-1]
          # decompress OK
          return Result::Zlib.new idx, x
        rescue Zlib::BufError
          # tried to decompress, but got EOF - need more data
          return Result::Zlib.new idx
        rescue Zlib::DataError, Zlib::NeedDict
          # not a zlib
        ensure
          zi.close if zi && !zi.closed?
        end
      end

      if (r=data[/[\x20-\x7e\r\n\t]{#{MIN_TEXT_LENGTH},}/]) && !one_char?(r)
        return Result::Text.new(r)
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
