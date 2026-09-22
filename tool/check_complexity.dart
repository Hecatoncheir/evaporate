import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Замер длины, вложенности и когнитивной сложности функций — по
/// синтаксическому дереву `package:analyzer`.
///
/// Прежде замер разбирал текст скобками и регулярками и не видел
/// конструкторов со списком инициализации, фабрик и `operator ==`, пока его
/// не научили им по одному и не приставили к нему перепись тел. Дерево
/// видит каждое объявление по построению. Пакет уже лежал в
/// `pubspec.lock` транзитивно (через `dart_style`), и прямой
/// dev-зависимостью новых пакетов в сборку он не принёс.
///
/// Сложность — когнитивная, по спецификации SonarSource:
///
/// - +1 за `if`, тернарник, `switch`, `for`, `while`, `do` и `catch` и ещё
///   столько, на какой глубине вложенности они стоят;
/// - +1 без надбавки за глубину за `else`, `else if`, условие `when` у
///   образца и `break`/`continue` к метке;
/// - +1 за каждую последовательность одинаковых логических операторов:
///   `a && b && c` — один, `a && b || c` — два;
/// - вложенность повышают ветви всего перечисленного, замыкания и
///   локальные функции.
///
/// `??`, `?.` и `??=` не считаются намеренно — как и в SonarSource: это
/// сокращения, которые заменяют ветвление и читаются легче его. Рекурсия
/// не считается: её видно только по разрешённым именам, а разбор здесь
/// синтаксический.
///
/// Вложенность — наибольшая глубина блоков внутри тела: ветвлений, циклов,
/// `try`, `switch` и замыканий. Литералы коллекций в неё не входят.
///
/// Запуск: `dart tool/check_complexity.dart [папка]` — выводит самые тяжёлые
/// функции. Ворота держит `test/guards/complexity_test.dart`.
void main(List<String> args) {
  final root = args.isEmpty ? 'lib' : args.first;
  final all = <FunctionMetrics>[];
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (isGenerated(path)) continue;
    all.addAll(measure(path, entity.readAsStringSync()));
  }
  all.sort((a, b) => b.complexity.compareTo(a.complexity));
  stdout.writeln('сложн. строк влож.  функция');
  for (final f in all.take(40)) {
    stdout.writeln(
      '${'${f.complexity}'.padLeft(6)} '
      '${'${f.lines}'.padLeft(5)} '
      '${'${f.nesting}'.padLeft(5)}  ${f.path}: ${f.name}',
    );
  }
}

/// Сгенерированное в счёт не идёт: его никто не читает и не правит.
bool isGenerated(String path) =>
    path.contains('/l10n/app_localizations') ||
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart');

class FunctionMetrics {
  const FunctionMetrics({
    required this.path,
    required this.name,
    required this.line,
    required this.lines,
    required this.nesting,
    required this.complexity,
  });

  final String path;

  /// `Класс.метод`, `Класс.new` для безымянного конструктора или имя
  /// функции верхнего уровня.
  final String name;
  final int line;
  final int lines;
  final int nesting;
  final int complexity;
}

/// Ошибки разбора файла.
///
/// Дерево с ошибками замер прочёл бы молча и мимо нераспознанного: так
/// бывает, когда язык опередил пакет `analyzer`, и тогда его обновляют.
List<String> parseErrors(String source) => [
  for (final error in _parse(source).errors) error.message,
];

/// Все функции файла с их показателями.
///
/// Вложенные функции и замыкания засчитываются той, в которой объявлены:
/// когнитивно это одна и та же функция, которую надо прочесть целиком.
List<FunctionMetrics> measure(String path, String source) {
  final parsed = _parse(source);
  final declarations = _Declarations(path, parsed.lineInfo);
  parsed.unit.accept(declarations);
  return declarations.result;
}

/// Замыкания-аргументы внутри `build` и их длина в строках: `builder:
/// (context, state) { … }`, `itemBuilder: (_, i) => …`.
///
/// Метод-виджет страж запрещает, и его обходят замыканием-строителем: те
/// же пятьдесят строк разметки, только без имени и не отдельным виджетом.
/// Отсюда вторая ступень храповика — на длину замыкания в `build`.
List<({String name, int line, int lines})> buildClosures(
  String path,
  String source,
) {
  final parsed = _parse(source);
  final builds = _Declarations(path, parsed.lineInfo);
  parsed.unit.accept(builds);
  final found = <({String name, int line, int lines})>[];
  for (final (name, node) in builds.nodes) {
    if (!name.endsWith('.build') || node is! MethodDeclaration) continue;
    node.body.accept(
      _ArgumentClosures((closure) {
        final line = _lineOf(parsed.lineInfo, closure.offset);
        found.add((
          name: name,
          line: line,
          lines: _lineOf(parsed.lineInfo, closure.end) - line + 1,
        ));
      }),
    );
  }
  return found;
}

