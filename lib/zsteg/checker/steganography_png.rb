# coding: binary
module ZSteg
  class Checker
    module SteganographyPNG

      URL = "https://github.com/pedrooaugusto/steganography-png"

      # https://github.com/pedrooaugusto/steganography-png/blob/2a0e038c135e41438b4c2c93821227a2289b4203/scanlines/scanlines.go#L234
      #
      # The secret metadata is stored in the last bytes of the last scanline in the form of:
      #   17 107 [bitloss] [secret size - 4 bytes] [secret type] [secret type length]
      #   17 107     1             4096             "text/plain"          10
      
      class Result < IOStruct.new "nCNa*", :magic, :bitloss, :secret_size, :secret_type
        def valid?
          magic == 0x116b && (1..8).include?(bitloss)
        end

        def to_s
          super.sub('#<struct ZSteg::Checker::SteganographyPNG::Result', 'SteganographyPNG').sub(/>$/,'').bright_red
        end
      end

      def self.check_image image, _params = {}
        ls = image.scanlines.last
        data = ls.decoded_bytes
        secret_type_length = data[-1].ord
        return nil if secret_type_length > data.size - 8
        data = data[ -secret_type_length-8 .. -2 ]
        # data.size to prevent "want 8 bytes, got 7" IOStruct warning when secret_type_length == 0
        r = Result.read(data, data.size)
        r.valid? && [r, URL]
      end
    end
  end
end
