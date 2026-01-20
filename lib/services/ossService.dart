import 'dart:io';
import 'package:aws_s3_api/s3-2006-03-01.dart';
import '../models/app_config.dart';

class OssService {
  /// 上传文件到所有启用的OSS
  Future<Map<String, String>> uploadFileToS3(
    String filePath,
    String fileName,
    List<OSSConfig> enabledOssList, {
    String fileType = 'image/jpeg',
  }) async {
    print('---------- OSS上传开始 ----------');
    print('文件路径: $filePath');
    print('目标文件名: $fileName');
    print('文件类型: $fileType');
    print('启用的OSS数量: ${enabledOssList.length}');

    if (enabledOssList.isEmpty) {
      print('!!! 错误: 没有启用的OSS配置');
      throw Exception('没有启用的OSS配置，请先在设置中添加并启用OSS配置');
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      print('!!! 错误: 文件不存在: $filePath');
      throw Exception('文件不存在: $filePath');
    }

    print('读取文件字节...');
    final fileBytes = file.readAsBytesSync();
    print('文件大小: ${fileBytes.length} bytes');

    final uploadResults = <String, String>{};
    final errors = <String, String>{};

    // 并行上传到所有启用的 OSS
    final uploadTasks = enabledOssList.map((ossConfig) async {
      print('\n>>> 开始上传到 ${ossConfig.name}');
      print('  Endpoint: ${ossConfig.endpoint}');
      print('  Region: ${ossConfig.region}');
      print('  Bucket: ${ossConfig.bucket}');
      print('  AccessKey: ${ossConfig.accessKeyId.substring(0, 8)}...');

      try {
        final credentials = AwsClientCredentials(
          accessKey: ossConfig.accessKeyId,
          secretKey: ossConfig.secretAccessKey,
        );
        print('  凭证创建成功');

        final s3 = S3(
          region: ossConfig.region,
          credentials: credentials,
          endpointUrl: ossConfig.endpoint,
        );
        print('  S3客户端创建成功');

        print('  正在调用 putObject...');
        await s3.putObject(
          bucket: ossConfig.bucket,
          key: fileName,
          body: fileBytes,
          contentType: fileType,
        );
        print('  putObject 调用成功');

        // 构建文件URL
        String fileUrl;
        if (ossConfig.publicDomain.isNotEmpty) {
          // 使用自定义域名
          String domain = ossConfig.publicDomain;
          // 如果域名没有协议前缀，自动添加 https://
          if (!domain.startsWith('http://') && !domain.startsWith('https://')) {
            domain = 'https://$domain';
            print('  自动添加 https:// 前缀: $domain');
          }
          fileUrl = '$domain/$fileName';
          print('  使用自定义域名: $fileUrl');
        } else {
          // 使用默认S3 URL格式
          fileUrl = '${ossConfig.endpoint}/${ossConfig.bucket}/$fileName';
          print('  使用默认S3 URL: $fileUrl');
        }

        uploadResults[ossConfig.name] = fileUrl;
        print('✓ 上传到 ${ossConfig.name} 成功: $fileUrl');

        return fileUrl;
      } catch (e) {
        final errorMsg = e.toString();
        print('✗ 上传到 ${ossConfig.name} 失败');
        print('  错误类型: ${e.runtimeType}');
        print('  错误详情: $errorMsg');
        errors[ossConfig.name] = errorMsg;
        return null;
      }
    }).toList();

    print('\n等待所有上传任务完成...');
    // 等待所有上传完成（允许部分失败）
    await Future.wait(uploadTasks, eagerError: false);

    print('\n文件上传完成，成功: ${uploadResults.length}/${enabledOssList.length}');

    // 如果所有OSS都上传失败，抛出异常
    if (uploadResults.isEmpty) {
      print('!!! 所有OSS上传均失败');
      final errorDetails = errors.entries.map((e) => '${e.key}: ${e.value}').join('\n');
      print('错误详情:\n$errorDetails');
      throw Exception('所有OSS上传均失败:\n$errorDetails');
    }

    print('---------- OSS上传完成 ----------\n');
    return uploadResults;
  }
}
