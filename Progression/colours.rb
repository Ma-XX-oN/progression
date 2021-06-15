require 'sketchup.rb'
XXX::bof(__FILE__)
module AFH
    RED   = Sketchup::Color.new('red')
    GREEN = Sketchup::Color.new('green')
    BLUE  = Sketchup::Color.new('blue')
    BLACK = Sketchup::Color.new('black')
    WHITE = Sketchup::Color.new('white')
    GREY  = BLACK.blend(WHITE, 0.50)
end
XXX::eof(__FILE__)