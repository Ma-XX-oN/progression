XXX::bof(__FILE__)
require 'sketchup.rb'

module AFH
    class << self
    
    ## AXES begin
    def axes_getExtents(bb)
        @@axes.flatten.each {|p| bb.add(p)}
    end

    @@stipple = ['', '.', '-', '_', '-.-'].reverse
    def axes_draw(view)
        origin_used = {}
        # draw some debugging stuff
        @@axes.each_with_index {|(o,x,y,z), i|
            view.line_stipple = @@stipple[origin_used.key?(o) ? origin_used[o] += 1 : origin_used[o] = 0]
            view.drawing_color = RED
            view.draw_line(o, x)
            view.drawing_color = GREEN
            view.draw_line(o, y)
            view.drawing_color = BLUE
            view.draw_line(o, z)
        }
    end

    @@axes = []
    
    def axes
        @@axes
    end
    
    def axes_add(axes)
        if @@axes.find {|e| are_equal?(axes, e) } == nil
            @@axes.push axes
            Sketchup.active_model.active_view.invalidate
        end
    end
    
    def axes_del(axes)
        @@axes.select! {|e|
            !are_equal?(axes, e)
        }
        Sketchup.active_model.active_view.invalidate
    end
    ## AXES end

    end # class << self
end
XXX::eof(__FILE__)