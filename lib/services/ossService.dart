import 'dart:io';
import 'package:aws_s3_api/s3-2006-03-01.dart';

class OssService {

  Future<void> uploadFileToS3(String filePath, String fileName) async {
    // 创建S3客户端
    final credentials = AwsClientCredentials(
      accessKey: 'YOUR_BITIFUL_ACCESS_KEY',
      secretKey: 'YOUR_BITIFUL_SECRET_KEY',
    );

    final s3 = S3(
      region: 'cn-east-1',
      credentials: credentials,
      endpointUrl: 'https://s3.bitiful.net'
    );

    final file = File(filePath);

    try {
      // 使用S3客户端上传文件
      final uploadResponse = await s3.putObject(
        bucket: 'leoon-cn', // 你的S3桶名称
        key: fileName,
        body: file.readAsBytesSync(),
        contentType: 'image/jpeg', // 根据文件类型选择
      );
      print('文件上传成功: ${uploadResponse.eTag}');
    } catch (e) {
      print('上传失败: $e');
    }
  }
}
