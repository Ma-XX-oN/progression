XXX::bof(__FILE__)
require_relative     'assert.rb'
require_relative     'debug.rb'
module AFH
    ## ENUM begin
    # Enum_type
    #
    # This defines a type that can use symbols to represent data (usually
    # integers, but could be anything).  Symbols are unique, but values may
    # not be, unless they represent the index.  An Enum from one Enum_type are
    # not comparable to another Enum of a different Enum_type.  Different
    # Enum_types instances are not equivalent.
    #
    # This enum type is interesting in that the value of the enum need not be
    # its indexed value.  This has interesting properties, but may result in
    # some performance issues with mapping values back to their symbol.
    class Enum_type
        include AFH
        
        def initialize(*symbol_set, value_is_index: true)
            Assert(ArgumentError){ True?(symbol_set[0].class == Symbol || symbol_set[0].class == String) {
                "First element is #{symbol_set[0].class}, but must be a String or a Symbol (name of type)."} }
            @name = "Enum " + symbol_set[0]
            # TODO: A hash is convenient but it may have more overhead when
            #       searching a small array.  May try and optimize later.
            @symbol_set = {}
            @order = []
            @value_is_index = value_is_index
            i = 1
            prev_value = -1
            while i < symbol_set.length
                Assert{ Equal?(symbol_set[i].class, Symbol) {
                    "Element #{i} with string rep of '#{symbol_set[i]}' must be a symbol"} }
                if i+1 < symbol_set.length && symbol_set[i+1].class != Symbol
                    # Symbol has been given a value.
                    prev_value = symbol_set[i+1]
                    @order.push symbol_set[i]
                    @symbol_set[symbol_set[i]] = prev_value
                    i += 2
                else
                    # Symbol will be assigned the next default value.
                    @order.push symbol_set[i]
                    @symbol_set[symbol_set[i]] = prev_value.next
                    prev_value = prev_value.next
                    i += 1
                end
            end
        end
        attr_reader :name, :value_is_index, :symbol_set
        
        def to_s
            name
        end
        
        def debug_s
            var_s(:@name, :@symbol_set, :@order) {|_|eval _}
        end
        
        def type_s(v)
            if v.nil?
                "nil"
            elsif Enum == v.class
                v.type.name
            else
                v.class
            end
        end
        
        def has_symbol?(s)
            Symbol === s && @symbol_set.key?(s)
        end
        
        def has_value?(s_or_i)
            if value_is_index
                (0...@order.length).cover?(s_or_i)
            else
                @order.find {|s| @symbol_set[s] == s_or_i} != nil
            end
        end
        
        def valid_index?(i)
            (0...@order.length).cover?(i)
        end

        # Find first index of symbol or value that is equal to v. raises ArgumentError if it doesn't exist.
        def index_of(s_or_v)
            Assert(ArgumentError){ True?(Symbol === s_or_v && has_symbol?(s_or_v) || has_value?(s_or_v)) {
                "'#{s_or_v.nil? ? 'nil' : s_or_v}' of type '#{type_s s_or_v}' is not a valid symbol or value for this enum type '#{name}'."} }
            if value_is_index
                if Symbol === s_or_v
                    @order.find_index { |e| e == s_or_v }
                else # value
                    s_or_v
                end
            else
                if Symbol === s_or_v
                    @order.find_index { |e| e == s_or_v }
                else # value
                    @order.find_index { |e| s_or_v == e }
                end
            end
        end
        
        # Get value of symbol
        def value_of(s)
            Assert(ArgumentError){ True?(Symbol === s && has_symbol?(s)) {
                "'#{s}' of type '#{type_s s}' is not a valid symbol for this enum type '#{name}'."} }
            @symbol_set[s]
        end
        
        # Get value at index
        def value_at(i)
            Assert(ArgumentError){ True?(valid_index?(i)) { "#{i} is not a valid index"} }
            if value_is_index
                i
            else
                @symbol_set[@order[i]]
            end
        end
        
        # Get symbol at index
        def symbol_at(i)
            Assert(ArgumentError){ True?(valid_index?(i)) { "#{i} is not a valid index"} }
            @order[i]
        end
        
        def end_index
            @order.length
        end
        
        # Create an enum based on Symbol or value
        def enum(s_or_v)
            Assert(ArgumentError){ True?(Symbol === s_or_v && has_symbol?(s_or_v) || has_value?(s_or_v)) {
                "'#{s_or_v}' is not a valid symbol or value for '#{self}'"} }
            Enum.new self, index: index_of(s_or_v), const: false
        end
        
        def enum_const(s_or_v)
            Assert(ArgumentError){ True?(Symbol === s_or_v && has_symbol?(s_or_v) || has_value?(s_or_v)) {
                "'#{s_or_v}' is not a valid symbol or value for '#{self}'"} }
            Enum.new self, index: index_of(s_or_v), const: true
        end
        
        # Checks if parameter is a comparable Enum, Symbol or value
        def enum_comparable?(e_s_or_v)
            Enum === e_s_or_v && e_s_or_v.type == self ||
            Symbol === e_s_or_v && has_symbol?(e_s_or_v) ||
            has_value?(e_s_or_v)
        end
        
        def assert_compariable(e_s_or_v, error_type: RuntimeError)
            Assert(error_type) { True?(enum_comparable?(e_s_or_v)) {
                "'#{e_s_or_v}' of type '#{type_s e_s_or_v}' is not comparable to '#{self}'"} }
        end

        # Different instances of Enum_type are different enum types.
        def   ==(v); equal?(v); end
        def  ===(v); equal?(v); end
        def eql?(v); equal?(v); end
        
        def hash
            symbol_set.hash
        end
        
        include Enumerable
        def each
            @order.each yield
        end

        # In case the default order isn't value ordered.  Haven't tested.
        def value_ordered
            Enum_type_value_ordered.new self
        end
        
        class Enum_type_value_ordered
            def initialize(enum_type)
                Assert(ArgumentError){ True?(enum_type.class == Enum_type) { "Parameter was '#{enum_type.class}' but must be 'Enum_type'"} }
                @enum_type = enum_type
                @new_order = (@order.sort_by {|e| value_at(e)}).uniq
            end
            include Enumerable
            def each
                @new_order.each yield
            end
        end
    end
    
    class Enum
        include AFH
        
        def initialize(enum_type, s_or_v: nil, index: nil, const:)
            Assert(ArgumentError){ True?((nil != s_or_v) ^ (nil != index)) { "Only one of s_or_v and index may be specified."} }
            Assert(ArgumentError){ True?((s_or_v.nil?) || Symbol === s_or_v && enum_type.has_symbol?(s_or_v) || enum_type.has_value?(s_or_v)) {
                "Symbol/value #{s_or_v} doesn't exist for enum type"} }
            Assert(ArgumentError){ True?((index.nil? ) || enum_type.valid_index?(index)) { "Index #{index} out of range for enum type"} }
            @enum_type = enum_type
            @index = (nil != s_or_v ? enum_type.index_of(s_or_v) : index)
            @const = const
        end
        
        def type_s
            type.type_s self
        end
        
        def type
            @enum_type
        end
        
        def dup
            Enum.new @enum_type, index: @index, const: false
        end
        
        def ==(e_s_or_v)
            #puts "==", var_s(:self, "self.class", :e_s_or_v, "e_s_or_v.class"){|e|eval e}
            @enum_type.assert_compariable(e_s_or_v, error_type: ArgumentError)
            if Enum === e_s_or_v
                index == e_s_or_v.index
            else
                index == @enum_type.index_of(e_s_or_v)
            end
        end

        # : may not be needed
        alias_method :===, :==
        alias_method :eql?, :==
        
        def hash
            calced = index.hash ^ @enum_type.hash
            puts var_s(:calced) {|e|eval e}
            calced
        end
        
        def assign(e_s_or_v)
            Assert(ArgumentError){ True?(!@const) { "Cannot change value of a const enum."} }
            @enum_type.assert_compariable?(e_s_or_v)
            if Enum === e_s_or_v 
                @index = e_s_or_v.index
            else
                @index = @enum_type.index_of e_s_or_v
            end
        end
        
        def symbol
            @enum_type.symbol_at @index
        end
        
        def value
            @enum_type.value_at @index
        end
        
        def index
            @index
        end
        
        include Comparable
        
        def prev!
            Assert(ArgumentError){ True?(!@const) { "Cannot change value of a const enum."} }
            @index                    = (index - 1) % @enum_type.end_index
        end
        
        def next!
            Assert(ArgumentError){ True?(!@const) { "Cannot change value of a const enum."} }
            @index                    = (index + 1) % @enum_type.end_index
        end
        
        def prev
            Enum.new @enum_type, index: (index - 1) % @enum_type.end_index
        end
        
        def next
            Enum.new @enum_type, index: (index + 1) % @enum_type.end_index
        end
        
        alias_method :succ, :next
        
        def <=>(rhs)
            index <=> rhs.index
        end
        
        def to_s
            symbol.to_s
        end
    end
    ## ENUM end
end
XXX::eof(__FILE__)