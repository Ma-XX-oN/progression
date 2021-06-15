XXX::bof(__FILE__)
require_relative 'assert.rb'

module AFH
puts __FILE__
    class << self
    ## DEBUG begin

    def Debug(debugging)
        yield if debugging
        nil
    end

    @@debug = true
    @@indent_count = 1
    def indent(s=nil, char: '|', indent_count: @@indent_count)
        if s.nil?
            char * indent_count# + " "
        else
            s = s.to_s
            raise_ RuntimeError, "s is #{s.class.name}" if s.class.name != "String"
            s.gsub(/^|(?<=\n)/, indent(nil, char: char, indent_count: indent_count))
        end
    end

    def wrap(debug = @@debug, block = Proc.new)
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
    
    end
    VarVal = Struct.new(:var_name, :var_expr)
    class << self
    
    def var_s(*var_names)
        Assert(ArgumentError){ True?(block_given?) { "Must have a {|e|eval e} code block passed!" } }
        s = '"'
        if var_names.length > 0
            (0...var_names.length-1).each {|i|
                s += var_s1(var_names[i])
            }
            s += "#{var_s1 var_names.last}\""
            yield s
        end
    end
    
    def var_type_s(*var_names)
        Assert(ArgumentError){ True?(block_given?) { "Must have a {|e|eval e} code block passed!" } }
        s = '"'
        if var_names.length > 0
            (0...var_names.length-1).each {|i|
                s += "#{var_type_s1 var_names[i]}\\n"
            }
            s     += "#{var_type_s1 var_names.last}"
            yield s += '"'
        end
    end
    
    private
    
    def var_value(var_expr)
        "\#{(#{var_expr}).nil? ? '*nil*' : #{var_expr}}"
    end
    
    def var_type(var_expr)
        "\#{(#{var_expr}).nil? ? '*nil*' : (#{var_expr}).class}"
    end
    
    def var_s1(var_name)
        # Surprised that I needed to qualify VarVal
        if AFH::VarVal === var_name
            "#{var_name.var_name} = #{var_value(var_name.var_expr)}\\n"
        else
            "#{var_name} = #{var_value(var_name)}\\n"
        end
    end
    
    def var_type_s1(var_name)
        if AFH::VarVal === var_name
            "#{var_name}{#{var_type var_name.var_expr}} = #{var_value var_name.var_expr}"
        else
            "#{var_name}{#{var_type var_name}} = #{var_vaue var_name}"
        end
    end

    end # class << self
    ## DEBUG end
end
XXX::eof(__FILE__)