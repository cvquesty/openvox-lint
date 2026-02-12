# Test manifest for double_quoted_strings check
class double_quote_test {
  # Should flag — no variables, no escapes, no nested quotes
  file { '/tmp/test':
    content => "hello world",
  }

  # Should NOT flag — contains nested single quotes
  notify { 'reminder':
    message => "it's a test",
  }

  # Should NOT flag — single-quoted word inside double quotes
  notify { 'another':
    message => "use 'ensure' as first parameter",
  }

  # Should NOT flag — has escape sequence
  notify { 'escaped':
    message => "line one\nline two",
  }

  # Should flag — plain double-quoted, no reason for double quotes
  exec { 'run':
    command => "/usr/bin/echo hello",
    path    => "/usr/bin",
  }
}