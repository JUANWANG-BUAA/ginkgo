import 'dart:convert';
import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

// Compiler-resolved declarations, calls and callback references. No name matching.
class Graph {
  Graph(this.root);
  final String root;
  final nodes = <String, Map<String, Object?>>{};
  final edges = <Map<String, Object?>>[];
  final issues = <Map<String, Object?>>[];
  final sourceText = <String, String>{};
  String relative(String path) =>
      path.startsWith('$root/') ? path.substring(root.length + 1) : path;
  String element(Element element) {
    final base = element.baseElement;
    final fragment = base.firstFragment;
    final path = fragment.libraryFragment?.source.fullName ?? '';
    final offset = fragment.nameOffset ?? -1;
    final name = base.displayName;
    final parent = base.enclosingElement;
    final qualified = parent is InterfaceElement || parent is ExtensionElement
        ? '${parent!.displayName}.$name'
        : name;
    final id = '$path:$offset:${base.kind.name}:$qualified';
    final sourceOffset = offset >= 0
        ? offset
        : parent?.firstFragment.nameOffset;
    int? sourceLine;
    if (path.startsWith('$root/flutter/lib/') &&
        sourceOffset != null &&
        sourceOffset >= 0) {
      final content = sourceText.putIfAbsent(
        path,
        () => File(path).readAsStringSync(),
      );
      if (sourceOffset <= content.length) {
        sourceLine =
            '\n'.allMatches(content.substring(0, sourceOffset)).length + 1;
      }
    }
    nodes.putIfAbsent(
      id,
      () => {
        'id': id,
        'name': qualified,
        'file': path.startsWith('$root/')
            ? relative(path)
            : (fragment.libraryFragment?.source.uri.toString() ?? 'external'),
        'offset': offset,
        if (sourceLine != null) 'line': sourceLine,
        'kind': base.kind.name,
        'language': 'dart',
        'external': !path.startsWith('$root/flutter/lib/'),
        'generated': path.contains('/flutter/lib/src/rust/'),
        if (base is ExecutableElement) 'abstract': base.isAbstract,
      },
    );
    return id;
  }
}

class Calls extends RecursiveAstVisitor<void> {
  Calls(this.graph, this.result);
  final Graph graph;
  final ResolvedUnitResult result;
  String? owner;
  int line(int offset) => result.lineInfo.getLocation(offset).lineNumber;
  String synthetic(AstNode node, String name, String kind) {
    final id = '${result.path}:${node.offset}:$kind';
    graph.nodes[id] = {
      'id': id,
      'name': name,
      'file': graph.relative(result.path),
      'offset': node.offset,
      'line': line(node.offset),
      'endLine': line(node.end),
      'kind': kind,
      'language': 'dart',
      'external': false,
      'generated': result.path.contains('/src/rust/'),
    };
    return id;
  }

  void within(
    AstNode node,
    Element? element,
    String name,
    void Function() visit,
  ) {
    final id = element == null
        ? synthetic(node, name, 'closure')
        : graph.element(element);
    graph.nodes[id]!.addAll({
      'line': line(node.offset),
      'endLine': line(node.end),
    });
    final previous = owner;
    if (previous != null) edge(id, node, 'contains');
    owner = id;
    visit();
    owner = previous;
  }

  void edge(String? target, AstNode node, String kind, {String? label}) {
    final caller = owner ??= synthetic(
      result.unit,
      '<module initialization>',
      'initializer',
    );
    graph.edges.add({
      'from': caller,
      'to': target,
      'kind': kind,
      'label': label ?? node.toSource().split('\n').first,
      'file': graph.relative(result.path),
      'line': line(node.offset),
      'resolved': target != null,
    });
  }

