#!/usr/bin/env ruby
require 'zpng'

class ChunkAppender
  def initialize image
    @image = image.is_a?(ZPNG::Image) ? image : ZPNG::Image.load(image)
  end

  def list_chunks
    @image.chunks.each_with_index do |c, idx|
      printf "%3d: type=%4s size=%d\n", idx, c.type, c.size
    end
  end

  def append chunk_no, data
    @image.chunks[chunk_no].define_singleton_method :export_data do
      super() + data
    end
    self
  end

  def save fname
    @image.save(fname, :repack => false)
  end
end

if $0 == __FILE__
  case ARGV.size
  when 1
    ChunkAppender.new(ARGV[0]).list_chunks
  when 3,4
    fname, chunk_no, data, oname = ARGV
    oname ||= fname.chomp(File.extname(fname)) + ".out" + File.extname(fname)
    ChunkAppender.new(fname).
      append(chunk_no.to_i, data).
      save(oname)
    puts "[=] #{oname} saved"
  else
    bname = File.basename($0)
    puts "USAGE:"
    puts "  Append data to specified chunk:"
    puts "    #{bname} input.png <chunk_no> <data> [output.png]"
    puts
    puts "  List chunks:"
    puts "    #{bname} input.png"
    exit
  end
end
