#!/usr/bin/env ruby

# | a00  a10  a20    0 | |    1    0    0    0 |     | a00 a10 a20   0 |
# | a01  a11  a21    0 | |    0    1    0    0 | --- | a01 a11 a21   0 |
# | a02  a12  a22    0 | |    0    0    1    0 | --- | a02 a12 a22   0 |
# | a03  a13  a23    1 | | -a03 -a13 -a23    1 |     |   0   0   0   1 |

# | a00  a10  a20    0 | |    1    0    0    0 |     | a00 a10 a20   0 |
# | a01  a11  a21    0 | |    0    1    0    0 | --- | a01 a11 a21   0 |
# | a02  a12  a22    0 | |    0    0    1    0 | --- | a02 a12 a22   0 |
# | a03  a13  a23    1 | |    0    0    0    1 |     | a03 a13 a23   1 |

# |    1    0    0    0 | | a00  a10  a20    0 |     | a00 a10 a20   0 |
# |    0    1    0    0 | | a01  a11  a21    0 | --- | a01 a11 a21   0 |
# |    0    0    1    0 | | a02  a12  a22    0 | --- | a02 a12 a22   0 |
# |    0    0    0    1 | | a03  a13  a23    1 |     | a03 a13 a23   1 |

# The following proves that AB = BA = I.  This implies that B is the inverse of A.
#   A B = IDENTITY
#   A = I B.inverse
#   A = B.inverse I
#   B A = IDENTITY
#
# Given the above:
#   ABC = I
#   AB = C.inverse
#   CAB = I
# Thus:
#   ABC = CAB = BCA = I
# This cannot show ABC = CBA

XXX::bof(__FILE__)
require 'sketchup.rb'
require_relative 'assert.rb'
require_relative 'axes.rb'
require_relative 'debug.rb'
require_relative 'enum.rb'
require_relative 'equality.rb'
require_relative 'geom.rb'
require_relative 'hiarchry.rb'
require_relative 'interpolate.rb'
require_relative 'keybindings.rb'
require_relative 'linear_matrix.rb'
require_relative 'math.rb'
require_relative 'string_formatting.rb'
require_relative 'transformation.rb'
require_relative 'colours.rb'

