require 'zpng'

module ZSteg
  class Analyzer
    def initialize image, params = {}
      @params = params
      @image = image.is_a?(ZPNG::Image) ? image : ZPNG::Image.load(image)
    end

    def analyze!
      if bs = detect_block_size
        puts "[!] possible image block size is #{bs.join('x')}, downscaling may be necessary".yellow
      end
    end

    def check_block_size dx, dy, x0, y0
      c0 = @image[x0,y0]
      y0.upto(y0+dy-1) do |y|
        x0.upto(x0+dx-1) do |x|
          return if @image[x,y] != c0
        end
      end
      true
    end

    def detect_block_size
      x=y=0
      c0 = @image[x,y]
      dx = dy = 1

      while (x+dx) < @image.width && @image[x+dx,y] == c0
        dx+=1
      end
      while (y+dy) < @image.height && @image[x,y+dy] == c0
        dy+=1
      end

      return if dx<2 && dy<2
      return if [1, @image.width].include?(dx) && [1, @image.height].include?(dy)

      # check 3x3 block
      0.step([dy*3, @image.height-1].min, dy) do |y|
        0.step([dx*3, @image.width-1].min, dx) do |x|
          return unless check_block_size dx, dy, x, y
        end
      end

      [dx,dy]
    end
  end
end

if __FILE__ == $0
  ARGV.each do |fname|
    printf "\r[.] %-40s .. ", fname
    begin
      ZSteg::Analyzer.new(fname).analyze!
    rescue
      p $!
    end
  end
  puts
end
