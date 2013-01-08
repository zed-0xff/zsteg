module ZSteg
  class Checker
    module WBStego

      class Result < IOStruct.new "a3a3a*", :size, :ext, :data, :even
        def initialize *args
          super
          if self.size.is_a?(String)
            self.size = (self.size[0,3] + "\x00").unpack('V')[0]
          end
          self.even = false if self.even.nil?
        end

        def to_s
          inspect.sub("#<struct #{self.class.to_s}", "<wbStego").red
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
          size1 = (data[0,3] + "\x00").unpack('V')[0]
          avail_size =
            if params[:image].format == :bmp
              calc_avail_size(params[:image])
            else
              params[:max_hidden_size]
            end
          return if size1 == 0 || size1 > avail_size
          size2 = (data[3,3] + "\x00").unpack('V')[0]
#          p [size1, size2, avail_size]
          if size2 < avail_size
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
#              puts "[d] r=#{r.inspect} (#{r.size})"
              return Result.new(size2, r[0,3], r[3..-1], true)
            end
          end
          # no even distribution
          return Result.read(data)
        end
      end
    end
  end
end