ParseStringResult _parse(String source) =>
    parseString(content: source, throwIfDiagnostics: false);

int _lineOf(LineInfo lines, int offset) => lines.getLocation(offset).lineNumber;

/// Объявления с телом: функции верхнего уровня, методы, геттеры,
/// операторы и конструкторы — с именем владельца.
class _Declarations extends RecursiveAstVisitor<void> {
  _Declarations(this.path, this.lines);

  final String path;
  final LineInfo lines;
  final result = <FunctionMetrics>[];

  /// Сами узлы — для тех, кому мало чисел (`buildClosures`).
  final nodes = <(String, AstNode)>[];

  final _owners = <String>[];
  final _seen = <String, int>{};

  @override
  void visitClassDeclaration(ClassDeclaration node) =>
      _inside(node.namePart.typeName.lexeme, node);

  @override
  void visitMixinDeclaration(MixinDeclaration node) =>
      _inside(node.name.lexeme, node);

  @override
  void visitEnumDeclaration(EnumDeclaration node) =>
      _inside(node.namePart.typeName.lexeme, node);

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) =>
      _inside(node.name?.lexeme ?? '', node);

  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) =>
      _inside(node.namePart.typeName.lexeme, node);

  void _inside(String owner, AstNode node) {
    _owners.add(owner);
    node.visitChildren(this);
    _owners.removeLast();
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // Локальная функция — часть той, где объявлена, и мерится вместе с ней.
    if (node.parent is! CompilationUnit) return;
    _record(node.name.lexeme, node, [node.functionExpression.body]);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.body is EmptyFunctionBody) return;
    final name = node.isOperator
        ? 'operator ${node.name.lexeme}'
        : node.name.lexeme;
    _record(name, node, [node.body]);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    // Без тела и без списка инициализации мерить нечего: `const A(this.x);`
    // и перенаправляющая фабрика `factory A() = B;`.
    if (node.body is EmptyFunctionBody && node.initializers.isEmpty) return;
    _record(node.name?.lexeme ?? 'new', node, [
      ...node.initializers,
      node.body,
    ]);
  }

  void _record(String name, AnnotatedNode node, List<AstNode> parts) {
    var full = _owners.isEmpty ? name : '${_owners.last}.$name';
    final seen = _seen[full] = (_seen[full] ?? 0) + 1;
    if (seen > 1) full = '$full#$seen';

    final cognitive = _Cognitive();
    for (final part in parts) {
      cognitive.measure(part);
    }
    final start = _lineOf(lines, node.firstTokenAfterCommentAndMetadata.offset);
    result.add(
      FunctionMetrics(
        path: path,
        name: full,
        line: start,
        lines: _lineOf(lines, node.end) - start + 1,
        nesting: cognitive.deepest,
        complexity: cognitive.score,
      ),
    );
    nodes.add((full, node));
  }
}

/// Когнитивная сложность и вложенность одного тела.
class _Cognitive extends RecursiveAstVisitor<void> {
  int score = 0;

  /// Наибольшая глубина блоков.
  int deepest = 0;

  /// Глубина вложенности по SonarSource: от неё надбавка к ветвлению.
  int _nesting = 0;

  /// Глубина блоков в фигурных скобках.
  int _depth = 0;

  /// Собственные скобки тела вложенностью не считаются: у функции в одну
  /// строку и у функции в блоке глубина одна и та же.
  void measure(AstNode part) {
    if (part is BlockFunctionBody) {
      part.block.visitChildren(this);
    } else {
      part.accept(this);
    }
  }

  void _nested(AstNode? node) {
    if (node == null) return;
    _nesting++;
    node.accept(this);
    _nesting--;
  }

  /// Ветвление: единица и надбавка за глубину.
  void _branch() => score += 1 + _nesting;

  void _inBraces(void Function() visit) {
    _depth++;
    if (_depth > deepest) deepest = _depth;
    visit();
    _depth--;
  }

  @override
  void visitBlock(Block node) => _inBraces(() => super.visitBlock(node));

