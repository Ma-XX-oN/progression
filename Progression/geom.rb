XXX::bof(__FILE__)
require 'sketchup.rb'
require_relative 'assert.rb'

module AFH
    class << self
    
    ## GEOM begin
    def v2p(v)
        Assert(ArgumentError){ True?(v.instance_of?(Geom::Vector3d)) {
            "Can't convert from #{v.class} to a Geom::Point3d! Expecting Vector3d!"} }
        Geom::Point3d.new(*v)
    end

    def p2v(v)
        Assert(ArgumentError){ True?(v.instance_of?(Geom::Point3d)) {
            "Can't convert from #{v.class} to a Geom::Vector3d! Expecting Point3d!"} }
        Geom::Vector3d.new(*v)
    end
    
    # Take the origin of t2 and subtract the origin of t1.
    def lm_origin_difference(t1, t2)
        o1 = lm_origin_point(t1)
        o2 = lm_origin_point(t2)
        o1 - o2
    end

    def lm_move_origin_to_000(t)
        a = t.to_a
        Geom::Transformation.new(a[0..11] += [0,0,0,1])
    end

    def lm_translation_only(t)
        a = t.to_a
        Geom::Transformation.new([1,0,0,0, 0,1,0,0, 0,0,1,0, a[12],a[13],a[14], 1])
    end

    def lm_origin_point(t)
        a = t.to_a
        Geom::Point3d.new(a[12],a[13],a[14])
    end
    ## GEOM end

    end # class << self
end
XXX::eof(__FILE__)