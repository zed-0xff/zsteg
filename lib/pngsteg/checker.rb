module PNGSteg
  class Checker
    attr_accessor :params, :channels

    # image can be either filename or ZPNG::Image
    def initialize image, params = {}
      @params = params
      @extractor = Extractor.new(image, params)
      @cache = {}
      @image = image.is_a?(ZPNG::Image) ? image : ZPNG::Image.load(image)
      @channels = params[:channels] ||
        if @image.alpha_used?
          %w'r g b a rgb bgr rgba abgr'
        else
          %w'r g b rgb bgr'
        end
    end

    def check
      Array(params[:bits]).each do |bits|
        channels.each do |c|
          check_channels c, @params.merge( :bits => bits )
        end
      end
    end

    def check_channels channels, params
      unless params[:bit_order]
        check_channels(channels, params.merge(:bit_order => :lsb))
        check_channels(channels, params.merge(:bit_order => :msb))
        return
      end

      title = "#{params[:bits]}b, #{channels}, #{params[:bit_order]}"
      printf "[.] %-10s .. ", title

      p1 = params.clone
      p1.delete :channel
      p1[:channels] = channels.split('')
      data = @extractor.extract p1
      if @cache[data]
        puts "(same as #{@cache[data].inspect})".gray
        return
      end

      @cache[data] = title

      if data.split('').uniq.size == 1
        printf " = #{data.size} bytes, each = %s (0x%02x)\n".yellow, data[0].inspect, data[0].ord
      else
        puts " = #{data.size} bytes".green
        puts ZPNG::Hexdump.dump(data)
      end
    end

  end
end
