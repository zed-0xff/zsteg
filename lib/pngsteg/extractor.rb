module PNGSteg
  class Extractor
    # image can be either filename or ZPNG::Image
    def initialize image, params = {}
      @image = image.is_a?(ZPNG::Image) ? image : ZPNG::Image.load(image)
    end

    def extract params = {}
      channels = (Array(params[:channels]) + Array(params[:channel])).compact

      limit = params[:limit].to_i
      limit = 2**32 if limit <= 0

      bits = params[:bits]
      raise "invalid bits value #{bits.inspect}" unless (1..8).include?(bits)
      mask = 2**bits - 1

      data = ''.force_encoding('binary')
      a = []
      @image.each_pixel do |color|
        channels.each do |c|
          value = color.send(c)
          bits.times do |bidx|
            a << ((value & (1<<(bits-bidx-1))) == 0 ? 0 : 1)
          end
        end
        if a.size >= 8
          byte = 0
          if params[:bit_order] == :msb
            8.times{ |i| byte |= (a.shift<<i)}
          else
            8.times{ |i| byte |= (a.shift<<(7-i))}
          end
          #printf "[d] %02x %08b\n", byte, byte
          data << byte.chr
          if data.size >= limit
            print "[limit #{params[:limit]}]".gray
            break
          end
        end
      end
      if params[:strip_tail_zeroes] != false && data[-1,1] == "\x00"
        oldsz = data.size
        data.sub!(/\x00+\Z/,'')
        print "[zerotail #{oldsz-data.size}]".gray
      end
      data
    end
  end
end
