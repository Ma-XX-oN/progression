XXX::bof(__FILE__)
require 'sketchup.rb'
require_relative 'geom.rb'
require_relative 'string_formatting.rb'

module AFH
    class << self
    ## STRING FORMATTING begin
    def max_integer_length_in_array(array)
        # sign holder
        character_count = array.min < 0 ? 1 : 0
        max_magnitude = array.map(&:abs).max
        # sign holder + number of digits in integer (log10 domain is >= 0)
        character_count + (1 + (max_magnitude < 10 ? 0 : Math.log10(max_magnitude)))
    end

    def format_float(value, decimal_places, min_integer_length)
        min_string_length = (decimal_places>0?1:0)+decimal_places+min_integer_length
        # Need the string field to pad any end zeros that are stripped from the number
        "% *.*s" % [ min_string_length, min_string_length, "%*.*f" % [min_string_length, decimal_places, value.zero? ? 0 : value.round(decimal_places)] ]
    end

    def to_csv(array1d, decimal_places=4, min_integer_length=nil)
        if min_integer_length.nil?
            min_integer_length = max_integer_length_in_array array1d.to_a
        end
        a = array1d.to_a
        s = ""
        if a.length > 0
            s = format_float(a[0], decimal_places, min_integer_length)
            (1..a.length-1).each { |i| s += ", " + format_float(a[i], decimal_places, min_integer_length) }
        end
        s
    end

    def to_ts(transform, decimal_places = 4)
        return "*nil*" if transform.nil?

        raise_ ArgumentError, "transform is a '#{transform.class.name}' instead of 'Geom::Transformation'" if transform.class.name != "Geom::Transformation"
        array = transform.to_a
        min_integer_length = 1 + max_integer_length_in_array(array)
        s = transform.to_a.each_slice(4).reduce("") { |str, row| str + to_csv(row, decimal_places, min_integer_length) + ",\n" }
        s = "Geom::Transformation.new([\n#{s}])"
    end

    def to_oijk(transform, decimal_places = 4)
        i = v2p(X_AXIS).transform(transform)
        j = v2p(Y_AXIS).transform(transform)
        k = v2p(Z_AXIS).transform(transform)
        o =    (ORIGIN).transform(transform)
        min_integer_length = max_integer_length_in_array [i.to_a, j.to_a, k.to_a, o.to_a].flatten
        s = "i = (#{to_csv(i, decimal_places, min_integer_length)}) (#{to_csv(i.normalize, decimal_places, min_integer_length)})\n" +
            "j = (#{to_csv(j, decimal_places, min_integer_length)}) (#{to_csv(j.normalize, decimal_places, min_integer_length)})\n" +
            "k = (#{to_csv(k, decimal_places, min_integer_length)}) (#{to_csv(k.normalize, decimal_places, min_integer_length)})\n" +
            "o = (#{to_csv(o, decimal_places, min_integer_length)}) (#{to_csv(o.normalize, decimal_places, min_integer_length)})\n"
    end

    ## STRING FORMATTING end
    end # class << self
end
XXX::eof(__FILE__)