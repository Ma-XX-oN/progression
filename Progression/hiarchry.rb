XXX::bof(__FILE__)
require_relative 'assert.rb'

module AFH
    class << self

    ## CLASS HIARCHRY begin
    def common_ancestor(t1, t2)
        Assert(ArgumentError){ Equal?(t1.class, Class) { "t1 must be a class.  Is #{t1.class} instead."} }
        Assert(ArgumentError){ Equal?(t2.class, Class) { "t2 must be a class.  Is #{t2.class} instead."} }
        return t1 if (t1 <= t2)
        return t2 if (t2 <= t1)
        type = t1.superclass
        until t2 < type
            type = type.superclass
        end
        type
    end

    def hiarchry_to_s(type)
        s = "#{type}"
        type = type.superclass
        while nil != type
            s += " <= #{type}"
            type = type.superclass
        end
        s
    end
    ## CLASS HIARCHRY end
    
    end # class << self
end
XXX::eof(__FILE__)