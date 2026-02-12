# frozen_string_literal: true

# Hash rockets (=>) should be aligned within a resource body.
OpenvoxLint.new_check(:arrow_alignment) do
  def check
    # Group FARROW tokens by resource (consecutive lines)
    arrows = tokens.select { |t| t.type == :FARROW }
    return if arrows.empty?

    # Group arrows by their enclosing brace block
    groups = group_arrows(arrows)
    groups.each do |group|
      next if group.size <= 1
      columns = group.map(&:column)
      max_col = columns.max
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
end
