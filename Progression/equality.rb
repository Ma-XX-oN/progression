XXX::bof(__FILE__)
require_relative 'assert.rb'

module AFH
    class << self
    ## EQUALITY begin
    @@precision = 0.0001

    def transform_equal?(lhs, rhs, precision: @@precision)
        Assert(ArgumentError){ True?(Geom::Transformation === lhs && Geom::Transformation === rhs) {
            "Both #{lhs.class} and #{rhs.class} must be Geom::Transformation types."} }
        array_equal?(lhs.to_a, rhs.to_a, precision: precision)
    end

    def array_equal?(lhs, rhs, precision: @@precision)
        Assert(ArgumentError){ True?(Array === lhs && Array === rhs) {
            "Both #{lhs.class} and #{rhs.class} must be Array types."} }
        Assert(ArgumentError){ Equal?(lhs.length, rhs.length) {
            "Arrays need to be of same length."} }
        [lhs, rhs].transpose.reduce (true) { |a, (e1, e2)|
            break false if !are_equal?(e1, e2, precision: precision)
            true
        }
    end
    
    def float_equal?(lhs, rhs, precision: @@precision)
        Assert(ArgumentError){ True?(any_of(Float, Length, lhs, &:===) || any_of(Float, Length, rhs, &:===)) {
            "Neither #{lhs} (#{hiarchry_to_s lhs.class}) nor #{rhs} (#{hiarchry_to_s rhs.class}) are Floats."} }
        Assert(ArgumentError){ True?(Numeric === lhs && Numeric === rhs) { "Both #{lhs.class} and #{rhs.class} must be Numeric."} }
        (lhs - rhs).abs <= precision
    end

    def are_equal?(lhs, rhs, precision: @@precision)
        if Float === lhs || Float === rhs

            float_equal?(lhs, rhs, precision: precision)
            
        elsif lhs.respond_to?(:to_a) && rhs.respond_to?(:to_a)

            array_equal?(lhs.to_a, rhs.to_a)
            
        else
            Assert{ True?(common_ancestor(lhs.class, rhs.class) != Object) {
                "Neither of #{lhs.class} and #{rhs.class} are the same type or have a common ancestor."} }
                
            lhs == rhs
        end
        rescue
            warn "Exception while comparing #{lhs} of type #{lhs.class} to #{rhs} of type #{rhs.class}."
            raise
    end
    
    def any_of(*list, compare_to)
        list.reduce(false) { |a, e| break true if yield(e, compare_to); false }
    end
    
    def all_of(*list, compare_to)
        list.reduce(true) { |a, e| break false if yield(e, compare_to); true }
    end
    ## EQUALITY end
    end # class << self
end
XXX::eof(__FILE__)