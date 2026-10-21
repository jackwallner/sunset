#!/usr/bin/env python3
"""Copy Swift sources into OUT, rewritten for an older command-line Swift.

- `case .x: "value"` single-expression switch arms get `return`.
- `let name: T = switch subject { ... }` becomes an immediately called closure.
- NotificationService keeps only its pure planning half (no UserNotifications).
"""
import os
import re
import sys


def add_returns(text: str) -> str:
    return re.sub(r'^(\s*(?:case [^\n:]+|default):\s+)(?!return\b|self\b|break\b)(".*"|[0-9.]+)\s*$',
                  r'\1return \2', text, flags=re.M)


def switch_expressions(text: str) -> str:
    pattern = re.compile(r'let (\w+): (\w+) = switch ([^{]+)\{(.*?)\n(\s*)\}', re.S)

    def repl(m):
        body = re.sub(r'(case [^:\n]+:|default:)(?![ \t]*return\b)[ \t]*', r'\1 return ', m.group(4))
        return f'let {m.group(1)}: {m.group(2)} = {{ () -> {m.group(2)} in switch {m.group(3)}{{{body}\n{m.group(5)}}} }}()'

    return pattern.sub(repl, text)


def drop_block(text: str, signature: str) -> str:
    start = text.find(signature)
    if start < 0:
        return text
    line_start = text.rfind('\n', 0, start) + 1
    brace = text.find('{', start)
    depth, i = 0, brace
    while True:
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                break
        i += 1
    return text[:line_start] + text[i + 1:]


def main() -> None:
    out = sys.argv[1]
    for path in sys.argv[2:]:
        text = open(path).read()
        if path.endswith('NotificationService.swift'):
            text = text.replace('import UserNotifications\n', '').replace('@MainActor\n', '')
            for signature in ('static func requestAuthorization', 'static func authorizationStatus', 'static func reschedule'):
                text = drop_block(text, signature)
        text = switch_expressions(add_returns(text))
        open(os.path.join(out, os.path.basename(path)), 'w').write(text)


if __name__ == '__main__':
    main()
