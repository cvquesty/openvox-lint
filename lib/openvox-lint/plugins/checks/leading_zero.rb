# frozen_string_literal: true

# Numbers should not have leading zeros (except octal file modes).
OpenvoxLint.new_check(:leading_zero) do
  def check
    tokens.each_with_index do |tok, i|
      next unless tok.type == :NUMBER
      next unless tok.value =~ /\A0\d+\z/ && tok.value !~ /\A0[xX]/
      # Allow if preceded by 'mode =>'
      j = i - 1
      j -= 1 while j >= 0 && tokens[j].formatting?
      if j >= 0 && tokens[j].type == :FARROW
        k = j - 1
        k -= 1 while k >= 0 && tokens[k].formatting?
        next if k >= 0 && tokens[k].type == :NAME && tokens[k].value == 'mode'
      end
      notify :warning,
        message: "number '#{tok.value}' has a leading zero (interpreted as octal)",
        line: tok.line, column: tok.column
    end
  end
end
