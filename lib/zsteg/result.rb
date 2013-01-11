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
        super.sub(/^<Result::/,'').sub(/>$/,'').bright_red
      end
    end

    class Text < Struct.new(:text, :offset)
      def one_char?
        (text =~ /\A(.)\1+\Z/m) == 0
      end

      def to_s
        "text: ".gray +
          if one_char?
            "[#{text[0].inspect} repeated #{text.size} times]".gray
          elsif offset == 0
            text.inspect.bright_red
          else
            text.inspect
          end
      end
    end

    # whole data is text
    class WholeText < Text; end

    # part of data is text
    class PartialText < Text; end

    # unicode text
    class UnicodeText < Text; end

    class Zlib < Struct.new(:data, :offset)
      def to_s
        "zlib: data=#{data.inspect.bright_red}, offset=#{offset}"
      end
    end

    class OneChar < Struct.new(:char, :size)
      def to_s
        "[#{char.inspect} repeated #{size} times]".gray
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
        super.bright_red
      end
    end
  end
end
