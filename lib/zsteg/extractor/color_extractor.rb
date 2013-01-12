module ZSteg
  class Extractor
    # ColorExtractor extracts bits from each pixel's color
    module ColorExtractor

      def color_extract params = {}
        channels = Array(params[:channels])
        #pixel_align = params[:pixel_align]

        bits = params[:bits]
        raise "invalid bits value #{bits.inspect}" unless (1..8).include?(bits)
        mask = 2**bits - 1

        if params[:prime]
          pregenerate_primes(
            :max   => @image.width * @image.height,
            :count => (@limit*8.0/bits/channels.size).ceil
          )
        end

        data = ''.force_encoding('binary')
        a = []
        #puts
        coord_iterator(params) do |x,y|
          color = @image[x,y]

          channels.each do |c|
            value = color.send(c)
            bits.times do |bidx|
              a << ((value & (1<<(bits-bidx-1))) == 0 ? 0 : 1)
            end
          end
          #p [x,y,a.size,a]

          # XXX need 'while' here
          if a.size >= 8
            byte = 0
            #puts a.join
            if params[:bit_order] == :msb
              8.times{ |i| byte |= (a.shift<<i)}
            else
              8.times{ |i| byte |= (a.shift<<(7-i))}
            end
            #printf "[d] %02x %08b\n", byte, byte
            data << byte.chr
            if data.size >= @limit
              print "[limit #@limit]".gray if @verbose > 1
              break
            end
            #a.clear if pixel_align
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
      def coord_iterator params
        type = params[:order]
        if type.nil? || type == 'auto'
          type = @image.format == :bmp ? 'xY' : 'xy'
        end
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

        # cannot join these lines from ByteExtractor and ColorExtractor into
        # one method for performance reason:
        #   it will require additional yield() for EACH BYTE iterated

        if type[0,1].downcase == 'x'
          # ROW iterator
          if params[:prime]
            idx = 0
            y0.step(y1,ystep){ |y| x0.step(x1,xstep){ |x|
              yield(x,y) if @primes.include?(idx)
              idx += 1
            }}
          else
            y0.step(y1,ystep){ |y| x0.step(x1,xstep){ |x| yield(x,y) }}
          end
        else
          # COLUMN iterator
          if params[:prime]
            idx = 0
            x0.step(x1,xstep){ |x| y0.step(y1,ystep){ |y|
              yield(x,y) if @primes.include?(idx)
              idx += 1
            }}
          else
            x0.step(x1,xstep){ |x| y0.step(y1,ystep){ |y| yield(x,y) }}
          end
        end
      end
    end
  end
end
