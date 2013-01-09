#!/usr/bin/env ruby
require 'zpng'
require 'awesome_print'

@show_all = true

images = ARGV.map{ |fname| ZPNG::Image.load(fname) }
raise "need at least 2 images" if images.size < 2

limit = 25
alpha_used = images.any?(&:alpha_used?)
channels = alpha_used ? %w'r g b a' : %w'r g b'
channels.reverse!

printf "%6s %4s %4s : %s  ...\n".magenta, "#", "X", "Y", (alpha_used ? "RRGGBBAA":"RRGGBB").reverse

idx = ndiff = 0
(images[0].height-1).downto(0) do |y|
  0.upto(images[0].width-1) do |x|
    colors = images.map{ |img| img[x,y] }
    if colors.uniq.size > 1 || @show_all
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
      exit
    end
  end
end
