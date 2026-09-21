# frozen_string_literal: true

# In a block of aligned hash rockets (=>), only the parameter with the
# longest key name should have exactly one space before =>.  All shorter
# keys are expected to have extra padding to keep the arrows aligned.
#
# This check now uses resource_indexes (like arrow_alignment) so that:
# - Only resource attribute arrows (including in "File { defaults }") are
#   considered — no longer mis-applies to case selectors or hash literals.
# - Alignment groups are exact (one per resource body) regardless of
#   blank lines, comments, or multi-line values (heredocs etc).
#
# This check fires only when:
#   - A => has more than one space before it AND is the longest key in its
#     resource (no reason for extra spaces), OR
#   - A => has more than one space before it AND is the only => in the
#     resource (nothing to align with).
OpenvoxLint.new_check(:space_before_arrow) do
  def check
    resource_indexes.each do |res|
      # Collect every FARROW in this resource's params together with its
      # preceding whitespace and key (using token links, since
      # param_tokens contains only semantic/non-formatting tokens).
      farrow_entries = []
      res[:param_tokens].each do |tok|
        next unless tok.type == :FARROW
        ws = tok.prev_token
        next unless ws&.type == :WHITESPACE
        key = ws.prev_token
        next unless key
        farrow_entries << { arrow: tok, whitespace: ws, key: key }
      end

      next if farrow_entries.empty?

      if farrow_entries.size == 1
        # Single parameter — no alignment needed, max one space.
        entry = farrow_entries.first
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
        max_key_len = farrow_entries.map { |e| key_length(e[:key]) }.max

        farrow_entries.each do |entry|
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

<<<<<<< HEAD
  # Group entries by line proximity.  Entries whose arrows appear on
  # lines within 2 of each other belong to the same group.
  def group_entries(entries)
    groups  = []
    current = [entries.first]

    entries[1..-1].each do |entry|
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

=======
>>>>>>> bab7829 (Committing latest refactor work)
  # Calculate the display length of a key token.  For quoted strings
  # the length includes the quotes, matching what the developer sees.
  def key_length(key_token)
    key_token.value.length
  end
end
