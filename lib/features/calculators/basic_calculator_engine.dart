/// A from-scratch, standard four-function calculator engine.
///
/// This models a real handheld calculator: digits accumulate into the
/// current operand exactly as typed (so "1", "2", "3" produces "123", not
/// three separate single-digit entries), operators are applied left-to-right
/// against the previous result, and `=` finalizes the expression.
///
/// Design notes (why this is correct for multi-digit input):
///   * [inputDigit] always appends to [display] unless the engine is in a
///     "fresh operand" state (right after an operator, `=`, or on first
///     launch) — in that one case it *replaces* the display instead of
///     appending, which is what lets you type a brand-new number instead of
///     gluing it onto the previous result. That fresh-operand flag is reset
///     to false immediately after the first digit of the new operand is
///     entered, so every digit after the first appends normally.
///   * There is no length cap on the digit buffer other than a sane display
///     limit (15 significant characters), so operands of any realistic size
///     work correctly.
class BasicCalculatorEngine {
  String display = '0';
  double? _accumulator;
  String? _pendingOperator;
  bool _freshOperand = true; // true = next digit replaces display
  bool _justEvaluated = false;

  static const int _maxDisplayLength = 15;

  /// The expression preview shown above the main display, e.g. "12 + 8".
  String get expressionPreview {
    if (_accumulator == null || _pendingOperator == null) return '';
    return '${_formatNumber(_accumulator!)} $_pendingOperator';
  }

  void inputDigit(String digit) {
    assert(digit.length == 1 && '0123456789'.contains(digit));
    if (_justEvaluated) {
      // Typing a digit right after "=" starts a brand-new calculation.
      _accumulator = null;
      _pendingOperator = null;
      _justEvaluated = false;
    }
    if (_freshOperand) {
      display = digit == '0' ? '0' : digit;
      _freshOperand = false;
      return;
    }
    if (display == '0') {
      display = digit;
      return;
    }
    if (display.replaceAll('-', '').replaceAll('.', '').length >= _maxDisplayLength) {
      return; // silently ignore further input past a sane display limit
    }
    display += digit;
  }

  void inputDecimal() {
    if (_justEvaluated) {
      _accumulator = null;
      _pendingOperator = null;
      _justEvaluated = false;
    }
    if (_freshOperand) {
      display = '0.';
      _freshOperand = false;
      return;
    }
    if (!display.contains('.')) {
      display += '.';
    }
  }

  void toggleSign() {
    if (display == '0') return;
    display = display.startsWith('-') ? display.substring(1) : '-$display';
  }

  void inputPercent() {
    final value = double.tryParse(display) ?? 0;
    display = _formatNumber(value / 100);
  }

  void backspace() {
    if (_freshOperand || _justEvaluated) return;
    if (display.length <= 1 || (display.length == 2 && display.startsWith('-'))) {
      display = '0';
      _freshOperand = true;
      return;
    }
    display = display.substring(0, display.length - 1);
  }

  /// Clears everything (the "AC" button).
  void clearAll() {
    display = '0';
    _accumulator = null;
    _pendingOperator = null;
    _freshOperand = true;
    _justEvaluated = false;
  }

  /// Clears only the current entry (the "C" button), keeping any pending
  /// operator/accumulator so the user can retype the second operand.
  void clearEntry() {
    display = '0';
    _freshOperand = true;
  }

  void inputOperator(String op) {
    assert(['+', '−', '×', '÷'].contains(op));
    final current = double.tryParse(display) ?? 0;
    _justEvaluated = false;

    if (_accumulator == null) {
      _accumulator = current;
    } else if (!_freshOperand) {
      // Chain: apply the previous pending operator before storing the new one.
      _accumulator = _apply(_accumulator!, current, _pendingOperator!);
      display = _formatNumber(_accumulator!);
    }
    _pendingOperator = op;
    _freshOperand = true;
  }

  /// Returns an error message (e.g. division by zero) or null on success.
  String? equals() {
    if (_pendingOperator == null || _accumulator == null) {
      _justEvaluated = true;
      _freshOperand = true;
      return null;
    }
    final current = double.tryParse(display) ?? 0;
    if (_pendingOperator == '÷' && current == 0) {
      display = 'Error';
      _accumulator = null;
      _pendingOperator = null;
      _freshOperand = true;
      _justEvaluated = true;
      return 'Cannot divide by zero';
    }
    final result = _apply(_accumulator!, current, _pendingOperator!);
    display = _formatNumber(result);
    _accumulator = null;
    _pendingOperator = null;
    _freshOperand = true;
    _justEvaluated = true;
    return null;
  }

  double _apply(double a, double b, String op) {
    switch (op) {
      case '+':
        return a + b;
      case '−':
        return a - b;
      case '×':
        return a * b;
      case '÷':
        return a / b;
      default:
        return b;
    }
  }

  String _formatNumber(double v) {
    if (v.isNaN || v.isInfinite) return 'Error';
    if (v == v.roundToDouble() && v.abs() < 1e15) {
      return v.toStringAsFixed(0);
    }
    // Trim trailing zeros but keep reasonable precision.
    var s = v.toStringAsFixed(8);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    if (s.replaceAll('-', '').replaceAll('.', '').length > _maxDisplayLength) {
      return v.toStringAsExponential(6);
    }
    return s;
  }
}
