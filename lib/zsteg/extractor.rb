module ZSteg
  class Extractor
    # image can be either filename or ZPNG::Image
    def initialize image, params = {}
      @image = image.is_a?(ZPNG::Image) ? image : ZPNG::Image.load(image)
      @verbose = params[:verbose]
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
      coord_iterator(params[:order]) do |x,y|
        color = @image[x,y]

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
            print "[limit #{params[:limit]}]".gray if @verbose > 1
            break
          end
        end
      end
      if params[:strip_tail_zeroes] != false && data[-1,1] == "\x00"
        oldsz = data.size
        data.sub!(/\x00+\Z/,'')
        print "[zerotail #{oldsz-data.size}]".gray if @verbose > 1
      end
      data
    end

    # 'xy': x=0,y=0; x=1,y=0; x=2,y=0; ...
    # 'yx': x=0,y=0; x=0,y=1; x=0,y=2; ...
    # ...
    # 'xY': x=0,  y=MAX; x=1,    y=MAX; x=2,    y=MAX; ...
    # 'XY': x=MAX,y=MAX; x=MAX-1,y=MAX; x=MAX-2,y=MAX; ...
    def coord_iterator type = nil
      type ||= 'xy'
      raise "invalid iterator type #{type}" unless type =~ /\A(xy|yx)\Z/i

      x0,x1,xstep =
        if type.index('x')
          [0, @image.width-1, 1]
        else
          [@image.width-1, 0, -1]
        end

      y0,y1,ystep =
        if type.index('y')
          [0, @image.height-1, 1]
        else
          [@image.height-1, 0, -1]
        end

      if type[0,1].downcase == 'x'
        # ROW iterator
        y0.step(y1,ystep) do |y|
          x0.step(x1,xstep) do |x|
            yield x,y
          end
        end
      else
        # COLUMN iterator
        x0.step(x1,xstep) do |x|
          y0.step(y1,ystep) do |y|
            yield x,y
          end
        end
      end
    end
  end
end
