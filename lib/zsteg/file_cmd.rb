require 'open3'
require 'tempfile'

module ZSteg
  class FileCmd

    IGNORES = [
      'data',
      'empty',
      'Sendmail frozen configuration',
      'DBase 3 data file',
      'DOS executable',
      'Dyalog APL',
      '8086 relocatable',
      'SysEx File',
      'COM executable',
      'Non-ISO extended-ASCII text',
      'ISO-8859 text',
      'very short file',
      'International EBCDIC text',
      'lif file',
      'AmigaOS bitmap font',
      'a python script text executable' # common false positive
    ]

    MIN_DATA_SIZE = 5

    class Result < Struct.new(:title, :data)
      COLORMAP_TEXT = {
        /DBase 3 data/i               => :gray
      }
      COLORMAP_WORD = {
        /bitmap|jpeg|pdf|zip|rar|7-?z/i => :bright_red,
      }

      def to_s
        if title[/UTF-8 Unicode text/i]
          begin
            t = data.force_encoding("UTF-8").encode("UTF-32LE").encode("UTF-8")
          rescue
            t = data.force_encoding('binary')
          end
          return "utf8: " + t
        end
        COLORMAP_TEXT.each do |re,color|
          return colorize(color) if title[re]
        end
        title.downcase.split.each do |word|
          COLORMAP_WORD.each do |re,color|
            return colorize(color) if title.index(re) == 0
          end
        end
        colorize(:yellow)
      end

      def colorize color
        if color == :gray
          # gray whole string
          "file: #{title}".send(color)
        else
          "file: " + title.send(color)
        end
      end
    end

    def start!
      @stdin, @stdout, @stderr, @wait_thr = Open3.popen3("file -n -b -f -")
    end

    def check_file fname
      @stdin.puts fname
      r = @stdout.gets.force_encoding('binary').strip
      IGNORES.any?{ |x| r.index(x) == 0 } ? nil : r
    end

    def check_data data
      @tempfile ||= Tempfile.new('zsteg', :encoding => 'binary')
      @tempfile.rewind
      @tempfile.write data
      @tempfile.flush
      check_file @tempfile.path
    end

    # checks data and resurns Result, if any
    def data2result data
      return if data.size < MIN_DATA_SIZE

      title = check_data data
      return unless title

      if title[/UTF-8 Unicode text/i]
        begin
          t = data.force_encoding("UTF-8")
        rescue
          t = data.force_encoding('binary')
        end
        if t.size >= Checker::DEFAULT_MIN_STR_LEN
          ZSteg::Result::UnicodeText.new(t,0)
        end
      else
        Result.new(title,data)
      end
    end

    def stop!
      @stdin.close
      @stdout.close
      @stderr.close
    ensure
      if @tempfile
        @tempfile.close
        @tempfile.unlink
        @tempfile = nil
      end
    end
  end
end

if __FILE__ == $0
  filecmd = ZSteg::FileCmd.new
  ARGV.each do |fname|
    p filecmd.check_file fname
    p filecmd.check_data File.binread(fname)
  end
  filecmd.stop!
end
