/// Minimal, safe arithmetic expression evaluator for the Basic Calculator.
/// Deliberately avoids dart:mirrors/eval-style approaches — parses a
/// restricted grammar (numbers, + - × ÷, parentheses) by hand so there's
/// no code-injection surface from user input.
class BasicCalculatorEngine {
  /// Evaluates a simple left-to-right expression with standard operator
  /// precedence (× and ÷ before + and -). Returns null on invalid input.
  static double? evaluate(String expression) {
    final sanitized = expression.replaceAll('×', '*').replaceAll('÷', '/').replaceAll(' ', '');
    if (sanitized.isEmpty) return null;

    try {
      final tokens = _tokenize(sanitized);
      if (tokens.isEmpty) return null;
      return _evaluateTokens(tokens);
    } catch (_) {
      return null;
    }
  }

  static List<String> _tokenize(String input) {
    final tokens = <String>[];
    var buffer = StringBuffer();

    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      if ('+-*/'.contains(char)) {
        // Handle unary minus (e.g. "-5+3")
        if (char == '-' && buffer.isEmpty && (tokens.isEmpty || '+-*/'.contains(tokens.last))) {
          buffer.write(char);
          continue;
        }
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer = StringBuffer();
        }
        tokens.add(char);
      } else if (RegExp(r'[0-9.]').hasMatch(char)) {
        buffer.write(char);
      } else {
        throw FormatException('Invalid character: $char');
      }
    }
    if (buffer.isNotEmpty) tokens.add(buffer.toString());
    return tokens;
  }

  static double _evaluateTokens(List<String> tokens) {
    // First pass: resolve × and ÷
    final pass1 = <String>[];
    int i = 0;
    while (i < tokens.length) {
      final token = tokens[i];
      if (token == '*' || token == '/') {
        final left = double.parse(pass1.removeLast());
        final right = double.parse(tokens[i + 1]);
        final result = token == '*' ? left * right : left / right;
        pass1.add(result.toString());
        i += 2;
      } else {
        pass1.add(token);
        i++;
      }
    }

    // Second pass: resolve + and -
    double result = double.parse(pass1.first);
    i = 1;
    while (i < pass1.length) {
      final op = pass1[i];
      final value = double.parse(pass1[i + 1]);
      result = op == '+' ? result + value : result - value;
      i += 2;
    }
    return result;
  }
}
