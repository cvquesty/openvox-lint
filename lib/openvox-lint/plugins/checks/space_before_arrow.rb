# frozen_string_literal: true

# In a block of aligned hash rockets (=>), only the parameter with the
# longest key name should have exactly one space before =>.  All shorter
# keys are expected to have extra padding to keep the arrows aligned.
#
# This check fires only when:
#   - A => has more than one space before it AND is the longest key in its
#     alignment group (no reason for extra spaces), OR
#   - A => has more than one space before it AND is the only => on its line
#     group (nothing to align with).
OpenvoxLint.new_check(:space_before_arrow) do
  def check
    # Collect every FARROW token together with its preceding whitespace
    # and the key token that precedes that whitespace.
    farrow_entries = []
    tokens.each_with_index do |tok, i|
      next unless tok.type == :FARROW
      next if i < 2

      ws = tokens[i - 1]
      next unless ws.type == :WHITESPACE

      # The key token is whatever sits before the whitespace. It could be
      # a NAME, SSTRING, STRING, VARIABLE, CLASSREF, etc.
      key = tokens[i - 2]
      farrow_entries << { arrow: tok, whitespace: ws, key: key }
    end

    return if farrow_entries.empty?

    # Group arrows that belong to the same aligned block.  Arrows on
    # consecutive lines (gap <= 2) belong to the same group — same
    # heuristic used by the arrow_alignment check.
    groups = group_entries(farrow_entries)

    groups.each do |group|
      if group.size == 1
        # Single parameter — no alignment needed, max one space.
        entry = group.first
        if entry[:whitespace].value.length > 1
          notify :warning,
            message: "more than one space before => (found #{entry[:whitespace].value.length})",
            line: entry[:arrow].line,
            column: entry[:whitespace].column
        end
      else
        # Multiple parameters — find the longest key.  Only the longest
        # key (the one that sets the alignment column) should have a
        # single space.  Flag it if it has extra spaces.
        max_key_len = group.map { |e| key_length(e[:key]) }.max

        group.each do |entry|
          ws_len = entry[:whitespace].value.length
          next if ws_len <= 1       # exactly one space — always fine
          klen = key_length(entry[:key])

          # This is the longest key (or tied for longest).  It should
          # have exactly one space before =>.
          if klen == max_key_len && ws_len > 1
            notify :warning,
              message: "more than one space before => (found #{ws_len})",
              line: entry[:arrow].line,
              column: entry[:whitespace].column
          end

          # Shorter keys: extra spaces are expected for alignment — no warning.
        end
      end
    end
  end

  private

  # Group entries by line proximity.  Entries whose arrows appear on
  # lines within 2 of each other belong to the same group.
  def group_entries(entries)
    groups  = []
    current = [entries.first]

    entries[1..].each do |entry|
      if entry[:arrow].line - current.last[:arrow].line <= 2
        current << entry
      else
        groups << current
        current = [entry]
      end
    end
    groups << current unless current.empty?
    groups
  end

  # Calculate the display length of a key token.  For quoted strings
  # the length includes the quotes, matching what the developer sees.
  def key_length(key_token)
    key_token.value.length
  end
end
