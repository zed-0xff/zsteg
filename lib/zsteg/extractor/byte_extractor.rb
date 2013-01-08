module ZSteg
  class Extractor
    # ByteExtractor extracts bits from each scanline bytes
    # actual for BMP+wbStego combination
    module ByteExtractor

      def byte_extract params = {}
        limit = params[:limit].to_i
        limit = 2**32 if limit <= 0

        bits = params[:bits]
        raise "invalid bits value #{bits.inspect}" unless (1..8).include?(bits)
        mask = 2**bits - 1


        data = ''.force_encoding('binary')
        a = []
        byte_iterator(params[:order]) do |x,y|
          sl = @image.scanlines[y]

          value = sl.decoded_bytes[x].ord
          bits.times do |bidx|
            a << ((value & (1<<(bits-bidx-1))) == 0 ? 0 : 1)
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

      # 'xy': b=0,y=0; b=1,y=0; b=2,y=0; ...
      # 'yx': b=0,y=0; b=0,y=1; b=0,y=2; ...
      # ...
      # 'xY': b=0,  y=MAX; b=1,    y=MAX; b=2,    y=MAX; ...
      # 'XY': b=MAX,y=MAX; b=MAX-1,y=MAX; b=MAX-2,y=MAX; ...
      def byte_iterator type = nil
        if type.nil? || type == 'auto'
          type = @image.format == :bmp ? 'bY' : 'by'
        end
        raise "invalid iterator type #{type}" unless type =~ /\A(by|yb)\Z/i

        sl0 = @image.scanlines.first

        x0,x1,xstep =
          if type.index('b')
            [0, sl0.decoded_bytes.size-1, 1]
          else
            [sl0.decoded_bytes.size-1, 0, -1]
          end

        y0,y1,ystep =
          if type.index('y')
            [0, @image.height-1, 1]
          else
            [@image.height-1, 0, -1]
          end

        if type[0,1].downcase == 'b'
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
end
