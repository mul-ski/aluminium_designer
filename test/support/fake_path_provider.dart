import 'dart:io';

import 'package:flutter_test/flutter_test.dart' show Fake;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A [PathProviderPlatform] that points `getApplicationDocumentsDirectory()`
/// at a real, freshly created temp directory instead of a platform channel.
///
/// `CatalogStore`/`ProjectStore` do real `dart:io` file/directory
/// operations under whatever `getApplicationDocumentsDirectory()` returns
/// -- there is no in-memory storage abstraction to swap in its place, and
/// testing seeding/persistence honestly requires exercising real file
/// I/O, not a mocked-away store. So this fakes only the one platform
/// channel `path_provider` depends on, pointing it at a real (temporary,
/// test-owned) directory on disk.
///
/// Uses `Fake` + `MockPlatformInterfaceMixin` rather than `extends
/// PathProviderPlatform` directly -- this is the pattern the
/// `path_provider` package's own tests use. `PathProviderPlatform`
/// extends `PlatformInterface`, whose constructor performs a token check
/// on every subclass; a bare `extends PathProviderPlatform` skips that
/// setup and can leave `PathProviderPlatform.instance` in a broken state.
/// `MockPlatformInterfaceMixin` exists specifically to bypass that check
/// for test doubles.
///
/// Each test that uses this should create its own temp dir and delete it
/// in a `tearDown`, so tests don't see each other's persisted catalogs.
class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory directory;

  FakePathProviderPlatform(this.directory);

  @override
  Future<String?> getApplicationDocumentsPath() async => directory.path;
}
