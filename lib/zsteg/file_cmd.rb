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
    ]

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
