#coding: binary
module ZSteg
  class Extractor
    # ByteExtractor extracts bits from each scanline bytes
    # actual for BMP+wbStego combination
    module ByteExtractor

      def byte_extract params = {}
        bidxs = bit_indexes params[:bits]

        if params[:prime]
          pregenerate_primes(
            :max   => @image.scanlines[0].size * @image.height,
            :count => (@limit*8.0/bidxs.size).ceil
          )
        end

        data = ''.force_encoding('binary')
        a = [0]*params[:shift].to_i        # prepend :shift zero bits
        byte_iterator(params) do |x,y|
          sl = @image.scanlines[y]

          value = sl.decoded_bytes.getbyte(x)
          bidxs.each do |bidx|
            a << value[bidx]
          end

          if a.size >= 8
            byte = 0
            if params[:bit_order] == :msb
              8.times{ |i| byte |= (a.shift<<i)}
            else
              8.times{ |i| byte |= (a.shift<<(7-i))}
            end
            data << byte.chr
            #a = []
            if data.size >= @limit
              print "[limit #@limit]".gray if @verbose > 1
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
      def byte_iterator params
        type = params[:order]
        if type.nil? || type == 'auto'
          type = @image.format == :bmp ? 'bY' : 'by'
        end
        raise "invalid iterator type #{type}" unless type =~ /\A(by|yb)\Z/i

        sl0 = @image.scanlines.first

        # XXX don't try to run it on interlaced PNGs!
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

        xstep *= params[:step] if params[:step]
        ystep *= params[:ystep] if params[:ystep]

        # cannot join these lines from ByteExtractor and ColorExtractor into
        # one method for performance reason:
        #   it will require additional yield() for EACH BYTE iterated

        if type[0,1].downcase == 'b'
          # ROW iterator (natural)
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