  void call(Element? element, AstNode node, String kind) {
    edge(
      element is ExecutableElement ? graph.element(element) : null,
      node,
      kind,
    );
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final type = node.declaredFragment?.element;
    if (type != null) {
      for (final method in type.methods.where((m) => !m.isStatic)) {
        for (final supertype in type.allSupertypes) {
          for (final inherited in supertype.element.methods.where(
            (m) =>
                !m.isStatic &&
                m.name == method.name &&
                (!m.isPrivate || m.library == method.library),
          )) {
            final base = graph.element(inherited);
            if (graph.nodes[base]!['external'] == true) continue;
            graph.edges.add({
              'from': base,
              'to': graph.element(method),
              'kind': 'implementation',
              'resolved': true,
              'file': graph.relative(result.path),
              'line': line(node.offset),
              'label': 'declared override; runtime receiver not proven',
            });
          }
        }
      }
    }
    super.visitClassDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) => within(
    node,
    node.declaredFragment?.element,
    node.name.lexeme,
    () => super.visitFunctionDeclaration(node),
  );
  @override
  void visitMethodDeclaration(MethodDeclaration node) => within(
    node,
    node.declaredFragment?.element,
    node.name.lexeme,
    () => super.visitMethodDeclaration(node),
  );
  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) => within(
    node,
    node.declaredFragment?.element,
    'constructor',
    () => super.visitConstructorDeclaration(node),
  );
  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (node.parent is FunctionDeclaration) {
      super.visitFunctionExpression(node);
      return;
    }
    within(
      node,
      node.declaredFragment?.element,
      '<callback @${line(node.offset)}> ',
      () => super.visitFunctionExpression(node),
    );
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    call(node.methodName.element, node, 'call');
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    call(node.constructorName.element, node, 'construct');
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    call(node.element, node, 'invoke');
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final e = node.element;
    // Tear-offs and getter references matter for event-driven UI. A reference is
    // not proof that a framework invokes the callback or in which order.
    if (e is ExecutableElement &&
        !node.inDeclarationContext() &&
        !(node.parent is MethodInvocation &&
            identical((node.parent as MethodInvocation).methodName, node)) &&
        node.parent is! ConstructorName) {
      call(e, node, 'reference');
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitAwaitExpression(AwaitExpression node) {
    edge(null, node, 'await');
    super.visitAwaitExpression(node);
  }
}

Future<void> main(List<String> args) async {
  final root = Directory(args[0]).absolute.path;
  final graph = Graph(root);
  final collection = AnalysisContextCollection(
    includedPaths: ['$root/flutter/lib'],
  );
  final files =
      Directory('$root/flutter/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.dart') &&
                (!f.path.contains('/src/rust/') ||
                    f.path.contains('/src/rust/api/')),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (var i = 0; i < files.length; i++) {
    final f = files[i];
    final result = await collection
        .contextFor(f.path)
        .currentSession
        .getResolvedUnit(f.path);
    if (result is! ResolvedUnitResult) {
      graph.issues.add({
        'file': graph.relative(f.path),
        'reason': result.runtimeType.toString(),
      });
      continue;
    }
    for (final error in result.diagnostics.where(
      (e) => e.diagnosticCode.severity.name == 'ERROR',
    )) {
      graph.issues.add({
        'file': graph.relative(f.path),
        'reason': error.message,
        'offset': error.offset,
      });
    }
    result.unit.accept(Calls(graph, result));
    if (i % 40 == 0) stderr.writeln('Dart resolved ${i + 1}/${files.length}');
  }
  await collection.dispose();
  // Stable portable IDs; SDK/cache declarations remain identified as external.
  final ids = <String, String>{};
  for (final n in graph.nodes.values) {
    final file = n['file'] as String;
    final stable = file.startsWith(root)
        ? graph.relative(file)
        : file.contains('/.pub-cache/')
        ? 'package-cache/${file.split('/.pub-cache/').last}'
        : file;
    ids[n['id'] as String] = '$stable:${n['offset']}:${n['kind']}:${n['name']}';
  }
  for (final n in graph.nodes.values) {
    n['id'] = ids[n['id']];
  }
  for (final e in graph.edges) {
    e['from'] = ids[e['from']];
    e['to'] = ids[e['to']];
  }
  File(args[1]).writeAsStringSync(
    jsonEncode({
      'tool': 'Dart analyzer 10.2.0 resolved AST',
      'files': files.length,
      'nodes': graph.nodes.values.toList(),
      'edges': graph.edges,
      'issues': graph.issues,
    }),
  );
  if (graph.issues.isNotEmpty) {
    stderr.writeln('${graph.issues.length} unresolved units/errors');
    exitCode = 1;
  }
}
