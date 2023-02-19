#coding: utf-8
require 'stringio'
require 'zlib'
require 'set'

require 'zsteg/checker/scanline_checker'
require 'zsteg/checker/steganography_png'
require 'zsteg/checker/wbstego'
require 'zsteg/checker/zlib'

module ZSteg
  class Checker
    attr_accessor :params, :channels, :verbose, :results

    DEFAULT_BITS         = [1,2,3,4]
    DEFAULT_ORDER        = 'auto'
    DEFAULT_LIMIT        = 256         # number of checked bytes, 0 = no limit
    DEFAULT_EXTRA_CHECKS = true
    DEFAULT_MIN_STR_LEN  = 8

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
      @file_cmd = FileCmd.new if params.fetch(:file, true)
      @results = []

      @params[:bits]  ||= DEFAULT_BITS
      @params[:order] ||= DEFAULT_ORDER
      @params[:limit] ||= DEFAULT_LIMIT

      if @params[:min_str_len]
        @min_str_len = @min_wholetext_len = @params[:min_str_len]
      else
        @min_str_len = DEFAULT_MIN_STR_LEN
        @min_wholetext_len = @min_str_len - 2
      end
      @strings_re = /[\x20-\x7e\r\n\t]{#@min_str_len,}/

      @extra_checks = params.fetch(:extra_checks, DEFAULT_EXTRA_CHECKS)
    end

    private

#   # catch Kernel#print for easier verbosity handling
#    def print *args
#      Kernel.print(*args) if @verbose >= 0
#    end
#
#    # catch Kernel#printf for easier verbosity handling
#    def printf *args
#      Kernel.printf(*args) if @verbose >= 0
#    end
#
#    # catch Kernel#puts for easier verbosity handling
#    def puts *args
#      Kernel.puts(*args) if @verbose >= 0
#    end

    public

    def check
      @found_anything = false
      @file_cmd.start! if @file_cmd

      if @extra_checks
        check_extradata
        check_metadata
        check_imagedata
      end

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
            if params[:pixel_align] == :all
              [false, true].each do |pixel_align|
                # skip cases when output will be identical for pixel_align true/false
                next if pixel_align && (8%bits) == 0
                p1 = @params.merge bits: bits, order: order, prime: prime, pixel_align: pixel_align
                if order[/b/i]
                  # byte iterator does not need channels
                  check_channels nil, p1
                else
                  channels.each{ |c| check_channels c, p1 }
                end
              end
            else
              p1 = @params.merge bits: bits, order: order, prime: prime
              if order[/b/i]
                # byte iterator does not need channels
                check_channels nil, p1
              else
                channels.each{ |c| check_channels c, p1 }
              end
            end
          end
        end
      end

      if @found_anything
        print "\r" + " "*20 + "\r" if @need_cr
      else
        puts "\r[=] nothing :(" + " "*20 # line cleanup
      end

      if @extra_checks
        Analyzer.new(@image).analyze!
      end

      # return everything found if this method was called from some code
      @results
    ensure
      @file_cmd.stop! if @file_cmd
    end

    def check_imagedata
      h = { :title => "imagedata", :show_title => true }
      process_result @image.imagedata, h
    end

    def check_extradata
      # accessing imagedata implicitly unpacks zlib stream
      # zlib stream may contain extradata
      if @image.imagedata.size > (t=@image.scanlines.map(&:size).inject(&:+))
        @found_anything = true
        data = @image.imagedata[t..-1]
        title = "extradata:imagedata"
        show_title title, :bright_red
        process_result data, :special => true, :title => title
      end

      if @image.extradata.any?
        @found_anything = true
        @image.extradata.each_with_index do |data,idx|
          title = "extradata:#{idx}"
          show_title title, :bright_red
          process_result data, :special => true, :title => title
        end
      end

      if data = ScanlineChecker.check_image(@image, @params)
        @found_anything = true
        title = "scanline extradata"
        show_title title, :bright_red
        process_result data, :special => true, :title => title
      end

      if r = SteganographyPNG.check_image(@image, @params)
        @found_anything = true
        title = "image"
        show_title title, :bright_red
        process_result nil, title: title, result: r
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

      bits_tag << "p" if params[:pixel_align]

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

      if p1[:invert]
        data.size.times{ |i| data.setbyte(i, data.getbyte(i)^0xff) }
      end

      @need_cr = !process_result(data, p1) # carriage return needed?
      @found_anything ||= !@need_cr
    end

    def show_title title, color = :gray
      printf "\r%-20s.. ".send(color), title
      $stdout.flush
    end

    def show_result result, params
      case result
      when Array
        result.each_with_index do |r,idx|
          # empty title for multiple results from same title
          show_title(" ") if idx > 0
          puts r
        end
      when nil, false
        # do nothing?
      else
        puts result
      end
    end

    # returns true if was any output
    def process_result data, params
      verbose = params[:special] ? [@verbose,1.5].max : @verbose

      result = nil
      if data
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
      elsif !(result = params[:result])
        raise "[?] No data nor result"
      end

      case verbose
      when -999..0
        # verbosity=0: only show result if anything interesting found
        if result && !result.is_a?(Result::OneChar)
          show_title params[:title] if params[:show_title]
          show_result result, params
          return true
        else
          return false
        end
      when 1
        # verbosity=1: if anything interesting found show result & hexdump
        return false unless result
      else
        # verbosity>1: always show hexdump
      end

      show_title params[:title] if params[:show_title]

      if params[:special]
        puts result.is_a?(Result::PartialText) ? nil : result
      else
        show_result result, params
      end
      if data && data.size > 0 && !result.is_a?(Result::OneChar) && !result.is_a?(Result::WholeText)
        # newline if no results and want hexdump
        puts if !result || result == []
        limit = (params[:limit] || @params[:limit]).to_i
        t = limit > 0 ? data[0,limit] : data
        print ZPNG::Hexdump.dump(t){ |x| x.prepend(" "*4) }
      end
      true
    end

    CAMOUFLAGE_SIG1 = "\x00\x00".force_encoding('binary')
    CAMOUFLAGE_SIG2 = "\xed\xcd\x01".force_encoding('binary')

    def data2result data, params
      if one_char?(data)
        return Result::OneChar.new(data[0,1], data.size)
      end

      if idx = data.index('OPENSTEGO')
        io = StringIO.new(data)
        io.seek(idx+9)
        return Result::OpenStego.read(io)
      end

      # only in extradata
      if params[:title]['extradata']
        if data[0,2] == CAMOUFLAGE_SIG1 && data[3,3] == CAMOUFLAGE_SIG2
          return Result::Camouflage.new(data)
        end
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

      if data.size >= @min_wholetext_len && data =~ /\A[\x20-\x7e\r\n\t]+\Z/
        # whole ASCII
        return Result::WholeText.new(data, 0)
      end

      if @file_cmd && (r = @file_cmd.data2result(data))
        return r
      end

      if r = Checker::Zlib.check_data(data)
        return r
      end

      case params.fetch(:strings, :first)
      when :all
        r=[]
        data.scan(@strings_re) do
          r << Result::PartialText.from_matchdata($~)
        end
        return r if r.any?
      when :first
        if data[@strings_re]
          return Result::PartialText.from_matchdata($~)
        end
      when :longest
        r=[]
        data.scan(@strings_re){ r << $~ }
        return Result::PartialText.from_matchdata(r.sort_by(&:size).last) if r.any?
      end

      # utf-8 string matching, may be slow, may throw exceptions
#      begin
#        t = data.
#          encode('UTF-16', 'UTF-8', :invalid => :replace, :replace => '').
#          encode!('UTF-8', 'UTF-16')
#        r = t.scan(/\p{Word}{#{DEFAULT_MIN_STR_LEN},}/)
#        r if r.any?
#      rescue
#      end
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
