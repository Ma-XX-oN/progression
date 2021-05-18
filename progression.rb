#!/usr/bin/env ruby

require 'sketchup.rb'


module AFH
    # show ruby console
    SKETCHUP_CONSOLE.show

    puts "Loaded " + __FILE__
    if !defined? reload
        # Will eventually need to use this
        # extension = SketchupExtension.new('Progression', 'progression/progression')

        # Menu item
        UI.menu("Plugins").add_item("Reload") {
            ::AFH.reload
        }

        UI.menu("Plugins").add_item("Progression") {
            ::AFH.progression
        }
    end

    #class Common
    class << self
    # Reload extension by running this method from the Ruby Console:
    #   Example::HelloWorld.reload
    def reload
        original_verbose = $VERBOSE
        $VERBOSE = nil
        pattern = File.realpath(__FILE__) #File.join(__dir__, __FILE__)
        Dir.glob(pattern).each { |file|
            puts "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n\nLoading #{file}"
            # Cannot use `Sketchup.load` because its an alias for `Sketchup.require`.
            load file
        }.size
        ensure
        $VERBOSE = original_verbose
    end

    @@indent_count = 0
    def indent(s=nil, char: '|', indent_count: @@indent_count)
        if s == nil
            char * indent_count + " "
        else
            s = s.to_s
            raise_ RuntimeError, "s is #{s.class.name}" if s.class.name != "String"
            s.gsub(/^|(?<=\n)/, indent(nil, char: char, indent_count: indent_count))
        end
    end
    
    def wrap(debug = true, block = Proc.new)
        if debug
            i = caller[0].match(/method_missing/) ? 1 : 0
            caller_string = caller[i]
            caller_string[/^(?:.*\/|)/] = ''
            if (i += 1) < caller.length
                i += caller[i].match(/method_missing/) ? 1 : 0
                from = caller[i]
                from[/^(?:.*\/|)/] = ''
                caller_string += " CALLED FROM #{from}"
            end
            puts indent(caller_string, char: '>')
            @@indent_count += 1
        end
        ret = block.call
        ensure
        if debug
            @@indent_count -= 1
            puts indent(caller_string, char: '<')
        end
        ret
    end
    
    def max_integer_length_in_array(array)
        # sign holder
        character_count = array.min < 0 ? 1 : 0
        max_magnitude = array.map(&:abs).max
        # sign holder + number of digits in integer (log10 domain is >= 0)
        character_count + (1 + (max_magnitude < 10 ? 0 : Math.log10(max_magnitude)))
    end

    def format_float(value, decimal_places, min_integer_length)
        min_string_length = (decimal_places>0?1:0)+decimal_places+min_integer_length
        # Need the string field to pad any end zeros that are stripped from the number
        "% *.*s" % [ min_string_length, min_string_length, "%*.*f" % [min_string_length, decimal_places, value.zero? ? 0 : value.round(decimal_places)] ]
    end

    def to_csv(array1d, decimal_places=4, min_integer_length=nil)
        if min_integer_length == nil
            min_integer_length = max_integer_length_in_array array1d.to_a
        end
        a = array1d.to_a
        s = ""
        if a.length > 0
            s = format_float(a[0], decimal_places, min_integer_length)
            (1..a.length-1).each { |i| s += ", " + format_float(a[i], decimal_places, min_integer_length) }
        end
        s
    end

    def to_ts(transform, decimal_places = 4)
        return "nil" if transform == nil
        
        raise_ ArgumentError, "transform is a '#{transform.class.name}' instead of 'Geom::Transformation'" if transform.class.name != "Geom::Transformation"
        array = transform.to_a
        min_integer_length = 1 + max_integer_length_in_array(array)
        s = transform.to_a.each_slice(4).inject("") { |str, row| str + to_csv(row, decimal_places, min_integer_length) + ",\n" }
        s = "Geom::Transformation.new([\n#{s}])"
    end

    def print_callstack
        puts "### vvv CALLSTACK vvv ###"
        caller.each {|e|
            puts e.sub(/^(?:.*\/|)/,"") if !e.match(/`(call|print_callstack|wrap|raise_|method_missing|assert(?:_[^']*)?)'/)
        }
        puts "### ^^^ CALLSTACK ^^^ ###"
    end
    
    def raise_(*args)
        print_callstack
        raise *args
    end
    
    def print_transform(transform, decimal_places = 4)
        puts indent to_ts(transform, decimal_places)
    end

    def to_ijko(transform, decimal_places = 4)
        i = p2v(Geom::Point3d.new([1,0,0]).transform(transform)).normalize!
        j = p2v(Geom::Point3d.new([0,1,0]).transform(transform)).normalize!
        k = p2v(Geom::Point3d.new([0,0,1]).transform(transform)).normalize!
        o = p2v(Geom::Point3d.new([0,0,0]).transform(transform)).normalize!
        min_integer_length = max_integer_length_in_array [i.to_a, j.to_a, k.to_a, o.to_a].flatten
        s = "i = #{to_csv(i, decimal_places, min_integer_length)}\n" +
            "j = #{to_csv(j, decimal_places, min_integer_length)}\n" +
            "k = #{to_csv(k, decimal_places, min_integer_length)}\n" +
            "o = #{to_csv(o, decimal_places, min_integer_length)}\n"
    end
    
    def print_ijko(transform, decimal_places = 4)
        print indent to_ijko(transform, decimal_places)
    end

    # multiply a scalar (x) with an object (m) that can convert to a 1d array (via to_a) and who's type can create a new object when passed a 1d array with the same number of elements.
    def mult(x, y)
        case x
        when Fixnum, Float
            if y === Fixnum || y === Float
                x * y
            elsif defined?(y.to_a); begin
                array = y.to_a.map { |e| e*x }
                y.class.new array
                rescue
                    raise_ RuntimeError, "Can't convert Array to #{y.class}"
                end
            else
                raise_ ArgumentError, "Not sure how to mult a #{x.class} with a #{y.class}"
            end
        end
    end

    def progression
        # ensure a component is selected
        model = Sketchup.active_model
        selection = model.selection
        if selection.length != 1 || selection[0].class.to_s != "Sketchup::ComponentInstance"
            UI.messagebox("Select one and only one component.")
            model.select_tool
            return
        end
        
        model.select_tool(Progression.new selection[0])
    end

    @@precision = 0.0001
    
    def transform_equal?(t1, t2, precision: @@precision)
        [t1.to_a, t2.to_a].transpose.inject(true) { |prev, comp| prev &= float_equal?(comp[0], comp[1], precision: precision) }
    end
    
    def float_equal?(x1, x2, precision: @@precision)
        (x1 - x2).abs <= precision
    end

    def testing?
        true
    end
    
    def v2p(v)
        assert(v.instance_of?(Geom::Vector3d), "Can't convert from #{v.class}! Expecting Vector3d!")
        Geom::Point3d.new(*v)
    end
    
    def p2v(v)
        assert(v.instance_of?(Geom::Point3d), "Can't convert from #{v.class}! Expecting Point3d!")
        Geom::Vector3d.new(*v)
    end
    
    # This generates an object that describe an equivalent translate
    # and two orthogonal rotate transforms which can be used to get
    # intermediate transforms to go from t2 to t1.
    #
    # NOTE: This function will currently not work well unless one of the xy,
    #       yz or zx planes are parallel to the others vector space.  The
    #       reason is that when there are two orthogonal rotations, accuracy is
    #       compromised unless the number of segments are high or the rotations
    #       are small.
    #
    #       There might be a better algorithm that would minimize this error,
    #       or use numerical methods to find a single rotation and rotation axis
    #       (does that even make sense? think so) but I don't have the time atm.
    #
    #       TO BE revisited later when I have more time.
    #
    def transform_t1_to_t2(t1, t2, debug: false)
        wrap(debug) {
        if debug; puts indent "t1 = #{to_ts t1}"; end
        if debug; puts indent "t2 = #{to_ts t2}"; end
        # Our target is to find up to one translation and up to two rotations
        # that would transform vector space t1 into t2.
        #   rtc ttc t1 = t2
        # We then move the system relative to t2.
        #   rtc ttc t1 t2.inverse = IDENTITY
        # The (ttc t1 t2.inverse) term is t1 moved to global origin, so
        #   ttc = translation_only(t1 t2.inverse).inverse
        translate = translation_only(t1 * t2.inverse).inverse
        puts indent "translate = #{to_ts translate}"
        assert_equal(IDENTITY, translation_only(translate * t1 * t2.inverse), "Didn't move t1 to t2's new origin, which is the global origin.")
        assert_equal(IDENTITY, translate * translation_only(t1 * t2.inverse), "Didn't move t1 to t2's new origin, which is the global origin.")
        translate_info = { :op => :translate, :offset => origin_point(translate) }
        rotate_info = []
        
        # Find rotations to get translate_to_t2's axes to overlap
        # IDENTITY's axes.
        #   rtc ttc t1 t2.inverse = IDENTITY
        transform = translate * t1 * t2.inverse
        assert_equal(transform, generate_transform(translate_info) * t1 * t2.inverse, "Sync error.")
        same_lines = 0
        axes = [X_AXIS, Y_AXIS, Z_AXIS]
        axes.each_with_index {|target_axis, i| 
            wrap(debug) {
                break if transform_equal?(IDENTITY, transform)
                
                if debug; puts indent "target_axis = #{target_axis}"; end
                if debug; puts indent "target_axis.transform(transform) = #{p2v v2p(target_axis).transform(transform)}"; end
                if debug; puts indent "transform = #{to_ts transform}"; end
                new_axis = p2v(v2p(target_axis).transform(transform))
                angle = new_axis.angle_between(target_axis).radians
                if debug; puts indent "angle = #{angle}"; end

                # If axes lie on the same line and in the same direction, then check next axis.
                next if float_equal?(angle, 0)
                
                if float_equal?(angle, 180)
                    puts "i = #{i}"
                    # if the axes lie on the same line but in the opposite direction, pick a known perpendicular vector.
                    rotate_vector = axes[(i+2)%3]
                else
                    # calculate a perpendicular vectors
                    rotate_vector = new_axis.cross(target_axis)
                end
                assert(rotate_vector.valid?, "Zero vector detected.")
                
                rotate_info.unshift({ :op => :rotate, :angle => angle, :axis => rotate_vector })
                if debug; puts indent "rotate_info = #{rotate_info}"; end
                if debug; puts indent "generate_transform(rotate_info.first) = #{to_ts generate_transform(rotate_info.first)}"; end
                transform = generate_transform(rotate_info.first) * transform
                if debug; puts indent "updated transform = #{to_ts transform}"; end
            }
        }
        assert_equal(transform, IDENTITY)

        object = Fractional_distance_and_orientaion.new t1, t2, translate_info, rotate_info
        if false && debug # additional tests
            assert_equal(object.interpolate(0, 1) * t1, t1, "Cannot find appropriate transforms to t1.  Found translate #{translate_info} and rotate #{rotate_info}.")
            total_length = (origin_point(t1) - origin_point(t2)).length
            count = 5
            # (count+1).times { |i|
                # partial_length_to_t2 =
                    # (origin_point(object.translate(i, count) * t1) - origin_point(t2)).length
                # assert_equal(partial_length_to_t2 / total_length, (count - i).to_f/count,
                    # "Distance remaining to t2 is not (#{count} - #{i})/#{count} or #{(count - i).to_f/count}.  It's #{partial_length_to_t2 / total_length}.")

                # partial_length_from_t1 =
                    # (origin_point(  object.translate(i, count) * t1) - origin_point(t1)).length
                # assert_equal(partial_length_from_t1, total_length * i.to_f / count,
                    # "Distance isn't correct for #{i}/#{count} of a move.")
            # }
            assert_equal(object.interpolate(1, 1) * t1, t2, "Cannot find appropriate transforms to t2.  Found translate #{translate_info} and rotate #{rotate_info}.")
        end
        return object
        }
    end
    
    def test_helper(t1, t2, translate_info, rotate_info, debug: false)
        wrap {
        
        # Tests
        if debug; puts indent "### TESTING!! ###"; end
        if debug; puts indent "translate_info = #{translate_info}"; end
        if debug; puts indent "rotate_info    = #{rotate_info}"   ; end
        
        # tt  = translate transform,                tta = translate transform accumulator,
        # ttt = translation transform total (tt^n), ttc = translation transform complete (ttc = tt as if n were 1),
        # rt  = rotation transform,                 rta = rotation transform accumulator,
        # rtt = rotation transform total (rt^n),    rtc = rotation transform complete (rtc = rt as if n were 1)
        
        # The following is the way how I figured out how to incrementally move
        # and rotate from vector space t1 to t2.
        #
        # Let's say that we want to describe a distance and rotation
        # between two vector spaces t1 to t2.  Thus:
        #
        #   rtc ttc t1 = t2
        #
        # If the rotation is to occur at t2's origin, then we can move the
        # problem into t2's vector space to simplify our rotations.  Thus
        # t2 becomes the IDENTITY's vector space by multiplying both sides
        # by t2.inverse on the right.
        #
        #    rtc ttc t1 t2.inverse = IDENTITY
        #
        # And then find the translation to get from t1 to t2:
        #
        #    ttc translation_only(t1 t2.inverse) = IDENTITY
        #    ttc = translation_only(t1 t2.inverse).inverse
        #
        # Finally we find the rotation around the origin by finding a rotation
        # (or a composite of rotations) that brings t1 in line with t2.
        #
        #    rtc = t2 t1.inverse ttc.inverse
        #
        # This is done by finding the rotation and rotation axis to get t1's
        # x-axis to line up with the IDENTITY's x-axis, and then do the same
        # for the y-axis and z-axis.  NOTE that we only need two of them to
        # force the 3rd into alignment.
        
        rtc = generate_transforms(rotate_info).inject(:*)
        ttc = generate_transform(translate_info)

        puts "t2 = #{to_ts t2}\nti = #{to_ts t1}\nttc = #{to_ts ttc}\nrtc = #{to_ts rtc}"
        rtc_ = t2 * t1.inverse * ttc.inverse
        ttc_ = rtc.inverse * t2 * t1.inverse 
        
        assert_equal(IDENTITY, rtc * ttc * t1 * t2.inverse)
        # Surprised by the lack of precision.
        assert_equal(IDENTITY, t2.inverse * rtc * ttc * t1, precision: 0.02)
        assert_equal(t2, rtc * ttc * t1, precision: 0.02)

        # Check if these are correct
        #
        #   rtc_ == rtt == rtc
        #   ttc_ == ttt == ttc
        assert_equal(rtc_, rtc)
        assert_equal(ttc_, ttc, precision: 0.04)
        
        if debug; puts indent "### Testing that ttt == ttc and rtt == rtc for a few different n values."; end
        1.upto(5). each {|n|
            if debug; puts indent "n = #{n}"; end
            tt = generate_transform(translate_info, 1.0/n)
            assert_equal(ttc, (n.times.inject(IDENTITY) { |tta| tt * tta }))
            rt = generate_transforms(rotate_info, 1.0/n).inject(:*)
            assert_equal(rtc, (n.times.inject(IDENTITY) { |rta| rt * rta }), precision: 0.1)
        }

        if debug; puts indent "### Testing approach of t2 from t1."; end
        puts indent "translate_info = #{translate_info}"
        puts indent "rotate_info = #{rotate_info}"
        m = 2
        10.upto(15). each {|n|
            if debug; puts indent "n = #{n}"; end
            full_length = Float(origin_difference(t2, t1).length)
            if debug; puts indent "full_length = #{full_length}"; end
            
            # prefix
            #  tt - translation transform |  ta - translation accumulator          |  t - translation of t1
            #  rt - rotation transform    | rta - rotation translation accumulator | rt - rotation translation of t1
            #
            # suffix:
            #  _1 - one unit              |   _m - one mth of a unit
         
            # For testing n size
            tt_1 = generate_transform(translate_info, 1.0/n)
            rt_1 = generate_transforms(rotate_info, 1.0/n).inject(:*)
            
            # For testing n*m size
            tt_m = generate_transform(translate_info, 1.0/(n*m))
            rt_m = generate_transforms(rotate_info, 1.0/(n*m)).inject(:*)
            
            obj = Fractional_distance_and_orientaion.new(t1, t2, translate_info, rotate_info)
            (ta_1, rta_1, ta_m, rta_m) =
            n.times.inject([IDENTITY,IDENTITY,IDENTITY,IDENTITY]) { |(ta_1, rta_1, ta_m, rta_m), j|
                puts "j/n   = #{j}/#{n}"
                # puts "ta_1  = #{to_ts ta_1}\n"\
                     # "rta_1 = #{to_ts rta_1}\n"\
                     # "ta_m  = #{to_ts ta_m}\n"\
                     # "rta_m = #{to_ts rta_m}\n"
                assert_equal(ta_1, obj.translate(j, n))
                assert_equal(rta_1, obj.rotate(j, n))
                
                pt_1  = ta_1 * t1
                prt_1 = rta_1 * pt_1
                partial_length_1 = [origin_difference(t2, pt_1).length, origin_difference(t2, prt_1).length].
                    map {|e| full_length - e}
                
                (ta_m, rta_m) = m.times.inject([ta_m, rta_m]) { |(ta_m, rta_m), i|
                    puts "i/m = #{i}/#{m}"
                    # puts "ta_m = #{to_ts ta_m}"
                    # puts "t1 = #{to_ts t1}"
                    pt_m  = ta_m * t1
                    prt_m = rta_m * pt_m
                    partial_length_m = [origin_difference(pt_m, t2).length, origin_difference(prt_m, t2).length].
                        map {|e| full_length - e}

                    # puts "% movement: #{partial_length_m[0]/full_length}, #{partial_length_m[1]/full_length}, #{(i.to_f+j*m)/(n*m)}"
                    assert_equal(partial_length_m[0]/full_length, (i+j*m).to_f/(n*m),
                        "Distance isn't changing an even amount when translating", precision: 0.1)
                    assert_equal(partial_length_m[1]/full_length, (i+j*m).to_f/(n*m),
                        "Distance isn't changing an even amount when translating and rotating", precision: 0.1)
                    [tt_m * ta_m, rt_m * rta_m]
                }
                ta_1  = tt_1 *  ta_1
                rta_1 = rt_1 * rta_1
                assert_equal(ta_m,  ta_1,  "m cumulative smaller translations don't equal 1 large translation", precision: 0.1)
                assert_equal(rta_m, rta_1, "m cumulative smaller rotations don't equal 1 large rotation translation", precision: 0.1)
                
                assert_equal(partial_length_1[1]/full_length, j.to_f/n,
                    "Distance isn't changing an even amount when translating and rotating", precision: 0.1)
                assert_equal(partial_length_1[0]/full_length, j.to_f/n,
                    "Distance isn't changing an even amount when translating", precision: 0.1)
            
                [ta_1, rta_1, ta_m, rta_m]
            }
            
            assert_equal(ttc, ta_1)
            assert_equal(ttc, ta_m)
            assert_equal(rtc, rta_1)
            assert_equal(rtc, rta_m)

        }
        
        # Now our first equation can be rewritten as:
        #
        #   t2 == rt^i tt^i t1
        #
        # Where rt and tt are transforms that will incrementally move and
        # rotate from t1 to t2.
        #
        # Because we want to approach t2 from t1, we find the translation
        # only matrix of t1 t2.inverse:
        #
        #   IDENTITY
        #       == rtc translation_only(t1 t2.inverse) t1 t2.inverse
        #
        # Which is pretty simple as you subtract the origin in t2's space from
        # the origin in t1's space, divide it by n and put that into a
        # translation matrix.
        #
        # Now to break up the rotations in the same way, we need to find the
        # actual rotation value that we can divide by.  This can be done by
        # using dot and cross product identities and is left up to the reader.
        # Though, I will say that you will have to do it on multiple orthogonal
        # axes if the rotation isn't along just one of them.
        # However, assuming that this can be done, we can now find the
        # appropriate rotation and translation that is i/n away between t1 and
        # t2.
        #
        #    fractional_distance_and_orientaion(i)
        #       = rt^i * tt^i * t1
        #
        # NOTE that the following may not be correct and doesn't need to be
        # taken into account.
        # When dealing with 2 (or more in higher dimensional vector space)
        # rotations on orthogonal axes, the discreet fractional angles
        # between the two vector spaces become closer to the actual single
        # transform only when n approaches +Infinity.  This can be
        # approximated by using larger values of n, as the largest of the
        # rotations gets closer to pi radians, or 180 degrees.  As there is
        # no one way to describe such a transform, the object would be to
        # minimize the angles.  That, or
        # somehow determining the actual combined angle and rotation vector,
        # perhaps by numerical methods.  This will have to be taken into
        # account when implementing rotations that don't lie on one of the
        # orthogonal standard planes.
        # A partial workaround would be to change the axis to the something
        # that would fit within these constraints, if possible.  As I don't
        # need this functionality immediately, I'll leave it for now.
        if debug; puts indent "### TESTING COMPLETE ####################"; end
        }
    end

    class Fractional_distance_and_orientaion
        #include AFH
        # include doesn't work consistently for some reason, so redirecting using method_missing.
        # if the function cannot be found in this class, then check ::AFH.
        def method_missing(method, *args, &block)
            if ::AFH.respond_to?(method)
                ::AFH.send(method, *args, &block)
            else
                super
            end
        end

        def initialize(t1, t2, translate_info, rotate_info)
            wrap {
            #raise_ RuntimeError, "Rotation should only happen on one axis for now" if rotate_info.length > 1
            @t1 = t1
            @t2 = t2
            @translate_info = translate_info
            @rotate_info = rotate_info
            puts "@translate_info = #{@translate_info}"
            puts "@rotate_info = #{@rotate_info}"
            }
        end
        
        def update_cache(which_segment, segments, debug: false)
            if segments == @segments
                # values cached, do nothing
                if debug; puts indent "Partials for #{segments} segments are up to date"; end
            else
                if debug; puts indent "Updating partials for #{segments} segments"; end
                @partial_translate_transform = generate_transform  @translate_info, 1.0/segments
                @partial_rotate_transform    = generate_transforms(@rotate_info   , 1.0/segments).inject(:*)
                if debug; puts indent "partial_translate_transform = #{to_ts @partial_translate_transform}"; end
                if debug; puts indent "partial_rotate_transform    = #{to_ts @partial_rotate_transform}"; end
                @segments = segments
            end
            
            # This would be better if I knew how to take a matrix to an
            # exponent.  For now, I'll just multiply successive
            # translations and rotations to generate needed matrices.  This
            # can result in cumulative rounding errors, so I really should
            # use the proper method when I get the chance.
            #
            # TODO: Update with function taking matrix to power
            if which_segment == @which_segment
                if debug; puts indent "Already have information for segment #{which_segment}/#{segments} "; end
                # do nothing
            elsif which_segment - 1 == @which_segment
                if debug; puts indent "Calc information for next segment #{which_segment}/#{segments}"; end
                @cumulative_translate_transform *= @partial_translate_transform
                @cumulative_rotate_transform    *= @partial_rotate_transform
                @which_segment = which_segment
            else
                if debug; puts indent "Calc complete information for #{which_segment}/#{segments}"; end
                @cumulative_translate_transform = which_segment.times.inject(IDENTITY) { |a| a * @partial_translate_transform }
                @cumulative_rotate_transform    = which_segment.times.inject(IDENTITY) { |a| a * @partial_rotate_transform }
                if debug; puts indent "@cumulative_translate_transform = #{to_ts @cumulative_translate_transform}"; end
                if debug; puts indent "@cumulative_rotate_transform = #{to_ts @cumulative_rotate_transform}"; end
                @which_segment = which_segment
            end

            t = @cumulative_translate_transform
            total_length   = (origin_point(    @t2)-origin_point(@t1)).length.to_f
            length_between_tn_and_t2 = (origin_point(t * @t1)-origin_point(@t2)).length.to_f
            length_between_t1_and_tn = (origin_point(t * @t1)-origin_point(@t1)).length.to_f
            # assert_equal(length_between_t1_and_tn + length_between_tn_and_t2, total_length)
            assert_equal(total_length * which_segment / segments, length_between_t1_and_tn)
            
            #assert_equal((origin_point(@t1)-origin_point(t * @t1)).length, total_length*which_segment/segments, "Doesn't equal IDENTITY?")
            # if debug; puts "which_segment / segments = #{which_segment} / #{segments} = #{which_segment.to_f / segments}"; end
            # if debug; puts "length_between_tn_and_t2 / total_length = #{length_between_tn_and_t2} / #{total_length} = #{length_between_tn_and_t2 / total_length}"; end
            # assert_equal(which_segment.to_f / segments, length_between_tn_and_t2 / total_length,
                # "#{which_segment} is not #{which_segment.to_f / segments} away from t1 as it is from t2.  It is instead #{length_between_tn_and_t2 / total_length}.")
        end
        
        def translate(which_segment, segments)
            update_cache(which_segment, segments)
            @cumulative_translate_transform
        end
        
        def rotate(which_segment, segments)
            update_cache(which_segment, segments)
            @cumulative_rotate_transform
        end
        
        def interpolate(which_segment, segments, translate_first: true, debug: false)
            update_cache(which_segment, segments, debug: debug)
            if translate_first
                return @cumulative_rotate_transform * @cumulative_translate_transform
            else
                return @cumulative_translate_transform * @cumulative_rotate_transform
            end
        end
        
        def test(t1, t2, debug)
            test_helper(t1, t2, @translate_info, @rotate_info, debug: debug)
        end
    end

    def test_helper2(t1, t2, debug: false)
        puts "t1 = #{to_ts t1}"
        puts "t2 = #{to_ts t2}"
        object = transform_t1_to_t2(t1, t2, debug: debug)
        object.test(t1, t2, debug: debug)
        (1..5).each { |n|
            puts "n = #{n}"
            #    fractional_distance_and_orientaion(i)
            #       = rt^i * tt^i * t1
            assert_equal(t1, object.rotate(0,n) * object.translate(0,n) * t1, "At beginning.")
            assert_equal(t2, object.rotate(n,n) * object.translate(n,n) * t1, "At end.")
        }
    end

    def test_transform_t1_to_t2(step = 1)

        t1 = Geom::Transformation.translation([rand, rand, 0]) *
             Geom::Transformation.rotation([rand, rand, 0], [0, 0, rand], 360.degrees*rand)
        t2 = Geom::Transformation.translation([rand, rand, 0]) *
             Geom::Transformation.rotation([rand, rand, 0], [0, 0, rand], 360.degrees*rand)

        t1 = Geom::Transformation.translation([1, 0, 0]) *
             Geom::Transformation.rotation([1, 1, 0], [0, 0, 1], 0.degrees)#360.degrees*rand)
        t2 = Geom::Transformation.translation([1, 0, 0]) *
             Geom::Transformation.rotation([1, 1, 0], [0, 0, 1], 360.degrees*rand)

        # Rotating vector spaces random amounts around the same axis causes problems w.r.t. interval spacing not being constant.

        if false
            # Displacing 0 units away with 180 rotation.
            # Getting NaN for % to total distance is expected for 0 displacement as it is already where it is supposed to be.
            a1 = 0#rand*2*Math::PI
            a2 = 180.degrees#rand*2*Math::PI
            puts "a1 = #{a1.radians}\na2 = #{a2.radians}\ndiff = #{(a2-a1).radians}"
            t1 = Geom::Transformation.translation([0, 0, 0]) * Geom::Transformation.rotation([0, 0, 0], [0, 0, 1], 0)
            t2 = Geom::Transformation.translation([0, 0, 0]) * Geom::Transformation.rotation([0, 0, 0], [0, 0, 1], a2)
            test_helper2(t1, t2)
        end

        if false && true
            # Displacing 1 unit on x axis
            a1 = 0#rand*2*Math::PI
            a2 = 180.degrees#rand*2*Math::PI
            puts "a1 = #{a1.radians}\na2 = #{a2.radians}\ndiff = #{(a2-a1).radians}"
            t1 = Geom::Transformation.translation([1, 0, 0]) * Geom::Transformation.rotation([0, 0, 0], [0, 0, 1], 0)
            t2 = Geom::Transformation.translation([0, 0, 0]) * Geom::Transformation.rotation([0, 0, 0], [0, 0, 1], a2)
            test_helper2(t1, t2, debug: true)
        end

        if false && true
            # Changing axis of rotation
            a1 = rand*360.degrees
            a2 = rand*360.degrees
            puts "a1 = #{a1.radians}\na2 = #{a2.radians}\ndiff = #{(a2-a1).radians}"
            t1 = Geom::Transformation.translation([2, 0, 0]) * Geom::Transformation.rotation([0, 0, 0], [0, 0, 1], 0)
            t2 = Geom::Transformation.translation([0, 0, 0]) * Geom::Transformation.rotation([0, 0, 0], [0, 1, 1], a2)
            test_helper2(t1, t2, debug: true)
        end

        if false
            # Changing axis of rotation
            a1 = rand*360.degrees
            a2 = rand*360.degrees
            puts "a1 = #{a1.radians}\na2 = #{a2.radians}\ndiff = #{(a2-a1).radians}"
            t1 = Geom::Transformation.translation([2, 0, 0]) * Geom::Transformation.rotation([0, 0, 0], [0, 0, 1], 0)
            t2 = Geom::Transformation.translation([1, 0, 0]) * Geom::Transformation.rotation([0, 0, 0], [0, 1, 1], a2)
            test_helper2(t1, t2, debug: true)
        end

        if false
            # Randomise everything
            t1 = Geom::Transformation.translation([rand, rand, rand]) * Geom::Transformation.rotation([0, 0, 0], [rand, rand, rand], rand)
            t2 = Geom::Transformation.translation([rand, rand, rand]) * Geom::Transformation.rotation([0, 0, 0], [rand, rand, rand], rand)
            test_helper2(t1, t2, debug: true)
        end

        if true
            t1 = Geom::Transformation.new([
                0.0000,     0.0000,    -1.0000,     0.0000,
                1.0000,     0.0000,     0.0000,     0.0000,
                0.0000,    -1.0000,     0.0000,     0.0000,
              129.0409,    84.3394,    27.0000,     1.0000,
            ])
            t2 = Geom::Transformation.new([
               -0.7373,     0.0000,    -0.6756,     0.0000,
                0.6756,     0.0000,    -0.7373,     0.0000,
                0.0000,    -1.0000,     0.0000,     0.0000,
              141.0965,    84.3394,    27.0844,     1.0000,
            ])
            test_helper2(t1, t2, debug: true)
        end
    end
    
    def sub(lhs, rhs)
        assert(lhs.class == rhs.class, "Class types #{lhs.class} and #{rhs.class} are not the same.")
        assert(defined?(lhs.class.private_instance_methods(false).include?(:initialize)) == "method",
            "Class #{lhs.class} must define 'new' method.")
        if defined?(lhs.to_a)
            lhs.class.new([lhs.to_a, rhs.to_a].transpose.map { |a,b| a-b })
        else
            lhs - rhs
        end
    end

    def max_diff(lhs, rhs)
        ([lhs.to_a, rhs.to_a].transpose.map { |a,b| a-b }).map(&:abs).max
    end
    
    def assert_msg(msg)
        msg == "" ? "" : msg + " "
    end
    
    def as_instantiated(x)
        if defined?(x.class.private_instance_methods(false).include?(:initialize)) == "method"
            if defined?(x.to_a) == "method"
                "#{x.class}.new(#{to_csv x})"
            else
                "#{x.class}.new(#{x})"
            end
        else
            "#{x}"
        end
    end
        
    def assert(test, msg= "")
        if !test
            raise_ RuntimeError, "### ERROR: #{assert_msg(msg)}Test failed!\n####"
        end
    end
    
    # Begining Of Error Message
    BOEM = "\n#### ERROR: "
    # Begining Of Warning Message
    BOWM = "#### WARNING: "
    # End Of Error Message
    EOEM = "\n####"
    def test_equal(lhs, rhs, msg= "", precision: @@precision)
        assert_equal(lhs, rhs, msg, precision: precision, stop: false)
    end
    
    def assert_equal(lhs, rhs, msg= "", precision: @@precision, stop: true)
        if lhs.kind_of?(Float) && rhs.kind_of?(Numeric) || lhs.kind_of?(Numeric) && rhs.kind_of?(Float)
            return if float_equal?(lhs, rhs, precision: precision)
            
            diff = (lhs - rhs).abs
            err_msg = "#{assert_msg msg}Floats not same!\n"\
                      "lhs = #{lhs}\n"\
                      "rhs = #{rhs}\n"\
                      "rhs-lhs = #{rhs-lhs}"
                                
        elsif lhs.kind_of?(Geom::Transformation) && rhs.kind_of?(Geom::Transformation)
            return if transform_equal?(lhs, rhs, precision: precision)
                
            err_msg = "#{assert_msg msg}Matrices not same!\n"\
                      "lhs = #{indent(to_ts(lhs), char: ' ', indent_count: 1).lstrip}\n"\
                      "rhs = #{indent(to_ts(rhs), char: ' ', indent_count: 1).lstrip}\n"\
                      "rhs-lhs = #{indent(to_ts(sub rhs,lhs), char: ' ', indent_count: 1).lstrip}\n"\
                      "max_diff = #{max_diff lhs,rhs}"
      
        elsif lhs.kind_of?(Geom::Point3d) && rhs.kind_of?(Geom::Point3d) ||
                lhs.kind_of?(Geom::Vector3d) && rhs.kind_of?(Geom::Vector3d)
            return if [lhs.to_a, rhs.to_a].transpose.inject(true) {|a, (e1, e2)| a && float_equal?(e1, e2, precision: precision) }
                
            err_msg = "#{lhs.class} objects not same!\n"\
                      "lhs = #{as_instantiated lhs}\n"\
                      "rhs = #{as_instantiated rhs}\n"\
                      "rhs-lhs = #{sub rhs,lhs}\n"\
                      "max_diff = #{max_diff lhs,rhs}"
      
        else
            return if lhs == rhs
        
            err_msg = "#{assert_msg msg}Values are not same!"\
                      "lhs = #{as_instantiated lhs}\n"\
                      "lhs.class = #{lhs.class}\n"\
                      "rhs = #{as_instantiated rhs}"\
                      "rhs.class = #{lhs.class}"
        end
        
        if stop
            raise_ RuntimeError, BOEM + indent(err_msg, char: ' ', indent_count: 4).lstrip + EOEM
        else
            puts                BOWM + indent(err_msg, char: ' ', indent_count: 4).lstrip + EOEM
        end
    end

    def equal?(lhs,rhs, precision: @@precision)
        if (lhs.kind_of?(Float) && rhs.kind_of?(Numeric) || lhs.kind_of?(Numeric) && rhs.kind_of?(Float))

            float_equal?(lhs, rhs, precision: precision)
                
        elsif lhs.kind_of?(Geom::Transformation) && rhs.kind_of?(Geom::Transformation)
        
            transform_equal?(lhs, rhs, precision: precision)

        elsif lhs.kind_of?(Geom::Point3d) && rhs.kind_of?(Geom::Point3d) ||
                lhs.kind_of?(Geom::Vector3d) && rhs.kind_of?(Geom::Vector3d)
                
            [lhs.to_a, rhs.to_a].transpose.inject(true) {|a, (e1, e2)| a && float_equal?(e1, e2, precision: precision) }
                
        else
            lhs != rhs
        end
    end
    
    # Converts a hash into a Transformation.  Each hashs has a :op parameter,
    # which can be set to :rotate, :translate, or :scale.
    #   :rotate requires :axis and :angle. :origin defaults to ORIGIN if not
    #     present.
    #   :translate requires :offset
    #   :scale requires either :xscale, :yscale or :zscale.  If any of those
    #     are missing, then :scale must be present.  :origin defaults to ORIGIN
    #     if not present.
    def generate_transform(hash, percent=1)
        debug = false
        wrap(debug) {
            raise_ ArgumentError, "No operation specified" if !hash.key?(:op)
            if debug; puts indent "hash = #{hash} percent = #{percent}"; end
            case hash[:op]
            when :rotate
                if float_equal?(0.0, hash[:angle], precision: 0.000001) || float_equal?(hash[:axis].length, 0, precision: 0.000001)
                    raise_ RuntimeError, "Attempting to generate a transform from an angle of 0 or a zero vector.  Could convert into IDENTITY, but this could cause slight performance issues as multiplying by this is just what it was multiplied with.  So, just don't convert such information to avoid unnecessary matrix multiplication."
                else
                    origin = hash.key?(:origin) ? hash[:origin] : ORIGIN
                    angle = hash[:angle] * percent
                    t = Geom::Transformation.rotation(origin, hash[:axis], angle.degrees)
                    if debug; puts indent "Geom::Transformation.rotation(#{origin}, #{hash[:axis]}, #{angle}) = #{to_ts t}"; end
                end
            when :translate
                raise_ ArgumentError, 'Translation requires :offset argument' if !hash.key?(:offset)
                offset = mult(percent, hash[:offset])
                t = Geom::Transformation.translation(offset)
                if debug; puts indent "Geom::Transformation.translation#{offset} = #{to_ts t}"; end
            when :scale
                xscale = percent * get_prioritized_value(hash, :xscale, :scale, "Scaling requires either :%s or :%s argument")
                yscale = percent * get_prioritized_value(hash, :yscale, :scale, "Scaling requires either :%s or :%s argument")
                zscale = percent * get_prioritized_value(hash, :zscale, :scale, "Scaling requires either :%s or :%s argument")
                origin = hash.key?(:origin) ? hash[:origin] : ORIGIN
                t = Geom::Transformation.scaling(origin, xscale, yscale, zscale)
                if debug; puts indent "Geom::Transformation.scale(#{origin}, #{xscale}, #{yscale}, #{zscale}) = #{to_ts t}"; end
            else
                raise_ ArgumentError, "Unknown operation \"#{op}\""
            end
            if debug; puts indent "t = #{to_ts t}\n#{to_ijko t}"; end
            t
        }
    end

    def generate_transforms(array_of_hashes, percent=1)
        if array_of_hashes.length == 0
            [IDENTITY]
        else
            array_of_hashes.map {|e| generate_transform(e, percent) }
        end
    end
    
    def get_prioritized_value(e, *keys)
        for key in keys
            break if e.key?(key)
        end
        raise_ ArgumentError, error_msg % keys if !e.key?(key)
        e[key]
    end

    # Take the origin of t2 and subtract the origin of t1.
    def origin_difference(t1, t2)
        o1 = origin_point(t1)
        o2 = origin_point(t2)
        o1 - o2
    end

    def translation_only(t)
        a = t.to_a
        Geom::Transformation.new([1,0,0,0, 0,1,0,0, 0,0,1,0, a[12],a[13],a[14], 1])
    end

    def origin_point(t)
        a = t.to_a
        Geom::Point3d.new(a[12],a[13],a[14])
    end
    end # class << self
    #end # class Common
    
    class Progression
        VK_OEM_MINUS = 0xBD
        VK_OEM_PLUS  = 0xBB

        START   = 0 # Transform points start
        FINISH  = 1 # Transform points finish
        POINTS  = 2 # Number of transform points
        
        ORIGIN_P  = 0 # Origin point
        X_AXIS_P  = 1 # X axis point (vector is X_AXIS_P - ORIGIN_P)
        Y_AXIS_P  = 2 # Y axis point (vector is Y_AXIS_P - ORIGIN_P)
        AXIS_PS = 3 # Number of axis points
        
        #PICK_ROTATION_P = 6
        FINISHED = 6
        
        @@prompt = nil
        @@segments = 12
        
        # # if the function cannot be found in this class, then check ::AFH.
        def method_missing(method, *args, &block)
            if ::AFH.respond_to?(method)
                x = ::AFH.send(method, *args, &block)
                #puts "xx.name = #{x.class.name}"
                x
            else
                super
            end
        end
        
        # including a module is cleaner than defining method_missing in the way
        # shown above.
        #include ::AFH

        def initialize(component)            
            @component_instance = component
            if @@prompt == nil
                @@prompt = Array.new(POINTS){ Array.new(AXIS_PS) }
                for pos in (START..FINISH)
                    for axis in (ORIGIN_P..Y_AXIS_P)
                        @@prompt[pos][axis] = "Select " + ["starting", "ending"][pos] + " " + ["origin", "x-axis", "y-axis"][axis]
                    end
                end
            end
            @ps     = Array.new(POINTS){ Array.new(AXIS_PS) }
            @ip     = Sketchup::InputPoint.new
            @point_to_rotate_around = nil
            @operation_complete = false
            @list = []
        end
        
        def activate
            @p      = nil
            for pos in (START..FINISH)
                for axis in (ORIGIN_P..Y_AXIS_P)
                    @ps[pos][axis] = nil
                end
            end

            @state  = START
            #Sketchup::set_status_text $exStrings.GetString("Select second end"), SB_PROMPT
            Sketchup::set_status_text @@prompt[START][ORIGIN_P], SB_PROMPT
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
            if @operation_complete
                reset(view)
                @operation_complete = false
            end
            
            @ip.pick view, x, y
            if @ip.valid?
                @p = @ip.position.clone
                if @state < FINISHED
                    @ps[@state/AXIS_PS][@state%AXIS_PS] = @p.clone
                end
                
                if @state == FINISHED - 1
                    @state = FINISHED
                    done
                elsif @state != FINISHED
                    @state += 1
                    view.invalidate
                end
            end
        end
        
        @@red   = Sketchup::Color.new('red')
        @@green = Sketchup::Color.new('green')
        @@black = Sketchup::Color.new('black')
        @@white = Sketchup::Color.new('white')
        @@grey  = @@black.blend(@@white, 0.50)
        @@rel_brightness = 0.20
        @@colors = [@@black, @@red, @@green]
        
        def draw(view)
            #puts indent "draw " + view.to_s
            view.line_stipple = ""
            view.line_width = 20
            # view.drawing_color = "yellow"
            # view.draw_line([0,0,0], @component_instance.transformation * [0, 0, 0])
            # view.drawing_color = "orange"
            # view.draw_line([0,0,0], @component_instance.transformation * [1, 1, 0])
            
            # Draw placed items
            for pos in (START..FINISH)
                origin = @ps[pos][ORIGIN_P]
                break if origin == nil
                #puts indent "pos #{origin}"
                
                x = @ps[pos][X_AXIS_P]
                if x != nil
                    view.drawing_color = @@red
                    view.draw_line(origin, x)
                    
                    y = @ps[pos][Y_AXIS_P]
                    if y != nil
                        angle = (x - origin).angle_between(y - origin).radians
                        if float_equal?(90, angle)
                            view.drawing_color = @@green
                        else
                            view.drawing_color = @@green.blend(@@black, @@rel_brightness)
                        end
                        view.draw_line(origin, y)
                    end
                end
            end

            # Draw stuff related to mouse movement
            pos = @state / AXIS_PS
            axis = @state % AXIS_PS
            color = @@colors[axis]
            if @state < FINISHED
                if @state > 0
                    if axis == ORIGIN_P
                        view.line_stipple = "-.-"
                        view.drawing_color = color
                        view.draw_line(@ps[START][ORIGIN_P], @p)
                    else
                        if axis == Y_AXIS_P
                            origin = @ps[pos][ORIGIN_P]
                            x = @ps[pos][X_AXIS_P]
                            y = @p
                            angle = (x - origin).angle_between(y - origin).radians
                            if !float_equal?(90, angle)
                                blend = @@black
                            end
                        end
                        view.drawing_color = (blend == nil ? color : color.blend(blend, @@rel_brightness))
                        view.draw_line(@ps[pos][ORIGIN_P], @p)
                    end
                end
                view.draw_points(@p, 10, 4, color.blend(@@white, @@rel_brightness)) 
                Sketchup::set_status_text @@prompt[@state/AXIS_PS][@state%AXIS_PS], SB_PROMPT
            else
                Sketchup::set_status_text "Finished", SB_PROMPT
            end
        end        
        
        def getExtents
            bb = Geom::BoundingBox.new
            bb.add(@p) if @p != nil
            for pos in (START..FINISH)
                for axis in (ORIGIN_P..Y_AXIS_P)
                    p = @ps[pos][axis]
                    bb.add(p) if p != nil
                end
            end
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
            Sketchup::set_status_text "Number of segments", SB_VCB_LABEL
            Sketchup::set_status_text @@segments.to_i.to_s, SB_VCB_VALUE
        end
        
        def enableVCB?
          return true
        end        

        def onUserText(text, view)
            wrap {
            begin
            puts indent "onUserText #{text} #{view}"
            segments = text.to_i
            if segments > 0 && @operation_complete
                @@segments = segments
                Sketchup.undo
                done
            end
            updateVCB
            rescue ArgumentError
              view.tooltip = 'Invalid length'
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
            @state = START
            for pos in (START..FINISH)
                for axis in (ORIGIN_P..Y_AXIS_P)
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
        
        # When done, add instances of component in a progression path between the beginning and end points.
        def done
            wrap {
            model = Sketchup::active_model
            entities = model.active_entities
            
            component_def = @component_instance.definition
            
            # Generate new instance name based on old one
            name = @component_instance.name
            progression_id = name.match /^((?:(?! \{).)*) ?(?:\{([^}]+)\})?/
            if progression_id != nil
                base_name = progression_id[1] != nil ? " " : progression_id[1]
                if progression_id[2] == nil
                    progression_id = "0000"
                    puts indent "A1"
                else
                    progression_id = progression_id[2]
                    puts indent "A2"
                end
            else
                base_name = " "
                progression_id = "0000"
                puts indent "A3"
            end
            progression_id = progression_id.to_i 16
            puts indent "1st element is #{progression_id}"
            model.start_operation "Progression", true
            
            t1 = @component_instance.transformation # I probably need this somewhere, right?
            from = Geom::Transformation.new(
                    @ps[START ][ORIGIN_P],
                    @ps[START ][X_AXIS_P] - @ps[START ][ORIGIN_P],
                    @ps[START ][Y_AXIS_P] - @ps[START ][ORIGIN_P])

            to   = Geom::Transformation.new(
                    @ps[FINISH][ORIGIN_P],
                    @ps[FINISH][X_AXIS_P] - @ps[FINISH][ORIGIN_P],
                    @ps[FINISH][Y_AXIS_P] - @ps[FINISH][ORIGIN_P])

            puts "from = Geom::Transformation.new(\n"\
            "        #{@ps[START ][ORIGIN_P]},\n"\
            "        #{@ps[START ][X_AXIS_P]} - #{@ps[START ][ORIGIN_P]},\n"\
            "        #{@ps[START ][Y_AXIS_P]} - #{@ps[START ][ORIGIN_P]})\n"\
            "\n"\
            "to   = Geom::Transformation.new(\n"\
            "        #{@ps[FINISH][ORIGIN_P]},\n"\
            "        #{@ps[FINISH][X_AXIS_P]} - #{@ps[FINISH][ORIGIN_P]},\n"\
            "        #{@ps[FINISH][Y_AXIS_P]} - #{@ps[FINISH][ORIGIN_P]})\n"\
            "\n"
                    
            puts indent "@ps[START ][ORIGIN_P] = #{@ps[START ][ORIGIN_P]}\n@ps[FINISH][ORIGIN_P] = #{@ps[FINISH][ORIGIN_P]}"
            puts indent "t1 = #{to_ts to}"
            
            method = :custom_interpolate
            case method
            when :sketchup_interpolate
                for i in (1..@@segments) # TODO: remember to change 0 back to 1
                    t2 = Geom::Transformation.interpolate(from, to, i.to_f/@@segments)
                    t3 = t2
                    # puts indent i
                    # debug t3

                    progression_id += 1
                    name = "#{base_name} {#{'%04x' % progression_id}}"
                    puts indent "new instance #{i}: #{name}"

                    instance = entities.add_instance(component_def, t3)
                    instance.name = name
                end
            when :custom_interpolate
                #instance = entities.add_instance(component_def, from)

                transformation = transform_t1_to_t2 from, to, debug: true
                
                assert_equal(translation_only(from), translation_only(transformation.interpolate(0,          @@segments) * from))
                assert_equal(translation_only(to),   translation_only(transformation.interpolate(@@segments, @@segments) * from))
                
                assert_equal(from, transformation.interpolate(0,          @@segments) * from)
                assert_equal(to,   transformation.interpolate(@@segments, @@segments) * from)
                # entities.add_instance(component_def, from).name = "from"
                # entities.add_instance(component_def, to  ).name = "to"
                
                # entities.add_instance(component_def, transformation.translate(0,          @@segments) * from).name = "from!!!"
                # puts "##############################################################"
                # entities.add_instance(component_def, transformation.translate(1,          @@segments, debug: true) * from).name = "1"
                # entities.add_instance(component_def, transformation.translate(@@segments, @@segments) * from).name = "to!!!"
                # entities.add_instance(component_def, translation_only(from)).name = "translation only from"
                # entities.add_instance(component_def, translation_only(to  )).name = "translation only to"
                (1..@@segments).each {|i| # TODO: remember to change 0 back to 1
                    #t2 = transformation.translation(i, @@segments)
                    # puts indent i
                    # debug t3

                    progression_id += 1
                    name = "#{base_name} {#{'%04x' % progression_id}}"
                    puts indent "new instance #{i}: #{name}"

                    instance = entities.add_instance(component_def, transformation.interpolate(i, @@segments)*from)
                    instance.name = name
                    @list.push instance
                    instance.hidden = false
                }
            when :nothing
                # There is an arbitrary rotation point that can be set in space.
                # The start and end point plus the rotation point form a plane.
                rotation_point = @ps[FINISH][ORIGIN_P]
                start_on_translate = true
                finish_on_translate = false
                
                if start_on_translate ^ finish_on_translate
                    rotation_segments = translation_segments = @@segments
                elsif start_on_translate
                    rotation_segments    = @@segments - 1
                    translation_segments = @@segments
                else
                    rotation_segments    = @@segments
                    translation_segments = @@segments - 1
                end
                transforms = transform_t1_to_t2(to, from)
                #puts indent "@point_to_rotate_around-origin_point(t1) : #{@point_to_rotate_around.class.name}-#{origin_point(t1).class.name}"
                #transforms[2][:offset] = @point_to_rotate_around-origin_point(t1)
                #puts indent "#{transforms[2][:offset].class.name}"
                
                if start_on_translate
                    transform = transforms.rotation(1, rotation_segments) * transforms.translate(1, translation_segments)
                else
                    transform = transforms.translate(1, translation_segments) * transforms.rotation(1, rotation_segments)
                end

                t = from
                #t = IDENTITY
                #t = transform.inverse * t
                place_component = ->(i, t) {
                    progression_id += 1
                    name = "#{base_name} {#{'%04x' % progression_id}}"
                    puts indent "new instance #{i}: #{name}"
                    print_transform t
                    print_ijko t

                    instance = entities.add_instance(component_def, t)
                    instance.name = name
                }
                for i in (1..[rotation_segments, translation_segments].min)
                    t_only = translation_only t
                    t = transform * t
                    place_component.call(i, t)
                end
                
                if       rotation_segments > translation_segments
                    t = rotate * t
                    place_component.call(i+1, t)
                elsif translation_segments >    rotation_segments
                    t = translate * t
                    place_component.call(i+1, t)
                end
            end
            @operation_complete = model.commit_operation
            }
        end
        
        def onKeyDown(key, repeat, flags, view)
            puts indent "onKeyDown #{key} #{VK_CONTROL} #{repeat}\n #{'%016b' % flags}\n #{'%016b' % COPY_MODIFIER_KEY}\n #{'%016b' % COPY_MODIFIER_MASK} #{@operation_complete} #{@@segments}"
            case key
            when VK_CONTROL
                @ctrlDown = true #(flags & COPY_MODIFIER_KEY) != 0
            end
            return false
        end

        def flip(list)
            all_visible = @list.inject(true) {|a, e| break false if e.hidden?; true }
            only_last_visible = !@list[-1].hidden? && !@list[0..-2].inject(true) {|a, e| break false if e.hidden?; true }
            if all_visible
                @list.each {|e| e.hidden = true }
                @list[0].hidden = false
            elsif only_last_visible
                @list.each {|e| e.hidden = false }
            else
                @list.inject(false) {|a, e|
                    if a; e.hidden = false; break; end
                    if !e.hidden?; e.hidden = true; true; else; false; end
                }
            end
        end
        
        def onKeyUp(key, repeat, flags, view)
            puts indent "onKeyup #{key} #{VK_CONTROL} #{repeat}\n #{'%016b' % flags}\n #{'%016b' % COPY_MODIFIER_KEY}\n #{'%016b' % COPY_MODIFIER_MASK}  #{@operation_complete} #{@@segments}"
            if @operation_complete
                if @ctrlDown
                    changed = false
                    if    key == "-".ord || key == VK_OEM_MINUS
                        @@segments -= 1 if @@segments > 1
                        changed = true
                    elsif key == "+".ord || key == VK_OEM_PLUS
                        @@segments += 1
                        changed = true
                    end
                end
                if changed
                    Sketchup.undo
                    updateVCB
                    done
                end
                case key
                when VK_CONTROL
                    @ctrlDown = false #(flags & COPY_MODIFIER_KEY) != 0
                when VK_RIGHT
                    flip(@list)
                when VK_LEFT
                    flip(@list.reverse)
                end
                return true
            end
            return false
        end
    end # class Progression

end # module
