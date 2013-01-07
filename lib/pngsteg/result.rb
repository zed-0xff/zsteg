module PNGSteg
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
        inspect.sub('#<struct PNGSteg::', '<')
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
#        inspect.sub('#<struct PNGSteg::Result::', '<')
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
        super.red
      end
    end

    class Text < Struct.new(:text)
      def to_s
        "text="+text.inspect.gray
      end
    end

    class Zlib < Struct.new(:offset, :data)
      def to_s
        super.sub(data.inspect, data.inspect.red)
      end
    end
  end
end
