import 'dart:io';
import 'package:aws_s3_api/s3-2006-03-01.dart';

class OssService {
  Future<void> uploadFileToS3(String filePath, String fileName,
      {String fileType = 'image/jpeg'}) async {
    // 创建S3客户端（缤纷）
    final credentials = AwsClientCredentials(
      accessKey: 'YOUR_BITIFUL_ACCESS_KEY',
      secretKey: 'YOUR_BITIFUL_SECRET_KEY',
    );
    final s3 = S3(
        region: 'cn-east-1',
        credentials: credentials,
        endpointUrl: 'https://s3.bitiful.net');

    // 创建S3客户端（七牛）
    final credentialsQiniu = AwsClientCredentials(
      accessKey: 'YOUR_QINIU_ACCESS_KEY',
      secretKey: 'YOUR_QINIU_SECRET_KEY',
    );
    final s3Qiniu = S3(
        region: 'cn-south-1',
        credentials: credentialsQiniu,
        endpointUrl: 'https://s3.cn-south-1.qiniucs.com');

    final file = File(filePath);
    final fileBytes = file.readAsBytesSync();

    try {
      // 并行上传到两个 S3 端点
      final responses = await Future.wait([
        s3.putObject(
          bucket: 'leoon-cn',
          key: fileName,
          body: fileBytes,
          contentType: fileType,
        ),
        s3Qiniu.putObject(
          bucket: 'leoon-cn',
          key: fileName,
          body: fileBytes,
          contentType: fileType,
        ),
      ]);

      print('文件上传成功: ${responses.map((res) => res.eTag).join(", ")}');
    } catch (e) {
      print('上传失败: $e');
    }
  }
}
