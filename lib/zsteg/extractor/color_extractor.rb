#coding: binary
module ZSteg
  class Extractor
    # ColorExtractor extracts bits from each pixel's color
    module ColorExtractor

      def color_extract params = {}
        channels = Array(params[:channels])
        pixel_align = params[:pixel_align]

        ch_masks = []
        case channels.first.size
        when 1
          # ['r', 'g', 'b']
          channels.each{ |c| ch_masks << [c[0], bit_indexes(params[:bits])] }
        when 2
          # ['r3', 'g2', 'b3']
          channels.each{ |c| ch_masks << [c[0], bit_indexes(c[1].to_i)] }
        else
          raise "invalid channels: #{channels.inspect}" if channels.size != 1
          t = channels.first
          if t =~ /\A[rgba]+\Z/
            return color_extract(params.merge(:channels => t.split('')))
          end
          raise "invalid channels: #{channels.inspect}"
        end

        # total number of bits = sum of all channels bits
        nbits = ch_masks.map{ |x| x[1].size }.inject(&:+)

        if params[:prime]
          pregenerate_primes(
            :max   => @image.width * @image.height,
            :count => (@limit*8.0/nbits/channels.size).ceil
          )
        end

        data = ''.force_encoding('binary')
        a = [0]*params[:shift].to_i        # prepend :shift zero bits
        catch :limit do
          coord_iterator(params) do |x,y|
            color = @image[x,y]

            ch_masks.each do |c,bidxs|
              bidxs = bidxs[a.size-8..] if pixel_align && a.size + bidxs.size > 8
              value = color.send(c)
              bidxs.each do |bidx|
                a << value[bidx]
              end
            end

            while a.size >= 8
              byte = 0
              # a0 = a.dup
              if params[:bit_order] == :msb
                8.times{ |i| byte |= (a.shift<<i)}
              else
                8.times{ |i| byte |= (a.shift<<(7-i))}
              end
              # printf "[d] %-10s -> %-10s : %s %02x %08b  x=%d y=%d\n", a0.join, a.join, byte.chr.inspect, byte, byte, x, y
              data << byte.chr
              if data.size >= @limit
                print "[limit #@limit]".gray if @verbose > 1
                throw :limit
              end
              a.clear if pixel_align && a.size < 8
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
