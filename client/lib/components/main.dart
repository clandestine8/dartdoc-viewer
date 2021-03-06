// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library web.main;

import 'dart:html';
import 'package:polymer/polymer.dart';
import 'package:dartdoc_viewer/app.dart';
import 'package:dartdoc_viewer/item.dart';
import 'package:dartdoc_viewer/location.dart';
import 'package:dartdoc_viewer/member.dart';
import 'search.dart';

// TODO(alanknight): Clean up the dart-style CSS file's formatting once
// it's stable.
@CustomTag("dartdoc-main")
class MainElement extends DartdocElement {
  @observable String sdkVersionString;
  @observable String pageContentClass;
  @observable bool shouldShowLibraryPanel;
  @observable bool shouldShowLibraryMinimap;
  @observable bool shouldShowClassMinimap;

  // TODO(jmesserly): somewhat unfortunate, but for now we don't have
  // polymer_expressions so we need a workaround.
  @observable String showOrHideLibraries;
  @observable String showOrHideMinimap;
  @observable String showOrHideInherited;
  @observable String showOrHideObjectMembers;

  /// The version of the docs that are being hosted on this main site, defaults
  /// to nothing, aka "latest".
  String hostDocsVersion = '';

  /// Records the timestamp of the event that opened the options menu.
  int _openedAt;

  @observable final homePage = '${BASIC_LOCATION_PREFIX}home';

  MainElement.created() : super.created();

  void attached() {
    super.attached();

    registerNamedObserver('viewer', viewer.changes.listen(_onViewerChange));
    registerNamedObserver('onclick',
        onClick.listen(hideOptionsMenuWhenClickedOutside));

    _onViewerChange(null);
  }

  void _onViewerChange(changes) {
    if (!viewer.isDesktop) {
      pageContentClass = '';
    } else {
      var left = viewer.isPanel ? 'margin-left ' : '';
      var right = viewer.isMinimap ? 'margin-right' : '';
      pageContentClass = '$left$right';
    }

    shouldShowLibraryPanel =
        viewer.currentPage != null && viewer.isPanel;

    shouldShowClassMinimap =
        viewer.currentPage is Class && viewer.isMinimap;

    shouldShowLibraryMinimap =
        viewer.currentPage is Library && viewer.isMinimap;

    showOrHideLibraries = viewer.isPanel ? 'Hide' : 'Show';
    showOrHideMinimap = viewer.isMinimap ? 'Hide' : 'Show';
    showOrHideInherited = viewer.isInherited ? 'Hide' : 'Show';
    showOrHideObjectMembers = viewer.showObjectMembers ? 'Hide' : 'Show';
  }

  Element query(String selectors) => shadowRoot.querySelector(selectors);

  /// Helper for finding the specific SDK version and channel if we want to
  /// link back to the canonical api.dartlang.org.
  String _versionSubstringHelper(Pattern start, [Pattern end]) {
    if (sdkVersionString != '') {
      var index = sdkVersionString.lastIndexOf(start);
      if (index != -1) {
        var substringEndIndex = sdkVersionString.length;
        if (end != null) {
          substringEndIndex = sdkVersionString.indexOf(end, index);
        }
        if (substringEndIndex != -1) {
          return sdkVersionString.substring(index + 1, substringEndIndex);
        }
      }
    }
    return '';
  }

  /// Determine what SDK channel (if applicable, for documenting packages) the
  /// package is built off of. Default to bleeding edge.
  String get sdkChannel {
    String channelString = _versionSubstringHelper('.', '-');
    if (channelString != 'edge' && channelString != '') return channelString;
    return 'be';
  }

  /// Determine the actual SDK revision number (if applicable and available)
  /// that this package was built with.
  String get sdkRevisionNum {
    var result = _versionSubstringHelper('.');
    if (result != '') return result + VERSION_NUM_SEPARATOR;
    return result;
  }

  String get highLevelSdkVersion => sdkVersionString.indexOf('-') != -1 ?
      sdkVersionString.substring(0, sdkVersionString.indexOf('-')) :
      sdkVersionString;

  void togglePanel() => viewer.togglePanel();
  void toggleInherited() => viewer.toggleInherited();
  void toggleObjectMembers() => viewer.toggleObjectMembers();
  void toggleMinimap() => viewer.toggleMinimap();

