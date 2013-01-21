require 'prime'
require 'set'

module ZSteg
  class Extractor

    include ByteExtractor
    include ColorExtractor

    # image can be either filename or ZPNG::Image
    def initialize image, params = {}
      @image = image.is_a?(ZPNG::Image) ? image : ZPNG::Image.load(image)
      @verbose = params[:verbose] || 0
    end

    def extract params = {}
      @limit = params[:limit].to_i
      @limit = 2**32 if @limit <= 0

      if params[:order] =~ /b/i
        byte_extract params
      else
        color_extract params
      end
    end

    def pregenerate_primes h
      @primes ||= Set.new
      return if @primes.size >= h[:count]

      count = h[:count]
      Prime.each(h[:max]) do |prime|
        @primes << prime
        break if @primes.size >= count
      end
    end

    def bit_indexes bits
      if (1..8).include?(bits)
        # number of bits
        # 1 => [0]
        # ...
        # 8 => [7,6,5,4,3,2,1,0]
        bits.times.to_a.reverse
      else
        # mask
        mask = bits & 0xff
        r = []
        8.times do |i|
          r << i if mask[i] == 1
        end
        r.reverse
      end
    end
  end
end
