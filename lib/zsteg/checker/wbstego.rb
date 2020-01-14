#coding: binary
module ZSteg
  class Checker
    module WBStego

      ENCRYPTIONS = [
        nil,         # 0
        "Blowfish",  # 1
        "Twofish",   # 2
        "CAST128",   # 3
        "Rijndael",  # 4
      ]

      class Result < IOStruct.new "a3a3a*", :size, :ext, :data, :even, :hdr, :enc, :mix, :controlbyte
        attr_accessor :color

        def initialize *args
          super
          if self.size.is_a?(String)
            self.size = (self.size[0,3] + "\x00").unpack('V')[0]
          end
          self.even ||= false
          #self.encrypted ||= false
          if ext[0,2] == "\x00\xff"
            # wbStego 4.x header
            self.hdr  = data[0,ext[2].ord] # 3rd ext byte is hdr len
            self.data = data[hdr.size..-1]
            self.ext  = nil                # encrypted files have no ext
            self.enc  = ENCRYPTIONS[hdr[0].ord] || "unknown ##{hdr[0].ord}"
          elsif (cb=ext[0].ord) & 0xc0 != 0
            # wbStego 2.x/3.x controlbyte
            self.controlbyte = ext[0]
            self.data = ext[1..-1] + data
            self.ext  = nil                # have ext but its encrypted/mixed with data
            self.mix  = true if cb & 0x40 != 0
            self.enc  = "wbStego 2.x/3.x" if cb & 0x80 != 0
          end
        end

        def to_s
          s = inspect.
              sub("#<struct #{self.class.to_s}", "<wbStego").
              gsub(/, \w+=nil/,'')

          color = @color

          if ext && !valid_ext?
            s.sub!(data.inspect, data[0,10].inspect+"...") if data && data.size>13
            color ||= :gray
          else
            s.sub!(data.inspect, data[0,10].inspect+"...") if data && data.size>13 && enc
            color ||= :bright_red
          end
          s.send(color)
        end

        # XXX require that file extension be 7-bit ASCII
        def valid_ext?
          ext =~ /\A[\x20-\x7e]+\Z/ && !ext['*'] && !ext['?']
        end
      end

      class << self
        def used_colors
          raise "TODO"
        end

        # from wbStego4open sources
        def calc_avail_size image
         space = 0
         biHeader = image.hdr
         if biHeader.biCompression == 0
           case biHeader.biBitCount
           when 4
             space = 2*image.imagedata_size if used_colors < 9
           when 8
             space = image.imagedata_size if used_colors < 129
           when 24
             space = image.imagedata_size
           end
         else
           raise "TODO"
#           if biHeader.biBitCount=4 then begin
#             if UsedColors<9 then space:=GetAvailSizeRLE else space:=0;
#           end;
#           if biHeader.biBitCount=8 then begin
#             if UsedColors<129 then space:=GetAvailSizeRLE else space:=0;
#           end;
         end
         space/8
        end

        def check data, params = {}
          return if data.size < 4
          return if params[:bit_order] != :lsb

          force_color = nil

          if params[:image].format == :bmp
            return if params[:order] !~ /b/i
          else
            # PNG
            return if Array(params[:channels]).join != 'bgr'
            force_color = :gray if params[:order] != 'xY'
          end

          size1 = (data[0,3] + "\x00").unpack('V')[0]
          avail_size =
            if params[:image].format == :bmp
              calc_avail_size(params[:image])
            else
              params[:max_hidden_size]
            end
          return if size1 == 0 || size1 > avail_size

          # check if too many zeroes, prevent false positive
          nzeroes = data[3..-1].count("\x00")
          return if nzeroes > 10 && data.size-3-nzeroes < 4

          result = nil

          size2 = (data[3,3] + "\x00").unpack('V')[0]
#          p [size1, size2, avail_size]
          if size2 < avail_size && size2 > 0
            spacing = 1.0*avail_size/(size2+5) - 1
#            puts "[d] spacing=#{spacing}"
            if spacing > 0
              error = 0
              r = ''
              6.upto(data.size-1) do |idx|
                if error < 1
                  r << data[idx]
                  error += spacing
                else
                  error -= 1
                end
              end
              if r.size > 4
                ext = r[0,3]
                result = Result.new(size2, ext, r[3..-1], true)
              end
            end
          end
          # no even distribution
          #return unless valid_ext?(data[3,3])
          result ||= Result.read(data)
          result.color = force_color if result && force_color
          result

        rescue
          STDERR.puts "[!] wbStego: #{$!.inspect}".red
        end

      end
    end
  end
end
