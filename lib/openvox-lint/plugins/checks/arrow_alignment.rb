# frozen_string_literal: true

# Hash rockets (=>) should be aligned within a resource body.
#
# Only fires on groups of 2+ arrows.  Skips groups where the
# misalignment is caused by the longest key having extra leading
# whitespace — that case is already reported by the
# space_before_arrow check to avoid duplicate / contradictory advice.
OpenvoxLint.new_check(:arrow_alignment) do
  def check
    # Group FARROW tokens by resource (consecutive lines)
    arrows = tokens.select { |t| t.type == :FARROW }
    return if arrows.empty?

    # Group arrows by their enclosing brace block
    groups = group_arrows(arrows)
    groups.each do |group|
      next if group.size <= 1

      # If the arrows are already at the same column, nothing to do.
      columns = group.map(&:column)
      max_col = columns.max
      next if columns.all? { |c| c == max_col }

      # Skip this group if the misalignment is caused by extra space
      # before the longest-key arrow — space_before_arrow handles that.
      next if longest_key_has_extra_space?(group)

      group.each do |arrow|
        next if arrow.column == max_col
        notify :warning,
          message: "arrow (=>) on line #{arrow.line} not aligned (column #{arrow.column} vs #{max_col})",
          line: arrow.line,
          column: arrow.column
      end
    end
  end

  private

  def group_arrows(arrows)
    groups = []
    current = [arrows.first]
    arrows[1..].each do |arrow|
      if arrow.line - current.last.line <= 2
        current << arrow
      else
        groups << current
        current = [arrow]
      end
    end
    groups << current unless current.empty?
    groups
  end

  # Returns true when the arrow belonging to the longest key in the
  # group has more than one space before it.  In that situation the
  # space_before_arrow check will fire, so arrow_alignment should stay
  # silent to avoid contradictory advice.
  def longest_key_has_extra_space?(group)
    group.each do |arrow|
      idx = tokens.index(arrow)
      next unless idx && idx >= 2
      ws = tokens[idx - 1]
      next unless ws.type == :WHITESPACE
      key = tokens[idx - 2]
      next if key.formatting?
      # Find the longest key length in the group
      max_klen = group.map { |a|
        ai = tokens.index(a)
        next 0 unless ai && ai >= 2 && tokens[ai - 1].type == :WHITESPACE
        tokens[ai - 2].value.length
      }.max
      if key.value.length == max_klen && ws.value.length > 1
        return true
      end
    end
    false
  end
end
