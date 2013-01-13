require 'set'

module ZSteg
  class Masker
    def initialize image, params = {}
      @src = image.is_a?(ZPNG::Image) ? image : ZPNG::Image.load(image)
      @masks = params[:masks] || {}
      @mask = params[:mask] || @masks[:all]
      @normalize = params[:normalize]
      [:r, :g, :b, :a].each{ |x| @masks[x] ||= @mask }
    end

    def mask params = {}
      dst = ZPNG::Image.new :width => @src.width, :height => @src.height
      rm, gm, bm, am = @masks[:r], @masks[:g], @masks[:b], @masks[:a]
      rd, gd, bd, ad = rm==0?1:rm, gm==0?1:gm, bm==0?1:bm, am==0?1:am
      # duplicate loops for performance reason
      if @normalize
        if rm == 0 && gm == 0 && bm == 0 && am != 0
          # alpha2grayscale
          @src.each_pixel do |c,x,y|
            c.r = c.g = c.b = (c.a & am) * 255 / ad
            c.a = 0xff
            dst[x,y] = c
          end
        else
          # normal operation
          @src.each_pixel do |c,x,y|
            #TODO: c.to_depth(8)
            # further possible optimizations:
            # a) precalculate (255 / Xm)
            c.r = (c.r & rm) * 255 / rd
            c.g = (c.g & gm) * 255 / gd
            c.b = (c.b & bm) * 255 / bd
            c.a = (c.a & am) * 255 / ad
            dst[x,y] = c
          end
        end
      else
        @src.each_pixel do |c,x,y|
          #TODO: c.to_depth(8)
          c.r &= rm
          c.g &= gm
          c.b &= bm
          c.a &= am
          dst[x,y] = c
        end
      end
      dst
    end
  end
end
