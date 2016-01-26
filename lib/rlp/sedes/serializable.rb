module RLP
  module Sedes
    ##
    # Mixin for objects which can be serialized into RLP lists.
    #
    # `fields` defines which attributes are serialized and how this is done. It
    # is expected to be a hash in the form of `name => sedes`. Here, `name` is
    # the name of an attribute and `sedes` is the sedes object that will be used
    # to serialize the corresponding attribute. The object as a whole is then
    # serialized as a list of those fields.
    #
    module Serializable

      module ClassMethods
        include Error

        def set_serializable_fields(fields)
          raise "Cannot override serializable fields!" if @serializable_fields

          @serializable_fields = fields

          fields.keys.each do |field|
            class_eval <<-ATTR
              def #{field}
                @#{field}
              end

              def #{field}=(v)
                _set_field(:#{field}, v)
              end
            ATTR
          end
        end

        def serializable_fields
          @serializable_fields
        end

        def serializable_sedes
          @serializable_sedes ||= Sedes::List.new(elements: serializable_fields.values)
        end

        def serialize(obj)
          begin
            field_values = serializable_fields.keys.map {|k| obj.send k }
          rescue NoMethodError => e
            raise ObjectSerializationError.new(message: "Cannot serialize this object (missing attribute)", obj: obj)
          end

          begin
            serializable_sedes.serialize(field_values)
          rescue ListSerializationError => e
            raise ObjectSerializationError.new(obj: obj, sedes: self, list_exception: e)
          end
        end

        def deserialize(serial, exclude: nil, extra: {})
          begin
            values = serializable_sedes.deserialize(serial)
          rescue ListDeserializationError => e
            raise ObjectDeserializationError.new(serial: serial, sedes: self, list_exception: e)
          end

          params = Hash[*serializable_fields.keys.zip(values).flatten(1)]
          params.delete_if {|field, value| exclude.include?(field) } if exclude

          obj = self.new params.merge(extra)
          obj.instance_variable_set :@_mutable, false
          obj
        end
      end

      class <<self
        def included(base)
          base.extend ClassMethods
        end
      end

      attr_accessor :_cached_rlp

      def initialize(*args)
        serializable_initialize(*args)
      end

      def serializable_initialize(*args)
        options = args.last.is_a?(Hash) ? args.pop : {}

        field_set = self.class.serializable_fields.keys

        self.class.serializable_fields.keys.zip(args).each do |(field, arg)|
          break unless arg
          _set_field field, arg
          field_set.delete field
        end

        options.each do |field, value|
          if field_set.include?(field)
            _set_field field, value
            field_set.delete field
          end
        end

        raise TypeError, "Not all fields initialized" unless field_set.size == 0
      end

      def _set_field(field, value)
        unless instance_variable_defined?(:@_mutable)
          @_mutable = true
        end

        if mutable? || !self.class.serializable_fields.has_key?(field)
          instance_variable_set :"@#{field}", value
        else
          raise ArgumentError, "Tried to mutate immutable object"
        end
      end

      def ==(other)
        return false unless other.class.respond_to?(:serialize)
        self.class.serialize(self) == other.class.serialize(other)
      end

      def mutable?
        @_mutable
      end

      def make_immutable!
        @_mutable = true
        self.class.serializable_fields.keys.each do |field|
          ::RLP::Utils.make_immutable! send(field)
        end

        @_mutable = false
        self
      end
    end
  end
end