  @override
  void visitIfStatement(IfStatement node) {
    if (!_isElseIf(node)) _branch();
    node.expression.accept(this);
    node.caseClause?.accept(this);
    _nested(node.thenStatement);
    switch (node.elseStatement) {
      case final IfStatement elseIf:
        score++;
        elseIf.accept(this);
      case final Statement otherwise:
        score++;
        _nested(otherwise);
      case null:
    }
  }

  static bool _isElseIf(IfStatement node) => switch (node.parent) {
    final IfStatement parent => identical(parent.elseStatement, node),
    _ => false,
  };

  @override
  void visitIfElement(IfElement node) {
    if (!_isElseIfElement(node)) _branch();
    node.expression.accept(this);
    node.caseClause?.accept(this);
    _nested(node.thenElement);
    switch (node.elseElement) {
      case final IfElement elseIf:
        score++;
        elseIf.accept(this);
      case final CollectionElement otherwise:
        score++;
        _nested(otherwise);
      case null:
    }
  }

  static bool _isElseIfElement(IfElement node) => switch (node.parent) {
    final IfElement parent => identical(parent.elseElement, node),
    _ => false,
  };

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    _branch();
    node.condition.accept(this);
    _nested(node.thenExpression);
    _nested(node.elseExpression);
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    _branch();
    node.expression.accept(this);
    _inBraces(() {
      _nesting++;
      node.members.accept(this);
      _nesting--;
    });
  }

  @override
  void visitSwitchExpression(SwitchExpression node) {
    _branch();
    node.expression.accept(this);
    _inBraces(() {
      _nesting++;
      node.cases.accept(this);
      _nesting--;
    });
  }

  @override
  void visitWhenClause(WhenClause node) {
    score++;
    super.visitWhenClause(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    _branch();
    node.forLoopParts.accept(this);
    _nested(node.body);
  }

  @override
  void visitForElement(ForElement node) {
    _branch();
    node.forLoopParts.accept(this);
    _nested(node.body);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    _branch();
    node.condition.accept(this);
    _nested(node.body);
  }

  @override
  void visitDoStatement(DoStatement node) {
    _branch();
    _nested(node.body);
    node.condition.accept(this);
  }

  @override
  void visitCatchClause(CatchClause node) {
    _branch();
    _nested(node.body);
  }

  @override
  void visitBreakStatement(BreakStatement node) {
    if (node.label != null) score++;
  }

  @override
  void visitContinueStatement(ContinueStatement node) {
    if (node.label != null) score++;
  }

  /// Замыкание и локальная функция повышают вложенность того, что внутри,
  /// но сами ничего не стоят.
  @override
  void visitFunctionExpression(FunctionExpression node) => _nested(node.body);

  @override
  void visitBinaryExpression(BinaryExpression node) {
    if (_isLogical(node) && !_continuesSequence(node)) {
      final operators = <TokenType>[];
      _logicalOperators(node, operators);
      score++;
      for (var i = 1; i < operators.length; i++) {
        if (operators[i] != operators[i - 1]) score++;
      }
    }
    super.visitBinaryExpression(node);
  }

  static bool _isLogical(Expression node) =>
      node is BinaryExpression &&
      (node.operator.type == TokenType.AMPERSAND_AMPERSAND ||
          node.operator.type == TokenType.BAR_BAR);

  /// Выражение — часть последовательности снаружи: над ним, сквозь
  /// скобки, стоит тот же логический оператор. Отрицание последовательность
  /// рвёт: `a && !(b && c)` — две.
  static bool _continuesSequence(BinaryExpression node) {
    AstNode? parent = node.parent;
    while (parent is ParenthesizedExpression) {
      parent = parent.parent;
    }
    return parent is BinaryExpression && _isLogical(parent);
  }

  static void _logicalOperators(Expression node, List<TokenType> out) {
    final inner = node.unParenthesized;
    if (inner is! BinaryExpression || !_isLogical(inner)) return;
    _logicalOperators(inner.leftOperand, out);
    out.add(inner.operator.type);
    _logicalOperators(inner.rightOperand, out);
  }
}

/// Литералы функций, переданные аргументом: позиционным или именованным.
class _ArgumentClosures extends RecursiveAstVisitor<void> {
  _ArgumentClosures(this.found);

  final void Function(FunctionExpression) found;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    final parent = node.parent;
    if (parent is ArgumentList || parent is NamedArgument) found(node);
    super.visitFunctionExpression(node);
  }
}
