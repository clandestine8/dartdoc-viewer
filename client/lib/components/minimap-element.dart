// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library web.minimap_element;

import 'package:dartdoc_viewer/item.dart';
import 'package:polymer/polymer.dart';
import 'package:polymer/src/build/utils.dart' show toCamelCase;
import 'package:dartdoc_viewer/app.dart' show viewer, defaultSyntax;
import 'package:dartdoc_viewer/shared.dart';
import 'package:dartdoc_viewer/location.dart';
import 'package:dartdoc_viewer/member.dart';

/// An element in a page's minimap displayed on the right of the page.
@CustomTag("dartdoc-minimap")
class MinimapElement extends PolymerElement {
  @published Category category;
  @published Item item;

  @observable String camelCaseName;
  @observable String categoryLink;

  @observable ObservableList<Item> itemsToShow;

  get syntax => defaultSyntax;
  bool get applyAuthorStyles => true;

  MinimapElement.created() : super.created() {
    registerNamedObserver('isInherited', viewer.changes.listen((changes) {
      for (var change in changes) {
        if (change.name == #isInherited || change.name == #showObjectMembers) {
          categoryChanged();
          return;
        }
      }
    }));
  }

  void itemChanged() {
    if (category == null || item == null) return;

    categoryLink = '${item.prefixedLinkHref}$ANCHOR_STRING'
        '${category.name.replaceAll(" ", "-")}';
  }

  void categoryChanged() {
    if (category == null || item == null) return;

    itemChanged();
    camelCaseName = toCamelCase(category.name.toLowerCase());
    // Note: ObservableList for isNotEmpty
    itemsToShow =
        new ObservableList.from(category.filteredContent(viewer.filter));
  }
  /// This is called from the template, so needs to be available
  /// as an instance method.
  void rerouteLink(event, detail, target) => routeLink(event, detail, target);
}
