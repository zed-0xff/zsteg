#coding: binary
module ZSteg
  class Checker
    module ScanlineChecker
      class << self
        def check_image image, params={}
          # TODO: interlaced images
          sl = image.scanlines.first
          significant_bits = sl.width*sl.bpp
          total_bits = sl.size*8
          # 1 byte for PNG scanline filter mode
          # XXX maybe move this into ZPNG::ScanLine#data_size ?
          total_bits -= 8 if image.format == :png
          return if total_bits == significant_bits

          #puts "[nbits] tb=#{total_bits}, sb=#{significant_bits}, nbits=#{total_bits-significant_bits}"
          nbits = total_bits-significant_bits
          raise "WTF" if nbits<0      # significant size greatar than total size?!

          data = ''
          scanlines = image.scanlines
          # DO NOT use 'reverse!' here - it will affect original image too
          scanlines = scanlines.reverse if image.format == :bmp
          if nbits%8 == 0
            # whole bytes
            nbytes = nbits/8
            scanlines.each do |sl|
              data << sl.decoded_bytes[-nbytes,nbytes]
            end
          else
            # extract a number of bits from each scanline
            nbytes = (nbits/8.0).ceil # number of whole bytes, rounded up
            mask = 2**nbits-1
            a = []
            scanlines.each do |sl|
              bytes = sl.decoded_bytes[-nbytes,nbytes]
              value = 0
              # convert 1+ bytes into one big integer
              bytes.each_byte{ |b| value = (value<<8) + b }

              # remove unwanted bits
              value &= mask

              # fix[n] -> 0, 1
              # Bit Reference - Returns the nth bit in the binary representation of fix
              # http://www.ruby-doc.org/core-1.9.3/Fixnum.html#method-i-5B-5D
              #
              # also "<<" + "reverse!" is 30% faster than "unshift"
              nbits.times{ |i| a << value[i] }
              a.reverse!

              while a.size >= 8
                byte = 0
                if params[:bit_order] == :msb
                  8.times{ |i| byte |= (a.shift<<i)}
                else
                  8.times{ |i| byte |= (a.shift<<(7-i))}
                end
                data << byte.chr
#                if data.size >= @limit
#                  print "[limit #@limit]".gray if @verbose > 1
#                  break
#                end
              end
            end
          end
          return if data =~ /\A\x00+\Z/ # nothing special, only zero bytes

          # something found
          data
        end
      end # class << self
    end # Scanline
  end # Checker
end # ZSteg

if $0 == __FILE__
  require 'zpng'
  ARGV.each do |fname|
    img = ZPNG::Image.load fname
    ZSteg::Checker::ScanlineChecker.check_image img
  end
end
