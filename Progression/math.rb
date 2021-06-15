XXX::bof(__FILE__)
require_relative 'assert.rb'
require_relative 'raise.rb'

module AFH
    class << self
    
    ## MATH begin
    def pow_positive(x, y)
        Assert(ArgumentError){ True?(y.kind_of?(Numeric) && y.truncate == y && y >= 0) }
        total = (y % 2 == 1 ? x : (x.kind_of?(Numeric) ? 1 : IDENTITY))
        while (y /= 2) != 0
            x *= x
            total *= x if y % 2 == 1
        end
        total
    end

    def pow(x, y)
        Assert(ArgumentError){ True?(y.kind_of?(Numeric) && y.truncate == y) { "y must be a Numeric and an Fixnum (atm)"} }
        if y < 0
            result = pow_positive(x.kind_of?(Numeric) ? 1/x.to_f : x.inverse, -y)
        else
            result = pow_positive x, y
        end
    end

    def max_diff(lhs, rhs)
        lhs.zip(rhs).map(&:-).map(&:abs).max
    end

    def sub(lhs, rhs)
        Assert(ArgumentError){ True?(lhs.class == rhs.class) { "Class types #{lhs.class} and #{rhs.class} are not the same."} }
        Assert(ArgumentError){ True?(lhs.class.private_instance_methods(false).include?(:initialize)) {
            "Class #{lhs.class} must define 'new' method."} }
        if lhs.respond_to?(:to_a)
            lhs.class.new(lhs.to_a.zip(rhs).map { |a,b|
                if Array === a || Array === b
                    Assert{ True?(a.respond_to?(:to_a) && b.respond_to?(:to_a)) {
                        "An Array cannot be subtracted from a non-Array that can't be converted into one.\n"\
                        "lhs(#{lhs.class}) = #{lhs}\n"\
                        "rhs(#{rhs.class}) = #{rhs}\n" } }
                    Assert{ True?(a.to_a.length == b.to_a.length) {
                        "Arrays must be the same length.\n"\
                        "lhs(#{lhs.class}) = #{lhs}\n"\
                        "rhs(#{rhs.class}) = #{rhs}\n" } }
                    sub(a.to_a, b.to_a)
                else
                    a-b
                end
            })
        else
            lhs - rhs
        end
    end

    # multiply a scalar (x) with an object (m) that can convert to a 1d array (via to_a) and who's type can create a new object when passed a 1d array with the same number of elements.
    def mult(x, y)
        case x
        when Fixnum, Float
            if Fixnum === y || Float === y
                x * y
            elsif respond_to?(y.to_a); begin
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
    ## MATH end

    end # class << self
end
XXX::eof(__FILE__)