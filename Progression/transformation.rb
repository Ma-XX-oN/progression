XXX::bof(__FILE__)
require 'sketchup.rb'
require_relative 'assert.rb'
require_relative 'debug.rb'

module AFH
    class << self
    
    ## TRANSFORMATION begin
    # Converts a hash into a Transformation.  Each hash has a :op parameter,
    # which can be set to :rotate, :translate, or :scale.
    #   :rotate requires :axis and :angle. :origin defaults to ORIGIN if not
    #     present.
    #   :translate requires :offset
    #   :scale requires either :xscale, :yscale or :zscale.  If any of those
    #     are missing, then :scale must be present.  :origin defaults to ORIGIN
    #     if not present.
    def generate_transform(hash, percent=1)
        debug = false
        wrap(debug) {
            Assert(ArgumentError){ True?(hash.key?(:op)) { "No operation specified"} }
            Debug(debug) { puts indent "hash = #{hash} percent = #{percent}" }
            case hash.fetch(:op)
            when :rotate
                Assert{ True?(!float_equal?(hash[:angle], 0.0, precision: 0.000001) &&
                        !float_equal?(hash[:axis].length, 0, precision: 0.000001)) {
                    "Attempting to generate a transform from an angle of 0 or "\
                    "a zero vector. Could convert into IDENTITY, but this "\
                    "could cause slight performance issues as multiplying by "\
                    "this is just what it was multiplied with.  So, just don't "\
                    "convert such information to avoid unnecessary matrix "\
                    "multiplication."} }
                origin = hash.fetch(:origin, ORIGIN)
                angle = hash[:angle] * percent
                t = Geom::Transformation.rotation(origin, hash[:axis], angle.degrees)
                Debug(debug) { puts indent "Geom::Transformation.rotation(#{origin}, #{hash[:axis]}, #{angle}) = #{to_ts t}" }
            when :translate
                Assert(ArgumentError){ True?(hash.key?(:offset)) { 'Translation requires :offset argument' } }
                offset = mult(percent, hash.fetch(:offset))
                t = Geom::Transformation.translation(offset)
                Debug(debug) { puts indent "Geom::Transformation.translation#{offset} = #{to_ts t}" }
            when :scale
                AssertCode{
                    [:xscale, :yscale, :zscale].each {|scale|
                        Assert{ True?(hash[scale] || hash[:scale]) { "Scaling requires either #{scale} or scale argument." } }
                    }
                }
                xscale = percent * (hash[:xscale] || hash[:scale])
                yscale = percent * (hash[:yscale] || hash[:scale])
                zscale = percent * (hash[:zscale] || hash[:scale])
                origin = hash.fetch(:origin, ORIGIN)
                t = Geom::Transformation.scaling(origin, xscale, yscale, zscale)
                Debug(debug) { puts indent "Geom::Transformation.scale(#{origin}, #{xscale}, #{yscale}, #{zscale}) = #{to_ts t}" }
            else
                raise_ ArgumentError, "Unknown operation \"#{op}\""
            end
            Debug(debug) { puts indent "t = #{to_ts t}\n#{to_oijk t}" }
            t
        }
    end

    def generate_transforms(array_of_hashes, percent=1)
        array_of_hashes.map {|e| generate_transform(e, percent) }
    end
    ## TRANSFORMATION end

    end # class << self
end
XXX::eof(__FILE__)