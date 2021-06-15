module AFH
    class << self
    
    ## TESTS begin
    # are out of date
    def test_helper(t1, t2, translate_info, rotate_info, debug: false)
        wrap {

        # Tests
        Debug(debug) { puts indent "### TESTING!! ###" }
        Debug(debug) { puts indent "translate_info = #{translate_info}" }
        Debug(debug) { puts indent "rotate_info    = #{rotate_info}"    }

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
        #    ttc lm_translation_only(t1 t2.inverse) = IDENTITY
        #    ttc = lm_translation_only(t1 t2.inverse).inverse
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

        rtc = generate_transforms(rotate_info).reduce(IDENTITY, :*)
        ttc = generate_transform(translate_info)

        puts "t2 = #{to_ts t2}\nti = #{to_ts t1}\nttc = #{to_ts ttc}\nrtc = #{to_ts rtc}"
        rtc_ = t2 * t1.inverse * ttc.inverse
        ttc_ = rtc.inverse * t2 * t1.inverse

        Assert{ Equal?(IDENTITY, rtc * ttc * t1 * t2.inverse) }
        # Surprised by the lack of precision.
        Assert{ Equal?(IDENTITY, t2.inverse * rtc * ttc * t1, precision: 0.02) }
        Assert{ Equal?(t2, rtc * ttc * t1, precision: 0.02) }

        # Check if these are correct
        #
        #   rtc_ == rtt == rtc
        #   ttc_ == ttt == ttc
        Assert{ Equal?(rtc_, rtc) }
        Assert{ Equal?(ttc_, ttc, precision: 0.04) }

        Debug(debug) { puts indent "### Testing that ttt == ttc and rtt == rtc for a few different n values." }
        1.upto(5). each {|n|
            Debug(debug) { puts indent "n = #{n}" }
            tt = generate_transform(translate_info, 1.0/n)
            Assert{ Equal?(ttc, (n.times.reduce(IDENTITY) { |tta| tt * tta })) }
            rt = generate_transforms(rotate_info, 1.0/n).reduce(IDENTITY, :*)
            Assert{ Equal?(rtc, (n.times.reduce(IDENTITY) { |rta| rt * rta }), precision: 0.1) }
        }

        Debug(debug) { puts indent "### Testing approach of t2 from t1." }
        puts indent "translate_info = #{translate_info}"
        puts indent "rotate_info = #{rotate_info}"
        m = 2
        10.upto(15). each {|n|
            Debug(debug) { puts indent "n = #{n}" }
            full_length = Float(lm_origin_difference(t2, t1).length)
            Debug(debug) { puts indent "full_length = #{full_length}" }

            # prefix
            #  tt - translation transform |  ta - translation accumulator          |  t - translation of t1
            #  rt - rotation transform    | rta - rotation translation accumulator | rt - rotation translation of t1
            #
            # suffix:
            #  _1 - one unit              |   _m - one mth of a unit

            # For testing n size
            tt_1 = generate_transform(translate_info, 1.0/n)
            rt_1 = generate_transforms(rotate_info, 1.0/n).reduce(IDENTITY, :*)

            # For testing n*m size
            tt_m = generate_transform(translate_info, 1.0/(n*m))
            rt_m = generate_transforms(rotate_info, 1.0/(n*m)).reduce(IDENTITY, :*)

            obj = Interpolate.new(t1, t2, translate_info, rotate_info)
            (ta_1, rta_1, ta_m, rta_m) =
            n.times.reduce([IDENTITY,IDENTITY,IDENTITY,IDENTITY]) { |(ta_1, rta_1, ta_m, rta_m), j|
                puts "j/n   = #{j}/#{n}"
                # puts "ta_1  = #{to_ts ta_1}\n"\
                     # "rta_1 = #{to_ts rta_1}\n"\
                     # "ta_m  = #{to_ts ta_m}\n"\
                     # "rta_m = #{to_ts rta_m}\n"
                Assert{ Equal?(ta_1, obj.translate(j, n)) }
                Assert{ Equal?(rta_1, obj.rotate(j, n)) }

                pt_1  = ta_1 * t1
                prt_1 = rta_1 * pt_1
                partial_length_1 = [lm_origin_difference(t2, pt_1).length, lm_origin_difference(t2, prt_1).length].
                    map {|e| full_length - e}

                (ta_m, rta_m) = m.times.reduce([ta_m, rta_m]) { |(ta_m, rta_m), i|
                    puts "i/m = #{i}/#{m}"
                    # puts "ta_m = #{to_ts ta_m}"
                    # puts "t1 = #{to_ts t1}"
                    pt_m  = ta_m * t1
                    prt_m = rta_m * pt_m
                    partial_length_m = [lm_origin_difference(pt_m, t2).length, lm_origin_difference(prt_m, t2).length].
                        map {|e| full_length - e}

                    # puts "% movement: #{partial_length_m[0]/full_length}, #{partial_length_m[1]/full_length}, #{(i.to_f+j*m)/(n*m)}"
                    Assert{ Equal?(partial_length_m[0]/full_length, (i+j*m).to_f/(n*m), precision: 0.1) {
                        "Distance isn't changing an even amount when translating"} }
                    Assert{ Equal?(partial_length_m[1]/full_length, (i+j*m).to_f/(n*m), precision: 0.1) {
                        "Distance isn't changing an even amount when translating and rotating"} }
                    [tt_m * ta_m, rt_m * rta_m]
                }
                ta_1  = tt_1 *  ta_1
                rta_1 = rt_1 * rta_1
                Assert{ Equal?(ta_m, ta_1, precision: 0.1) {  "m cumulative smaller translations don't equal 1 large translation"} }
                Assert{ Equal?(rta_m, rta_1, precision: 0.1) { "m cumulative smaller rotations don't equal 1 large rotation translation"} }
                      
                Assert{ Equal?(partial_length_1[1]/full_length, j.to_f/n, precision: 0.1) {
                    "Distance isn't changing an even amount when translating and rotating"} }
                Assert{ Equal?(partial_length_1[0]/full_length, j.to_f/n, precision: 0.1) {
                    "Distance isn't changing an even amount when translating"} }

                [ta_1, rta_1, ta_m, rta_m]
            }

            Assert{ Equal?(ttc, ta_1) }
            Assert{ Equal?(ttc, ta_m) }
            Assert{ Equal?(rtc, rta_1) }
            Assert{ Equal?(rtc, rta_m) }

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
        #       == rtc lm_translation_only(t1 t2.inverse) t1 t2.inverse
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
        Debug(debug) { puts indent "### TESTING COMPLETE ####################" }
        }
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
            Assert{ Equal?(t1, object.rotate(0,n) * object.translate(0,n) * t1) { "At beginning."} }
            Assert{ Equal?(t2, object.rotate(n,n) * object.translate(n,n) * t1) { "At end."} }
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
    ## TESTS end

    end # class << self
end
