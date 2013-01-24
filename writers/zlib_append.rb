#!/usr/bin/env ruby
require 'zpng'

class ZlibAppender
  def initialize image
    @image = image.is_a?(ZPNG::Image) ? image : ZPNG::Image.load(image)
  end

  def _guess_compress_method
    zdata = @image.chunks.find_all{ |c| c.is_a?(ZPNG::Chunk::IDAT) }.map(&:data).join
    puts "[.] old zdata size  = #{zdata.size}"
    9.downto(0) do |i|
      if zdata == Zlib::Deflate.deflate(@image.imagedata, i)
        puts "[.] compress_method = #{i}"
        return i
      end
    end
    9.downto(0) do |i|
      if zdata.size == Zlib::Deflate.deflate(@image.imagedata, i).size
        puts "[.] compress_method = #{i}"
        return i
      end
    end
    puts "[?] failed to guess compress method, using default".yellow
    nil
  end

  def append appendum
    m = _guess_compress_method
    new_data = @image.imagedata + appendum
    new_zdata = Zlib::Deflate.deflate(new_data, m)
    puts "[.] new zdata size  = #{new_zdata.size}"

    idats = @image.chunks.find_all{ |c| c.is_a?(ZPNG::Chunk::IDAT) }
    idats[0].data = new_zdata

    # delete other IDAT chunks, if any
    image.chunks -= idats[1..-1] if idats.size > 1

    self
  end

  def save fname
    @image.save(fname, :repack => false)
  end
end

if $0 == __FILE__
  case ARGV.size
  when 2,3
    fname, data, oname = ARGV
    oname ||= fname.chomp(File.extname(fname)) + ".out" + File.extname(fname)
    ZlibAppender.new(fname).
      append(data).
      save(oname)
    puts "[=] #{oname} saved"
  else
    bname = File.basename($0)
    puts "USAGE:"
    puts "  Append data to zlib stream:"
    puts "    #{bname} input.png <data> [output.png]"
    exit
  end
end
