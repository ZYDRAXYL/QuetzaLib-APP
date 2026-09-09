import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/app_update_info.dart';
import 'apk_installer.dart';

/// Checks GitHub Releases for a newer QuetzaLib build and, when the user
/// opts in, downloads the APK and hands it to the system installer — the
/// standard way to update a sideloaded Android app that isn't distributed
/// through the Play Store.
class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  static const _releasesUrl =
      'https://api.github.com/repos/ZYDRAXYL/QuetzaLib-APP/releases/latest';

  final http.Client _client;

  /// The currently installed app version, e.g. "1.0.1".
  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Fetches the latest GitHub release and returns its details if it's
  /// newer than the installed version and has an APK asset attached, or
  /// null if the app is already up to date.
  Future<AppUpdateInfo?> checkForUpdate() async {
    final current = await currentVersion();

    final response = await _client.get(
      Uri.parse(_releasesUrl),
      headers: const {'Accept': 'application/vnd.github+json'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('GitHub returned HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final tagName = body['tag_name'] as String?;
    if (tagName == null) return null;
    final latest = tagName.startsWith('v') ? tagName.substring(1) : tagName;

    if (!_isNewer(latest, current)) return null;

    Map<String, dynamic>? apkAsset;
    for (final asset in (body['assets'] as List<dynamic>? ?? [])) {
      final map = asset as Map<String, dynamic>;
      if ((map['name'] as String? ?? '').endsWith('.apk')) {
        apkAsset = map;
        break;
      }
    }
    final downloadUrl = apkAsset?['browser_download_url'] as String?;
    if (downloadUrl == null) return null;

    return AppUpdateInfo(
      version: latest,
      downloadUrl: downloadUrl,
      apkSizeBytes: apkAsset?['size'] as int? ?? 0,
      releaseNotes: (body['body'] as String? ?? '').trim(),
      releaseUrl: body['html_url'] as String? ?? '',
    );
  }

  /// The local file [update]'s APK is (or would be) downloaded to.
  Future<File> apkFileFor(AppUpdateInfo update) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    return File('${dir.path}/quetzalib-${update.version}.apk');
  }

  /// The already-downloaded APK for [update], or null if it hasn't been
  /// downloaded yet (or the cached copy is incomplete). Lets the UI offer
  /// "install" on its own, so a failed install doesn't cost a second
  /// download of the same file.
  Future<File?> downloadedApk(AppUpdateInfo update) async {
    final file = await apkFileFor(update);
    if (!await file.exists()) return null;
    if (update.apkSizeBytes > 0 &&
        await file.length() != update.apkSizeBytes) {
      // A truncated leftover from an interrupted download.
      await file.delete();
      return null;
    }
    return file;
  }

  /// Downloads [update]'s APK to a private cache folder, reporting progress
  /// in `[0, 1]` via [onProgress], and returns the local file.
  ///
  /// The download lands in a `.part` file that is only renamed into place
  /// once the whole APK has arrived, so an interrupted download can never
  /// be mistaken for an installable one by [downloadedApk].
  Future<File> download(
    AppUpdateInfo update, {
    void Function(double progress)? onProgress,
  }) async {
    final file = await apkFileFor(update);
    await file.parent.create(recursive: true);
    await _deleteStaleDownloads(file);

    final response = await _client.send(
      http.Request('GET', Uri.parse(update.downloadUrl)),
    );
    if (response.statusCode != 200) {
      throw Exception('Download failed: HTTP ${response.statusCode}');
    }

    final total = response.contentLength ?? update.apkSizeBytes;
    final part = File('${file.path}.part');

    var received = 0;
    final sink = part.openWrite();
    try {
      await response.stream.map((chunk) {
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
        return chunk;
      }).pipe(sink);
    } finally {
      await sink.close();
    }
    if (total > 0 && received != total) {
      await part.delete();
      throw Exception('Download ended early ($received of $total bytes).');
    }
    if (await file.exists()) await file.delete();
    return part.rename(file.path);
  }

  /// Removes cached APKs (and partial downloads) for other versions, so the
  /// update cache never holds more than the one build being installed.
  Future<void> _deleteStaleDownloads(File keep) async {
    await for (final entry in keep.parent.list()) {
      if (entry is! File) continue;
      if (entry.path == keep.path) continue;
      if (entry.path.endsWith('.apk') || entry.path.endsWith('.apk.part')) {
        await entry.delete();
      }
    }
  }

  /// Requests the "install unknown apps" permission if needed, then hands
  /// [apk] to the system package installer and waits for the final result.
  Future<void> install(File apk) async {
    var status = await Permission.requestInstallPackages.status;
    if (!status.isGranted) {
      status = await Permission.requestInstallPackages.request();
    }
    if (!status.isGranted) {
      throw Exception(
        'QuetzaLib needs permission to install updates. Allow '
        '"Install unknown apps" for QuetzaLib in system settings, then '
        'try again.',
      );
    }
    final result = await ApkInstaller.install(apk.path);
    switch (result.outcome) {
      case InstallOutcome.success:
        return;
      case InstallOutcome.conflict:
        throw Exception(
          'This update is signed differently than the app already on this '
          'device, so Android won\'t install it over the existing app. '
          'Uninstall QuetzaLib first, then install this update -- note '
          'that uninstalling erases your local library, since it isn\'t '
          'backed up anywhere else.',
        );
      case InstallOutcome.failure:
        throw Exception(result.message ?? 'Install was not completed.');
    }
  }

  /// True if dotted version [a] is greater than [b]. A trailing `-suffix`
  /// (e.g. "1.2.0-prototype") is ignored for comparison.
  bool _isNewer(String a, String b) {
    List<int> parts(String v) => v
        .split('-')
        .first
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();

    final pa = parts(a);
    final pb = parts(b);
    for (var i = 0; i < pa.length || i < pb.length; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va > vb;
    }
    return false;
  }

  void dispose() => _client.close();
}
