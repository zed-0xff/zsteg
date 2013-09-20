require 'zlib'

#coding: binary
module ZSteg
  class Checker
    module Zlib

      MIN_UNPACKED_SIZE = 4

      class Result < Struct.new(:data, :offset)
        MAX_SHOW_SIZE = 100

        def to_s
          x = data
          x=x[0,MAX_SHOW_SIZE] + "..." if x.size > MAX_SHOW_SIZE
          "zlib: data=#{x.inspect.bright_red}, offset=#{offset}, size=#{data.size}"
        end
      end

      # try to find zlib
      # http://blog.w3challs.com/index.php?post/2012/03/25/NDH2k12-Prequals-We-are-looking-for-a-real-hacker-Wallpaper-image
      # http://blog.w3challs.com/public/ndh2k12_prequalls/sp113.bmp
      def self.check_data data
        return unless idx = data.index(/\x78[\x9c\xda\x01]/n)

        zi = ::Zlib::Inflate.new
        x = zi.inflate data[idx..-1]
        # decompress OK
        return Result.new x, idx if x.size >= MIN_UNPACKED_SIZE
      rescue ::Zlib::BufError
        # tried to decompress, but got EOF - need more data
        return Result.new x, idx
      rescue ::Zlib::DataError, ::Zlib::NeedDict
        # not a zlib
      ensure
        zi.close if zi && !zi.closed?
      end

    end # Zlib
  end # Checker
end # ZSteg
