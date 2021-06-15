XXX::bof(__FILE__)
module AFH
    class << self
    def raise_(*args)
        if String === args[0]
            raise args[0] + callstack
        else
            puts "raise"
            puts "raise #{args}"
            puts "raise #{callstack.nil?}"
            raise args[0], args[1] + callstack
        end
    end
    
    def callstack
        puts "CALLSTACK"
        s = "\n### vvv CALLSTACK vvv ###"
        last_frame = ''
        count = 0
        prefix = "\n    "
        caller.each {|e|
            next if e.match(/`(call|callstack|wrap|raise_|method_missing|[aA]ssert(?:_[^']*)?)'/)
            if last_frame == e
                count += 1
                next
            elsif count > 0
                s += prefix + "... repeated #{count} ..."
                count = 0
            end
            last_frame = e
            s += prefix + e.sub(/^(?:.*\/|)/,"")
        }
        s += "\n### ^^^ CALLSTACK ^^^ ###"
    end
    end # class << self
end
XXX::eof(__FILE__)