class AFH
    @@stuff = nil
    def self.stuff;     @@stuff;     end
    def self.stuff=(x); @@stuff = x; end
    
    def self.progression_tool
        model = Sketchup.active_model
        model.select_tool(@@stuff = Progression.new)
    end
    
    ## PROGRESSION begin
    class Progression
        VK_OEM_MINUS  = 0xBD
        VK_OEM_PLUS   = 0xBB
        VK_OEM_COMMA  = 0xBC
        VK_OEM_PERIOD = 0xBE
         
        # enums for what Ctrl-- and Ctrl-+ control.
        MODIFY_ENUM      = Enum_type.new("MODIFY_ENUM", :segments, :start, :which_1st, :finish, :method)
        MODIFY_SEGMENTS  = MODIFY_ENUM.enum_const :segments
        MODIFY_START     = MODIFY_ENUM.enum_const :start
        MODIFY_WHICH_1ST = MODIFY_ENUM.enum_const :which_1st
        MODIFY_FINISH    = MODIFY_ENUM.enum_const :finish
        MODIFY_METHOD    = MODIFY_ENUM.enum_const :method

        METHOD_ENUM      = Enum_type.new("METHOD_ENUM", :sketchup_interpolate, :custom_interpolate)

        SELECT_COMPONENT =-1 # Select a component
        SELECT_START     = 0 # Transform points start
        SELECT_FINISH    = 1 # Transform points finish
        SELECT_AXES_END  = 2 # Number of transform points

        POINT_ORIGIN = 0 # Origin point
        POINT_X_AXIS = 1 # X axis point (vector is POINT_X_AXIS - POINT_ORIGIN)
        POINT_Y_AXIS = 2 # Y axis point (vector is POINT_Y_AXIS - POINT_ORIGIN)
        POINT_END    = 3 # Number of axis points

        SELECT_ROTATION_POINT = 6
        SELECT_END = 7

        @@prompt = nil
        # No need for a object level @segments as this value will persist
        # beyond the lifetime of this obJect.
        @@segments = 12

        include AFH

        def initialize
            if nil == @@prompt
                @@prompt = Array.new(SELECT_AXES_END){ Array.new(POINT_END) }
                for pos in (SELECT_START..SELECT_FINISH)
                    for axis in (POINT_ORIGIN..POINT_Y_AXIS)
                        @@prompt[pos][axis] = "Select " + ["starting", "ending"][pos] + " " + ["origin", "x-axis", "y-axis"][axis]
                    end
                end
            end
            @ps     = Array.new(SELECT_AXES_END){ Array.new(POINT_END) }
            @ip     = Sketchup::InputPoint.new
            @ph     = Sketchup::PickHelper.new
            @rotation_point = nil
            @operation_complete = false
            @start_with = END_TRANSLATE.dup
            @finish_with   = END_ROTATE.dup
            @which_1st = FIRST_ROTATE.dup
            @method    = METHOD_ENUM.enum :sketchup_interpolate
            @list = [] # used to kind of animate instances
            @keybindings = KeyBindings.new(
                { :keys => "\t"                   , :code => -> { @modify.next! }                        , :on_press => :down },
                { :keys => "\t"                   , :code => -> { @modify.prev! }, :modifiers => VK_SHIFT, :on_press => :down },
                { :keys => ["-".ord, VK_OEM_MINUS], :code => -> {
                        if @modify == MODIFY_SEGMENTS
                            @@segments -= 1 if @@segments > 1
                            update(true)
                        elsif @operation_complete
                            case @modify
                            when MODIFY_WHICH_1ST
                                @which_1st.prev!
                                update(true)
                            when MODIFY_START
                                @start_with.prev!
                                update(true)
                            when MODIFY_FINISH
                                @finish_with.prev!
                                update(true)
                            when MODIFY_METHOD
                                @method.prev!
                                update(true)
                            end
                        end
                    }, :modifiers => VK_CONTROL, :on_press => :down
                },
                { :keys => ["+".ord, VK_OEM_PLUS]  , :code => -> {
                        if @modify == MODIFY_SEGMENTS
                            @@segments += 1
                            update(true)
                        elsif @operation_complete
                            case @modify
                            when MODIFY_WHICH_1ST
                                @which_1st.next!
                                update(true)
                            when MODIFY_START
                                @start_with.next!
                                update(true)
                            when MODIFY_FINISH
                                @finish_with.next!
                                update(true)
                            when MODIFY_METHOD
                                @method.next!
                                update(true)
                            end
                        end
                    }, :modifiers => VK_CONTROL, :on_press => :down
                }
            )
            
            ::AFH::stuff = self
        end

        attr_reader :ps, :state
        def activate
            puts var_s(:@start_with, :@finish_with, :@which_1st){|_|eval _};
            model = Sketchup.active_model
            selection = model.selection
            if selection.length != 1 || selection[0].class.to_s != "Sketchup::ComponentInstance"
                @component_instance = nil
                @state  = SELECT_COMPONENT
                update_statusbar "Select a component", ""
            else
                @component_instance = selection[0]
                @state  = SELECT_START
                update_statusbar @@prompt[SELECT_START][POINT_ORIGIN], ""
            end
            
            @p = Geom::Point3d.new(0, 0, 0)
            for pos in (SELECT_START..SELECT_FINISH)
                for axis in (POINT_ORIGIN..POINT_Y_AXIS)
                    @ps[pos][axis] = nil
                end
            end

            @operation_complete = false
            @modify = MODIFY_SEGMENTS.dup
            @translate_segments = 0
            @rotate_segments    = 0
            updateVCB
        end

        # deactivate is called when the tool is deactivated because
        # a different tool was selected
        def deactivate(view)
            view.invalidate
        end

        # The onMouseMove method is called whenever the user moves the mouse.
        # because it is called so often, it is important to try to make it efficient.
        # In a lot of tools, your main interaction will occur in this method.
        def onMouseMove(flags, x, y, view)
            #puts indent "onMouseMove " + flags.to_s + ", " + x.to_s + ", " + y.to_s + ", " + view.to_s
            @ip.pick view, x, y
            if @ip.valid?
                @p = @ip.position.clone
                view.invalidate
                view.tooltip = @ip.tooltip
            end
        end

        # The onLButtonUp method is called when the user releases the left mouse button.
        def onLButtonUp(flags, x, y, view)
            # if @operation_complete
                # reset(view)
                # @operation_complete = false
            # end

            @ip.pick view, x, y
            if @ip.valid?
                @p = @ip.position.clone
                if @state < SELECT_ROTATION_POINT
                    @ps[@state/POINT_END][@state%POINT_END] = @p.clone
                end

                if @state == SELECT_ROTATION_POINT - 1
                    @state = SELECT_ROTATION_POINT
                    update_statusbar
                    @rotation_point = @ps[SELECT_FINISH][POINT_ORIGIN]
                    done
                elsif @state != SELECT_ROTATION_POINT
                    @state += 1
                    view.invalidate
                    update_statusbar
                    updateVCB
                else
                    @rotation_point = @p
                    parameters_changed
                end
            end
        end

        @@rel_brightness = 0.20
        @@colors = [BLACK, RED, GREEN]

        def draw(view)
            #puts indent "draw " + view.to_s
            view.line_stipple = ""
            view.line_width = 20

            if @state == SELECT_COMPONENT
                # What to do for this?
            else
                # Draw placed items
                for pos in (SELECT_START..SELECT_FINISH)
                    origin = @ps[pos][POINT_ORIGIN]
                    break if origin.nil?
                    #puts indent "pos #{origin}"

                    x = @ps[pos][POINT_X_AXIS]
                    if nil != x
                        view.drawing_color = RED
                        view.draw_line(origin, x)

                        y = @ps[pos][POINT_Y_AXIS]
                        if nil != y
                            angle = (x - origin).angle_between(y - origin).radians
                            if float_equal?(90, angle)
                                view.drawing_color = GREEN
                            else
                                view.drawing_color = GREEN.blend(BLACK, @@rel_brightness)
                            end
                            view.draw_line(origin, y)
                        end
                    end
                end

                # Draw stuff related to mouse movement
                pos = @state / POINT_END
                axis = @state % POINT_END
                color = @@colors[axis]
                if @state < SELECT_ROTATION_POINT
                    if @state > 0
                        if axis == POINT_ORIGIN
                            view.line_stipple = "-.-"
                            view.drawing_color = color
                            view.draw_line(@ps[SELECT_START][POINT_ORIGIN], @p)
                        else
                            if axis == POINT_Y_AXIS
                                origin = @ps[pos][POINT_ORIGIN]
                                x = @ps[pos][POINT_X_AXIS]
                                y = @p
                                angle = (x - origin).angle_between(y - origin).radians
                                if !float_equal?(90, angle)
                                    blend = BLACK
                                end
                            end
                            view.drawing_color = (blend.nil? ? color : color.blend(blend, @@rel_brightness))
                            view.draw_line(@ps[pos][POINT_ORIGIN], @p)
                        end
                    end
                    view.draw_points(@p, 10, 4, color.blend(WHITE, @@rel_brightness))
                    update_statusbar @@prompt[@state / POINT_END][@state % POINT_END]
                else
                    view.draw_points(@rotation_point, 10, 4, RED)
                    view.draw_points(@p, 10, 4, RED)
                end
            end
            axes_draw(view)    
        end

        def update_statusbar(pre_msg = nil, post_msg = nil)
            @pre_msg = pre_msg   if pre_msg  != nil
            @post_msg = post_msg if post_msg != nil
            s = @pre_msg + "    "
            s += "  #{@modify == MODIFY_START     ? "(+/-)" : ''} #{@start_with  == END_TRANSLATE   ? 'T' : @start_with  == END_ROTATE ? 'R' : ' '}"\
                 "  #{@modify == MODIFY_WHICH_1ST ? "(+/-)" : ''} #{@which_1st   == FIRST_TRANSLATE ? 'TR': 'RT' }"\
                 "  #{@modify == MODIFY_FINISH    ? "(+/-)" : ''} #{@finish_with == END_TRANSLATE   ? 'T' : @finish_with == END_ROTATE ? 'R' : ' '}"\
                 "  #{@modify == MODIFY_METHOD    ? "(+/-)" : ''} #{@method}"\
                 "  Rotate segments: #{@rotate_segments} Translate segments: #{@translate_segments}"
            s += @post_msg
            Sketchup::set_status_text s, SB_PROMPT
        end

        def getExtents
            bb = Geom::BoundingBox.new
            bb.add(@p) if nil != @p
            for pos in (SELECT_START..SELECT_FINISH)
                for axis in (POINT_ORIGIN..POINT_Y_AXIS)
                    p = @ps[pos][axis]
                    bb.add(p) if nil != p
                end
            end
            axes_getExtents(bb)
            bb
        end

        def suspend(view)
            view.invalidate
        end

        def resume(view)
            view.invalidate
            updateVCB
        end

        def updateVCB
            Sketchup::set_status_text "#{@modify == MODIFY_SEGMENTS ? "(+/-) " : ""}Number of segments", SB_VCB_LABEL
        end

        def enableVCB?
          return true
        end

        def onUserText(text, view)
            wrap {
            puts indent "onUserText #{text} #{view}"
            match = text.match /^
                \s*                       # remove leading whitespace
                (?<number>[-+]*\d*\.?\d*) # capture number
                (?<suffix>)#[se]?)        # capture suffix
                (?<garbage>.*)/x          # capture garbage if any
            if !match[:garbage].match(/^\s*$/)
                view.tooltip = 'Invalid input'
            elsif (number = match[:number].to_i) > 0
                @@segments = number
                parameters_changed
                updateVCB
            end
            }
        end

        # onCancel is called when the user hits the escape key
        def onCancel(flag, view)
            @operation_complete = false
            self.reset(view)
        end

        # internal function
        def reset(view)
            @state = SELECT_START
            for pos in (SELECT_START..SELECT_FINISH)
                for axis in (POINT_ORIGIN..POINT_Y_AXIS)
                    @ps[pos][axis] = nil
                    #@@prompt[pos][axis] = "Select " + ["starting", "ending"][pos] + ["origin", "x-axis", "y-axis"][axis]
                end
            end

            view.tooltip = ""
            view.invalidate
        end

        def change_component_axis(component_definition, origin, xaxis, yaxis)
            transformation = Geom::Transformation.axes(origin, xaxis, yaxis)
            # Transform all instances

            component_definition.instances.each{ |instance|
              instance.transform!(transformation)
            }
            # Apply the inverse transformation to the contained entities
            component_definition.entities.transform_entities(transformation.inverse,
                                                                component_definition.entities.to_a)
        end

        def axes_to_linear_map(axes)
            Geom::Transformation.new(
                axes[POINT_ORIGIN],
                axes[POINT_X_AXIS] - axes[POINT_ORIGIN],
                axes[POINT_Y_AXIS] - axes[POINT_ORIGIN])
        end

        # Get
        def axes_to_s(axes)
            "Geom::Transformation.new(\n"\
            "    #{axes[POINT_ORIGIN]},\n"\
            "    #{axes[POINT_X_AXIS]} - #{axes[POINT_ORIGIN]},\n"\
            "    #{axes[POINT_Y_AXIS]} - #{axes[POINT_ORIGIN]})\n"
        end
        
        # Takes a variable and converts any hex value it contains to a decimal
        # number.  If variable is nil, make it 0
        def get_number(x)
            if x.nil?
                number = 0
            else
                number = x.to_i 16
            end
        end

        def id_parse(s)
            match = s.match /^(.*?) *(?:\{([\da-fA-F]+),([\da-fA-F]+)\})?$/
            Assert{ True?(nil != match) { 
                "This should match a leading name, possibly followed by one "\
                "or more spaces, with a possible brace enclosed single or "\
                "tuple of hex numbers."} }
            base_name = match[1] == nil ? "" : match[1]
            if match[2] != nil
                chunk_id, progression_id = get_number(match[2]), get_number(match[3])
            else
                chunk_id, progression_id = 0, 0
            end
            {:name => base_name, :chunk => chunk_id, :id => progression_id, :had_chunk_id? => match[2] != nil}
        end
        
        def id_inc_id(h)
            h[:id] += 1
            h
        end
        
        def id_inc_chunk(h)
            if h[:had_chunk_id?]
                h[:chunk] += 1
            end
            h
        end
        
        def id_to_s(h)
            "#{h[:name]} {#{'%02x' % h[:chunk]},#{'%04x' % h[:id]}}"
        end
        
        # When done, add instances of component in a progression path between the beginning and end points.
        def done
            wrap {
            model = Sketchup.active_model
            entities = model.active_entities

            component_def = @component_instance.definition

            # Generate new instance name based on old one
            name = @component_instance.name
            id = id_parse(name)
            id_inc_chunk(id)
            puts indent "1st element is #{id[:name]}, with chunk id #{id[:chunk]} and progression id #{id[:id]}."
            
            # For starting the undo operation chunk
            model.start_operation "Progression", true

            lm_component = @component_instance.transformation
            # This is the linear matrix (lm) to start from
            lm_from = axes_to_linear_map(@ps[SELECT_START ])
            # and the lm to finish to.
            lm_to   = axes_to_linear_map(@ps[SELECT_FINISH])
            # However we need to change that to be relative to the components
            # lm origin.
            # So these are the lm's relative from the components origin:
            lm_from_adjusted = lm_component
            rotation    = generate_transforms(lm_rotation(lm_from, lm_component, lm_origin_point(lm_component))).reduce(IDENTITY, :*)
            translation = generate_transform( lm_translation(lm_from, lm_component) )
            puts indent var_s(:lm_from, :translation, :rotation, :lm_to) {|_|eval _}
            lm_to_adjusted = lm_to * lm_from.inverse * rotation * translation * lm_from
            
            puts indent "BAHAHAHA!"
            puts indent var_s(:@@segments, :@method){|e| eval e}
            case @method
            when METHOD_ENUM.enum(:sketchup_interpolate)
                for i in (1..@@segments) # TODO: remember lm_to change 0 back lm_to 1
                    puts indent var_s(:i){|e| eval e}
                    lm_partial = Geom::Transformation.interpolate(lm_from_adjusted, lm_to_adjusted, i.to_f/@@segments)

                    id_inc_id(id)
                    id_s = id_to_s(id)
                    puts indent "new instance #{id_s}"

                    instance = entities.add_instance(component_def, lm_partial)
                    instance.name = id_s
                end
            when METHOD_ENUM.enum(:custom_interpolate)
                #instance = entities.add_instance(component_def, lm_from)
                puts var_s(:@start_with, :@finish_with, :@which_1st){|_|eval _};
                
                transformation = Interpolate.new(lm_from_adjusted, lm_to_adjusted, @rotation_point, @@segments,
                    @start_with, @finish_with, @which_1st, debug: true)
                @translate_segments = transformation.translation_segment_count
                @rotate_segments    = transformation.rotation_segment_count
                @pre_msg = "Select rotation point."
                test_equal(lm_translation_only(lm_to_adjusted), lm_translation_only(transformation[-1]), "Doesn't arrive.")
                if transform_equal?(lm_translation_only(lm_to_adjusted), lm_translation_only(transformation[-1]))
                    @post_msg = "  Arrives at t2 "
                    test_equal(lm_to_adjusted,   transformation[-1], "Didn't rotate enough.")
                    if transform_equal?(lm_to_adjusted,   transformation[-1])
                        @post_msg += "properly rotated."
                    else
                        @post_msg += "with rotation off."
                    end
                end
                update_statusbar
                puts "transformation.length = #{transformation.length}"
                transformation.length.times {|i|
                    id_inc_id(id)
                    id_s = id_to_s(id)
                    puts indent "new instance #{id_s}"

                    instance = entities.add_instance(component_def, transformation[i])
                    instance.name = id_s

                    @list.push instance
                    instance.hidden = false
                }
            when :nothing
                # There is an arbitrary rotation point that can be set in space.
                # The start and end point plus the rotation point form a plane.
                rotation_point = @ps[SELECT_FINISH][POINT_ORIGIN]
                start_on_translate = true
                finish_on_translate = false

                if start_on_translate ^ finish_on_translate
                    rotation_segment_count = translation_segment_count = @@segments
                elsif start_on_translate
                    rotation_segment_count    = @@segments - 1
                    translation_segment_count = @@segments
                else
                    rotation_segment_count    = @@segments
                    translation_segment_count = @@segments - 1
                end
                transforms = Interpolate(lm_to, lm_from)
                #puts indent "@point_to_rotate_around-lm_origin_point(t1) : #{@point_to_rotate_around.class.name}-#{lm_origin_point(t1).class.name}"
                #transforms[2][:offset] = @point_to_rotate_around-lm_origin_point(t1)
                #puts indent "#{transforms[2][:offset].class.name}"

                if start_on_translate
                    transform = transforms.rotation(1, rotation_segment_count) * transforms.translate(1, translation_segment_count)
                else
                    transform = transforms.translate(1, translation_segment_count) * transforms.rotation(1, rotation_segment_count)
                end

                t = lm_from
                #t = IDENTITY
                #t = transform.inverse * t
                place_component = ->(i, t) {
                    progression_id += 1
                    name = "#{base_name} {#{'%04x' % progression_id}}"
                    puts indent "new instance #{i}: #{name}"
                    puts to_ts t
                    puts to_oijk t

                    instance = entities.add_instance(component_def, t)
                    instance.name = name
                }
                for i in (1..[rotation_segment_count, translation_segment_count].min)
                    t_only = lm_translation_only t
                    t = transform * t
                    place_component.call(i, t)
                end

                if       rotation_segment_count > translation_segment_count
                    t = rotate * t
                    place_component.call(i+1, t)
                elsif translation_segment_count >    rotation_segment_count
                    t = translate * t
                    place_component.call(i+1, t)
                end
            end
            @operation_complete = model.commit_operation
            }
            rescue
                puts "Exception thrown"
                raise
            ensure
                puts "Done with done"
        end

        def onKeyDown(key, repeat, flags, view)
            puts indent "onKeyDown #{key} #{VK_CONTROL} #{repeat}\n #{'%016b' % flags}\n #{'%016b' % COPY_MODIFIER_KEY}\n #{'%016b' % COPY_MODIFIER_MASK} #{@operation_complete} #{@@segments}"
            @keybindings.handle_key(key, :down)
        end

        def onKeyUp(key, repeat, flags, view)
            puts indent "onKeyup #{key} #{VK_CONTROL} #{repeat}\n #{'%016b' % flags}\n #{'%016b' % COPY_MODIFIER_KEY}\n #{'%016b' % COPY_MODIFIER_MASK}  #{@operation_complete} #{@@segments}"
            @keybindings.handle_key(key, :up)
        end

        def update(model_changed)
            updateVCB
            update_statusbar
            if model_changed
                parameters_changed
            end
        end
        
        def flip(list)
            all_visible = @list.reduce(true) {|a, e| break false if e.hidden?; true }
            only_last_visible = !@list.last.hidden? && !@list[0..-2].reduce(true) {|a, e| break false if e.hidden?; true }
            if all_visible
                @list.each {|e| e.hidden = true }
                @list[0].hidden = false
            elsif only_last_visible
                @list.each {|e| e.hidden = false }
            else
                @list.reduce(false) {|a, e|
                    if a; e.hidden = false; break; end
                    if !e.hidden?; e.hidden = true; true; else; false; end
                }
            end
        end

        def parameters_changed
            Sketchup.undo
            done
        end
    end # class Progression
    ## PROGRESSION end
    
end # module
XXX::eof(__FILE__)