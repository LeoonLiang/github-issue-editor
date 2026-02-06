/// Issue 中的图片信息
class IssueImageInfo {
  final String url;
  final String? thumbhash;
  final int? width;
  final int? height;
  final String? liveVideo;

  IssueImageInfo({
    required this.url,
    this.thumbhash,
    this.width,
    this.height,
    this.liveVideo,
  });

  bool get isLivePhoto => liveVideo != null && liveVideo!.isNotEmpty;
}