  /// We want the search and options to collapse into a menu button if there
  /// isn't room for them to fit, but the amount of room taken up by the
  /// breadcrumbs is dynamic, so we calculate the widths programmatically
  /// and set the collapse style if necessary. As a bonus, when we're expanding
  /// we have to make them visible first in order to measure the width to know
  /// if we should leave them visible or not.
  void collapseSearchAndOptionsIfNeeded() {
    // TODO(alanknight) : This is messy because we've deleted many of the
    // bootstrap-specific attributes, but we need some of it in order to have
    // things look right. This leads to the odd behavior where the drop-down
    // makes the crumbs appear either in the title bar or dropping down,
    // depending how wide the window is. I'm calling that a feature for now,
    // but it could still use cleanup.
    var permanentHeaders = shadowRoot.querySelectorAll(".navbar-brand");
    var searchAndOptions = shadowRoot.querySelector("#searchAndOptions");
    var searchBox = shadowRoot.querySelector("search-box") as Search;
    if (searchBox.isFocused) return;
    var wholeThing = shadowRoot.querySelector(".navbar-fixed-top");
    var navbar = shadowRoot.querySelector("#navbar");
    var collapsible = shadowRoot.querySelector("#nav-collapse-content");
    // First, we make it visible, so we can see how large it _would_ be.
    collapsible.classes.add("in");
    var allItems = permanentHeaders.toList()
      ..add(searchAndOptions)
      ..add(navbar);
    var innerWidth = allItems.fold(0,
        (sum, element) => sum + element.marginEdge.width);
    var outerWidth = wholeThing.contentEdge.width;
    var button = shadowRoot.querySelector("#nav-collapse-button");
    // Then if it's too big, we make it go away again.
    if (outerWidth <= innerWidth) {
      button.classes.add("visible");
      collapsible.classes.remove("in");
    } else {
      button.classes.remove("visible");
      collapsible.classes.add("in");
    }
  }

  void toggleOptionsMenu(MouseEvent event, detail, target) {
    var list = shadowRoot.querySelector(".dropdown-menu").parent;
    if (list.classes.contains("open")) {
      list.classes.remove("open");
    } else {
      _openedAt = event.timeStamp;
      list.classes.add("open");
    }
  }

  void hideOptionsMenuWhenClickedOutside(MouseEvent e) {
    if (_openedAt != null && _openedAt == e.timeStamp) {
      _openedAt == null;
      return;
    }
    hideOptionsMenu();
  }

  void hideOptionsMenu() {
    var list = shadowRoot.querySelector(".dropdown-menu").parent;
    list.classes.remove("open");
  }

  /// Collapse/expand the navbar when in mobile. Workaround for something
  /// that ought to happen magically with bootstrap, but fails in the
  /// presence of shadow DOM.
  void navHideShow(event, detail, target) {
    var nav = shadowRoot.querySelector("#nav-collapse-content");
    hideOrShowNavigation(hide: nav.classes.contains("in"), nav: nav);
  }

  void hideOrShowNavigation({bool hide: true, Element nav}) {
    var searchBox = shadowRoot.querySelector("search-box") as Search;
    if (searchBox.isFocused) return;
    if (nav == null) nav = shadowRoot.querySelector("#nav-collapse-content");
    var button = shadowRoot.querySelector("#nav-collapse-button");
    if (hide && button.getComputedStyle().display != 'none') {
      nav.classes.remove("in");
    } else {
      nav.classes.add("in");
    }
    // The navbar is fixed, but can change size. We need to tell the main
    // body to be below the expanding navbar. This seems to be the least
    // horrible way to do that. But this will only work on the current page,
    // so if we change pages we have to make sure we close this.
    var navbar = shadowRoot.querySelector(".navbar-fixed-top");
    Element body = shadowRoot.querySelector(".main-body");
    var height = navbar.marginEdge.height;
    var positioning = navbar.getComputedStyle().position;
    if (positioning == "fixed") {
      body.style.paddingTop = height.toString() + "px";
    } else {
      body.style.removeProperty("padding-top");
    }
  }
}
