XXX::bof(__FILE__)
require 'sketchup.rb'
require_relative 'debug.rb'
require_relative 'assert.rb'

module AFH
    class << self
    
    ## LM begin (Linear Matrix)
    def lm_to_axes(transform)
        o =    (ORIGIN).transform(transform)
        i = v2p(X_AXIS).transform(transform)
        j = v2p(Y_AXIS).transform(transform)
        k = v2p(Z_AXIS).transform(transform)
        [o,i,j,k]
    end
    
    def lm_add(*transforms)
        transforms.each { |transform| axes_add(lm_to_axes(transform)) }
    end
    
    def lm_del(*transforms)
        transforms.each { |transform| axes_del(lm_to_axes(transform)) }
    end
    
    def lm_translation(t1, t2, offset = ORIGIN)
        t1_rel_t2 = lm_origin_difference(t2, t1)
        puts indent var_s(:t1_rel_t2){|e| eval e}
        { :op => :translate, :offset => t1_rel_t2 + p2v(offset) }
    end

    def lm_rotation(from, to, offset = Geom::Point3d.new(0,0,0), debug: false)
        from = lm_move_origin_to_000(from)
        to = lm_move_origin_to_000(to)
        Debug(debug) { puts indent var_s(:from, :to){|e| eval e} }
        rotate_info = []
        # Bring from into to's vector space so that a rotation against the global
        # axes can be calculated.
        #   rtc from = to
        # From here, we find 0 or more rotation transforms that will left
        # multiply with "from" matrix to create the "to" matrix.  We do that
        # by starting rtc at "from" matrix, and apply orthogonal rotations to
        # it until we arrive at the "to" matrix. Hmmm, that will require 2
        # matrix multiplications to each orthogonal axis.  If we rearrange to:
        #    rtc from to.inverse = IDENTITY
        # we would need only one matrix multiplication as the unmultiplied axis
        # will already be in the 'correct' location.
        rtc = from * to.inverse
        axes = [X_AXIS, Y_AXIS, Z_AXIS]
        axes.each_with_index {|target_axis, i|
            wrap(debug) {
                break if transform_equal?(IDENTITY, rtc)

                new_axis = p2v(v2p(target_axis).transform(rtc))
                angle = new_axis.angle_between(target_axis).radians
                Debug(debug) { puts indent var_s(:target_axis, "target_axis.transform(rtc)", :rtc, :angle){|e| eval e} }

                # If axes lie on the same line and in the same direction, then
                # this axis is already aligned, skip to next axis.
                next if float_equal?(angle, 0)

                if float_equal?(angle, 180)
                    puts indent var_s(:i){|e|eval e}
                    # If the axes lie on the same line but in the opposite
                    # direction, pick a known perpendicular vector.  Don't use
                    # the next axis to be tested, because that will make the
                    # next test useless. (right?)
                    rotate_vector = axes[(i+2)%3]
                else
                    # calculate a perpendicular vectors
                    rotate_vector = new_axis.cross(target_axis)
                end
                Assert{ True?(rotate_vector.valid?) { "Zero vector detected."} }

                rotate_info.unshift({ :op => :rotate, :angle => angle, :axis => rotate_vector})
                Debug(debug) { puts indent "rotate_info = #{rotate_info}" }
                Debug(debug) { puts indent "generate_transform(rotate_info.first) = #{to_ts generate_transform(rotate_info.first)}" }
                rtc = generate_transform(rotate_info.first) * rtc
                Debug(debug) { puts indent "updated rtc = #{to_ts rtc}" }
            }
        }
        Assert{ Equal?(rtc, IDENTITY) }
        Assert{ Equal?(to, generate_transforms(rotate_info).reduce(IDENTITY, :*) * from) }
        rotate_info.length.times { |i| rotate_info[i][:origin] = offset }
        rotate_info
    end
    ## LM end
    
    end # class << self
end
XXX::eof(__FILE__)