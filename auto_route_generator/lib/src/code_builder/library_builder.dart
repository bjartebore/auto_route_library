import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

import '../../utils.dart';
import '../models/importable_type.dart';
import '../models/route_config.dart';
import '../models/router_config.dart';
import 'root_router_builder.dart';
import 'route_info_builder.dart';

const autoRouteImport = 'package:auto_route/auto_route.dart';
const materialImport = 'package:flutter/material.dart';

const Reference stringRefer = Reference('String');
const Reference pageRouteType = Reference('PageRouteInfo', autoRouteImport);
const Reference requiredAnnotation = Reference('required', materialImport);

TypeReference listRefer(Reference reference, {bool nullable = false}) =>
    TypeReference((b) => b
      ..symbol = "List"
      ..isNullable = nullable
      ..types.add(reference));

String generateLibrary(RouterConfig config, {bool usesPartBuilder = false}) {
  final fileName = config.element.source.uri.pathSegments.last;
  final emitter = DartEmitter(
    allocator: usesPartBuilder ? Allocator.none : Allocator.simplePrefixing(),
    orderDirectives: true,
    useNullSafetySyntax: false,
  );

  var allRouters = config.collectAllRoutersIncludingParent;
  List<RouteConfig> allRoutes =
      allRouters.fold(<RouteConfig>[], (acc, a) => acc..addAll(a.routes));

  final nonRedirectRoutes =
      allRoutes.where((r) => r.routeType != RouteType.redirect);
  final checkedRoutes = <RouteConfig>[];
  nonRedirectRoutes.forEach((route) {
    throwIf(
      (checkedRoutes.any((r) =>
          r.routeName == route.routeName && r.pathName != route.pathName)),
      'Duplicate route names must have the same path! (name: ${route.routeName}, path: ${route.pathName})\nNote: Unless specified, route name is generated from page name.',
      element: config.element,
    );
    checkedRoutes.add(route);
  });

  var allGuards = allRoutes.fold<Set<ResolvedType>>(
    {},
    (acc, a) => acc..addAll(a.guards),
  );

  final library = Library(
    (b) => b
      ..directives.addAll([
        if (usesPartBuilder) Directive.partOf(fileName),
      ])
      ..body.addAll([
        buildRouterConfig(config, allGuards, allRoutes),
        ...allRoutes
            .where((r) => r.routeType != RouteType.redirect)
            .distinctBy((e) => e.routeName)
            .map((r) => buildRouteInfoAndArgs(r, config, emitter))
            .reduce((acc, a) => acc..addAll(a)),
      ]),
  );

  return [_header, DartFormatter().format(library.accept(emitter).toString())]
      .join('\n');
}

const String _header = '''
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouteGenerator
// **************************************************************************
//
// ignore_for_file: type=lint
''';
