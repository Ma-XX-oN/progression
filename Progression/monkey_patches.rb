XXX::bof(__FILE__)
require 'sketchup.rb'
require_relative 'enum.rb'

## MONKEY PATCHES begin
module AFH
    class ::Geom::Point3d
        def hash; to_a.hash; end
        def eql?(o); hash == o.hash; end
    end
    class ::Geom::Vector3d
        def hash; to_a.hash; end
        def eql?(o); hash == o.hash; end
    end
    class ::Geom::Transformation
        def to_s; AFH::to_ts self; end
    end
    module Symbol_extensions
        def ===(rhs)
            if Enum === rhs
                rhs === self
            else
                super
            end
        end
        def ==(rhs)
            if Enum === rhs
                rhs == self
            else
                super
            end
        end
        def eql?(rhs)
            if Enum === rhs
                rhs.eql?(self)
            else
                super
            end
        end
    end
end
class Symbol
    test = AFH::Enum_type.new "test", :a
    if :a != test.enum(:a)
        prepend AFH::Symbol_extensions
    end
end
## MONKEY PATCHES end
XXX::eof(__FILE__)