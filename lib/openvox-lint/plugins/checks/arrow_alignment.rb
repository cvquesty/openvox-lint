# frozen_string_literal: true

# Hash rockets (=>) should be aligned within a resource body.
#
# Uses resource_indexes for accurate scoping to each resource's
# top-level parameters (handles arbitrary gaps from heredocs/comments,
# prevents cross-resource grouping, and supports resource defaults like
# File { ... }).
#
# Only fires on groups of 2+ arrows.  Skips groups where the
# misalignment is caused by the longest key having extra leading
# whitespace — that case is already reported by the
# space_before_arrow check to avoid duplicate / contradictory advice.
OpenvoxLint.new_check(:arrow_alignment) do
  def check
    resource_indexes.each do |res|
      arrows = res[:param_tokens].select { |t| t.type == :FARROW }
      next if arrows.size <= 1

      # If the arrows are already at the same column, nothing to do.
      columns = arrows.map(&:column)
      max_col = columns.max
      next if columns.all? { |c| c == max_col }

      # Skip this group if the misalignment is caused by extra space
      # before the longest-key arrow — space_before_arrow handles that.
      next if longest_key_has_extra_space?(arrows)

      arrows.each do |arrow|
        next if arrow.column == max_col
        notify :warning,
          message: "arrow (=>) on line #{arrow.line} not aligned (column #{arrow.column} vs #{max_col})",
          line: arrow.line,
          column: arrow.column
      end
    end
  end

  private

<<<<<<< HEAD
  def group_arrows(arrows)
    groups = []
    current = [arrows.first]
    arrows[1..-1].each do |arrow|
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
=======
  # Returns true when the arrow belonging to the longest key among the
  # given arrows has more than one space before it. Uses token links
  # (prev_token) to locate the preceding whitespace and key without
  # relying on global array indexes or fragile line heuristics.
  def longest_key_has_extra_space?(arrows)
    entries = arrows.map do |arrow|
      ws = arrow.prev_token
      key = ws&.prev_token
      next unless ws&.type == :WHITESPACE && key && !key.formatting?
      { key_len: key.value.length, ws_len: ws.value.length }
    end.compact
    return false if entries.empty?
>>>>>>> bab7829 (Committing latest refactor work)

    max_klen = entries.map { |e| e[:key_len] }.max
    entries.any? { |e| e[:key_len] == max_klen && e[:ws_len] > 1 }
  end
end
