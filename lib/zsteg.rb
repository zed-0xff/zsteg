require 'zpng'
require 'iostruct'

require 'zsteg/extractor/byte_extractor'
require 'zsteg/extractor/color_extractor'
require 'zsteg/extractor'

require 'zsteg/checker'
require 'zsteg/result'
require 'zsteg/file_cmd'

require 'zsteg/masker'

require 'zsteg/analyzer'

module ZSteg::CLI
  class << self
    def run
      a = File.basename($0).downcase.scan(/\w+/) - %w'zsteg rb'
      a = %w'cli' if a.empty?

      klass = a.map(&:capitalize).join
      req = a.join('_')
      require File.expand_path( File.join('zsteg', 'cli', req), File.dirname(__FILE__))

      const_get(klass).new.run
    end

    # shortcut for ZSteg::CLI::Cli.new, mostly for RSpec
    def new *args
      require 'zsteg/cli/cli'
      Cli.new(*args)
    end
  end
end
