module ZIL
  class ArrayWithOffset
    attr_reader :original_array, :offset

    def initialize(original_array, offset:)
      @original_array = original_array
      @offset = offset
      raise FunctionError, 'Cannot REST past last element' if @offset > @original_array.size
      raise FunctionError, 'Cannot BACK past first element' if @offset.negative?
    end

    def [](index)
      @original_array[with_offset(index)]
    end

    def []=(index, value)
      @original_array[with_offset(index)] = value
    end

    def size
      @original_array.size - offset
    end

    def to_a
      @original_array[@offset..-1]
    end

    def self.from(value, offset:)
      case value
      when Array
        new(value, offset: offset)
      when ArrayWithOffset
        new(value.original_array, offset: offset + value.offset)
      else
        raise FunctionError, "REST not supported for #{value}"
      end
    end

    private

    def with_offset(index)
      case index
      when Integer
        return index if index.negative? # Don't offset index relative to the end

        index + @offset
      when Range
        Range.new(with_offset(index.begin), with_offset(index.end), index.exclude_end?)
      end
    end
  end
end
