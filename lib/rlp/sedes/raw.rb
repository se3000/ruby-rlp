module RLP
  module Sedes
    ##
    # A sedes that does nothing. Thus, everything that can be directly encoded
    # by RLP is serializable. This sedes can be used as a placeholder when
    # deserializing larger structures.
    #
    class Raw
      include Utils

      def serialize(obj)
        raise SerializationError("Can only serialize nested lists of strings", obj) unless serializable?(obj)
        obj
      end

      def deserialize(serial)
        serial
      end

      private

      def serializable?(obj)
        return true if primitive?(obj)
        return obj.all? {|item| serializable?(item) } if list?(obj)
        false
      end

    end
  end
end
