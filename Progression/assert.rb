XXX::bof(__FILE__)
require 'sketchup.rb'
require_relative 'equality.rb'
require_relative 'raise.rb'

module AFH
    class << self
    
    ## ASSERT begin
    @@asserts_on = true
    def AssertCode
        return if !@@asserts_on
        yield
    end
    
    def Assert(error_type = RuntimeError)
        return if !@@asserts_on
        if (msg = yield)
            raise_ error_type, BOEM + indent(msg, char: ' ', indent_count: 4).lstrip + EOEM
        end
    end
    
    def True?(value)
        return if value
        msg = "Test failed!"
        if block_given?
            msg = dev_msg(yield) + msg
        end
        msg
    end

    def test_equal(lhs, rhs, msg = '')
        test_result_msg = Equal?(lhs, rhs, precision: @@precision)
        unless test_result_msg.nil?
            test_result_msg = dev_msg(msg) + test_result_msg
            warn test_result_msg
        end
    end
    
    def Equal?(lhs, rhs, precision: @@precision)
        # This check is to ensure that the types put in are comparable.  So default RuntimeError is correct.
        Assert(ArgumentError){ True?(lhs.class === rhs || rhs.class === lhs) {
            "Neither of #{lhs.class} and #{rhs.class} are the same type or descended from the other."} }

        if Float === lhs && Numeric === rhs || Numeric === lhs && Float === rhs
            return if float_equal?(lhs, rhs, precision: precision)

            diff = (lhs - rhs).abs
            msg = "Floats not same!\n"\
                      "lhs = #{lhs}\n"\
                      "rhs = #{rhs}\n"\
                      "rhs-lhs = #{rhs-lhs}"

        elsif lhs.kind_of?(Geom::Transformation) && rhs.kind_of?(Geom::Transformation)
            return if transform_equal?(lhs, rhs, precision: precision)

            msg = "Matrices not same!\n"\
                      "lhs = #{indent(to_ts(lhs), char: ' ', indent_count: 1).lstrip}\n"\
                      "rhs = #{indent(to_ts(rhs), char: ' ', indent_count: 1).lstrip}\n"\
                      "rhs-lhs = #{indent(to_ts(sub rhs,lhs), char: ' ', indent_count: 1).lstrip}\n"\
                      "max_diff = #{max_diff lhs,rhs}"

        elsif Geom::Point3d === lhs && Geom::Point3d === rhs || Geom::Vector3d === lhs && Geom::Vector3d === rhs
            return if array_equal?(lhs.to_a, rhs.to_a, precision: precision)

            msg = "#{lhs.class} objects not same!\n"\
                      "lhs = #{as_instantiated lhs}\n"\
                      "rhs = #{as_instantiated rhs}\n"\
                      "rhs-lhs = #{sub rhs,lhs}\n"\
                      "max_diff = #{max_diff lhs,rhs}"

        elsif Array === lhs && rhs.respond_to?(:to_a)
            return if lhs == rhs.to_a

            msg = "lhs Array not equivalent to rhs #{rhs.class}!\n"\
                      "lhs       = #{as_instantiated lhs}\n"\
                      "lhs.class = #{lhs.class}\n"\
                      "rhs (to_a)= #{as_instantiated rhs}\n"\
                      "rhs.class = #{lhs.class}"
        elsif Array === rhs && lhs.respond_to?(:to_a)
            return if lhs == rhs || lhs.to_a == rhs

            msg = "lhs #{lhs.class} not equivalent to rhs Array!\n"\
                      "lhs (to_a)= #{as_instantiated lhs}\n"\
                      "lhs.class = #{lhs.class}\n"\
                      "rhs       = #{rhs}\n"\
                      "rhs.class = #{lhs.class}"
        else
            return if (lhs.class === rhs || rhs.class === lhs) && lhs == rhs 

            msg = "Values are not same!\n"\
                      "lhs       = #{as_instantiated lhs}\n"\
                      "lhs.class = #{lhs.class}\n"\
                      "rhs       = #{as_instantiated rhs}\n"\
                      "rhs.class = #{lhs.class}"
        end
        if block_given?
            msg = dev_msg(yield) + msg
        end
        msg
    end
    
    def as_instantiated(x)
        if x.class.private_instance_methods(false).include?(:initialize)
            if x.respond_to?(:to_a)
                "#{x.class}.new(#{to_csv x})"
            else
                "#{x.class}.new(#{x})"
            end
        else
            "#{x}"
        end
    end

    private

    def dev_msg(msg)
        if msg == "" || msg[-1] == "\n"
            msg
        else
            ".?!".include?(msg[-1]) ? msg + " " : msg + ". "
        end
    end

    # Begining Of Error Message
    BOEM = "\n#### ERROR: "
    # Begining Of Warning Message
    BOWM = "#### WARNING: "
    # End Of Error Message
    EOEM = "\n####"

    ## ASSERT end

    end # class << self
end
XXX::eof(__FILE__)