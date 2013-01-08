module ZSteg
  class Extractor

    include ByteExtractor
    include ColorExtractor

    # image can be either filename or ZPNG::Image
    def initialize image, params = {}
      @image = image.is_a?(ZPNG::Image) ? image : ZPNG::Image.load(image)
      @verbose = params[:verbose]
    end

    def extract params = {}
      if params[:order] =~ /b/i
        byte_extract params
      else
        color_extract params
      end
    end
  end
end
