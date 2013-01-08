module ZSteg
  module Result

    class Struct < ::Struct
      def to_s
        inspect.sub('#<struct ZSteg::', '<')
      end
    end

    class OpenStego < IOStruct.new "CVCCCC",
      :version, :data_len, :channel_bits, :fname_len, :compress, :encrypt, :fname

      def self.read io
        super.tap do |r|
          r.fname = io.read(r.fname_len) if r.fname_len
        end
      end

      def to_s
        super.sub(/^<Result::/,'').sub(/>$/,'').red
      end
    end

    class Text < Struct.new(:text, :offset)
      def to_s
        "text: ".gray + (offset == 0 ? text.inspect.red : text.inspect)
      end
    end

    # whole data is text
    class WholeText < Text; end

    # part of data is text
    class PartialText < Text; end

    class Zlib < Struct.new(:data, :offset)
      def to_s
        "zlib: data=#{data.inspect.red}, offset=#{offset}"
      end
    end

    class OneChar < Struct.new(:char, :size)
      def to_s
        "[#{char.inspect} repeated #{size} times]".gray
      end
    end

    class FileCmd < Struct.new(:title, :data)
      COLORMAP = {
        /bitmap|jpeg|pdf|zip|rar|7z/i => :red,
        /DBase 3 data/i               => :gray
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
        COLORMAP.each do |re,color|
          if title[re]
            if color == :gray
              return "file: #{title}".send(color)
            else
              return "file: " + title.send(color)
            end
          end
        end
        "file: " + title.yellow
      end
    end

    class Camouflage < Struct.new(:hidden_data_len, :host_orig_len)
      def initialize(data)
        self.hidden_data_len = (data[0x1a,4] || '').unpack('V').first
        if data.size > 300 && data[-4,4] == "\x20\x20\x20\x20"
          # orignal length of host file
          self.host_orig_len = data[-281,4].unpack('V').first
        end
      end

      def to_s
        super.red
      end
    end
  end
end
