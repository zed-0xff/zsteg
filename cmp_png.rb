#!/usr/bin/env ruby
require 'zpng'
require 'awesome_print'

images = ARGV.map{ |fname| ZPNG::Image.load(fname) }
raise "need at least 2 images" if images.size < 2

limit = 100
alpha_used = images.any?(&:alpha_used?)
channels = alpha_used ? %w'r g b a' : %w'r g b'

printf "%6s %4s %4s : %s  ...\n".magenta, "#", "X", "Y", (alpha_used ? "RRGGBBAA":"RRGGBB")

idx = ndiff = 0
images[0].each_pixel do |c,x,y|
  colors = images.map{ |img| img[x,y] }
  if colors.uniq.size > 1
    ndiff += 1
    printf "%6d %4d %4d : ", idx, x, y
    t = Array.new(images.size){ '' }
    channels.each do |channel|
      values = colors.map{ |color| color.send(channel) }
      if values.uniq.size == 1
        # all equal
        values.each_with_index do |value,idx|
          t[idx] << "%02x".gray % value
        end
      else
        # got diff
        values.each_with_index do |value,idx|
          t[idx] << "%02x".red % value
        end
      end
    end
    puts t.join('  ')
  end
  idx += 1
  if limit && ndiff >= limit
    puts "[.] diff limit #{limit} reached"
    break
  end
end
