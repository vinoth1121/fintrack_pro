import 'package:flutter/material.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../domain/basic_calculator_engine.dart';
import '../widgets/calculator_components.dart';

class BasicCalculatorView extends StatefulWidget {
  const BasicCalculatorView({super.key});

  @override
  State<BasicCalculatorView> createState() => _BasicCalculatorViewState();
}

class _BasicCalculatorViewState extends State<BasicCalculatorView> {
  String _expression = '';
  String _display = '0';
  bool _justEvaluated = false;

  void _onKeyTap(String key) {
    setState(() {
      switch (key) {
        case 'C':
          _expression = '';
          _display = '0';
          _justEvaluated = false;
          break;
        case '⌫':
          if (_expression.isNotEmpty) {
            _expression = _expression.substring(0, _expression.length - 1);
            _display = _expression.isEmpty ? '0' : _expression;
          }
          break;
        case '=':
          final result = BasicCalculatorEngine.evaluate(_expression);
          if (result != null) {
            _display = _formatResult(result);
            _expression = _display;
            _justEvaluated = true;
          } else {
            _display = 'Error';
          }
          break;
        case '±':
          if (_expression.isNotEmpty) {
            if (_expression.startsWith('-')) {
              _expression = _expression.substring(1);
            } else {
              _expression = '-$_expression';
            }
            _display = _expression;
          }
          break;
        case '%':
          final result = BasicCalculatorEngine.evaluate(_expression);
          if (result != null) {
            _display = _formatResult(result / 100);
            _expression = _display;
            _justEvaluated = true;
          }
          break;
        default:
          if (_justEvaluated && !'+-×÷'.contains(key)) {
            _expression = key;
            _justEvaluated = false;
          } else {
            _justEvaluated = false;
            _expression += key;
          }
          _display = _expression;
      }
    });
  }

  String _formatResult(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        children: [
          CalculatorDisplay(expression: _expression == _display ? '' : _expression, result: _display),
          const SizedBox(height: AppSpacing.xl),
          Expanded(child: CalculatorKeypad(onKeyTap: _onKeyTap)),
        ],
      ),
    );
  }
}
