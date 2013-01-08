module ZSteg
  module Result
    module Readable
      # src can be IO or String, or anything that responds to :read or :unpack
      def read src, size = nil
        size ||= const_get 'SIZE'
        data =
          if src.respond_to?(:read)
            src.read(size).to_s
          elsif src.respond_to?(:unpack)
            src
          else
            raise "[?] don't know how to read from #{src.inspect}"
          end
        if data.size < size
          $stderr.puts "[!] #{self.to_s} want #{size} bytes, got #{data.size}"
        end
        new(*data.unpack(const_get('FORMAT')))
      end
    end

    class << self
      def create_struct fmt, *args
        size = fmt.scan(/([a-z])(\d*)/i).map do |f,len|
          [len.to_i, 1].max *
            case f
            when /[aAC]/ then 1
            when 'v' then 2
            when 'V','l' then 4
            when 'Q' then 8
            else raise "unknown fmt #{f.inspect}"
            end
        end.inject(&:+)

        Struct.new( *args ).tap do |x|
          x.const_set 'FORMAT', fmt
          x.const_set 'SIZE',  size
          x.class_eval do
            include InstanceMethods
          end
          x.extend Readable
        end
      end
    end

    class Struct < ::Struct
      def to_s
        inspect.sub('#<struct ZSteg::', '<')
      end
    end

    module InstanceMethods
      def pack
        to_a.pack self.class.const_get('FORMAT')
      end

      def empty?
        to_a.all?{ |t| t == 0 || t.nil? || t.to_s.tr("\x00","").empty? }
      end

#      def to_s
#        inspect.sub('#<struct ZSteg::Result::', '<')
#      end
    end

    class OpenStego < create_struct "CVCCCC",
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
  end
end
