//
// network_manager.dart
// KYSuperApp
//
// Created by 曹雪松 on 2020/7/27.
// Copyright © 2020 KYDW. All rights reserved.
//
import 'dart:core';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_app/network/interceptors/header_interceptor.dart';
import 'package:flutter_app/network/interceptors/response_interceptor.dart';
import 'package:flutter_app/extension/null_safe_extension.dart';
import 'package:flutter_app/network/model/base_model.dart';
import 'package:flutter_app/network/network_connectivity.dart';
import 'package:flutter_app/network/response_code.dart';
import 'package:oktoast/oktoast.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';



import 'api.dart';

enum Method { get, post }

typedef DownloadStart = void Function();
typedef DownloadCanceled = void Function();
typedef DownloadCompleted = void Function();
typedef DownloadError = void Function(String msg);
const CANCEL="CANCELED";

///
/// 网络请求单例
///
class NetworkManager {
  /// 超时时间
  static const int sendTimeout = 10 * 1000;
  static const int connectTimeout = 10 * 1000; // 毫秒
  static const int receiveTimeout = 10 * 1000;
  static const int fileDownLoadTimeout = 60 * 1000;

  static final NetworkManager _instance = NetworkManager._internal();

  factory NetworkManager.shared() => _instance;
  Dio _dio;

  NetworkManager._internal({String baseUrl}) {
    if (null == _dio) {
      _dio = new Dio(new BaseOptions(
        baseUrl: Api.baseUrl,
        sendTimeout: sendTimeout,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
      ));
    }
    _dio.interceptors.add(HeaderInterceptor());
    _dio.interceptors.add(ResponseInterceptor());
  }

  // MARK: Public Method

  ///
  /// 发起一个 GET 请求
  ///
  /// 根据[showLoading]控制是否显示一个状态弹框，默认值为 false, 如果设置为 true, 需要传入[loadingMessage]。
  ///
  /// 如果需要更改当前请求的 baseUrl / 请求超时时间 / 响应超时时间 等等参数, 请单独配置请求的 [options] 参数，具体可配置参数参照[RequestOptions]。
  ///
  /// eg:
  /// ```dart
  ///   NetworkManager.shared()
  ///   .get(
  ///     Api.xxx,
  ///     options: RequestOptions(
  ///       baseUrl: Api.keyMachineBaseUrl,
  ///       connectTimeout: xxx,
  ///       receiveTimeout: xxx
  ///     )
  ///  );
  /// ```
  Future<Response<T>> get<T>(
      String path, {
      Map<String, dynamic> parameters = const {},
      bool showLoading = false,
      String loadingMessage,
      bool showErrorLoading = true,
      bool checkConnectivity = true,
      Options options,
      CancelToken cancelToken,
      ProgressCallback onSendProgress
    }) async {
    return _request(
        path,
        Method.get,
        parameters: parameters,
        showLoading: showLoading,
        loadingMessage: loadingMessage,
        showErrorLoading: showErrorLoading,
        checkConnectivity: checkConnectivity,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress
    );
  }

  ///
  /// 发起一个 POST 请求
  ///
  /// 根据[showLoading]控制是否显示一个状态弹框，默认值为 false, 如果设置为 true, 需要传入[loadingMessage]。
  ///
  /// 如果需要更改当前请求的 baseUrl / 请求超时时间 / 响应超时时间 等等参数, 请单独配置请求的 [options] 参数，具体可配置参数参照[RequestOptions]。
  ///
  /// eg:
  /// ```dart
  ///   NetworkManager.shared()
  ///   .post(
  ///     Api.xxx,
  ///     options: RequestOptions(
  ///       baseUrl: Api.keyMachineBaseUrl,
  ///       connectTimeout: xxx,
  ///       receiveTimeout: xxx
  ///     )
  ///   );
  /// ```
  Future<Response<T>> post<T>(
      String path, {
      Map<String, dynamic> parameters = const {},
      bool showLoading = false,
      String loadingMessage,
      bool showErrorLoading = true,
      bool checkConnectivity = true,
      Options options,
      CancelToken cancelToken,
      ProgressCallback onSendProgress,
      ProgressCallback onReceiveProgress
    }) async {
    return _request(
      path,
      Method.post,
      parameters: parameters,
      showLoading: showLoading,
      loadingMessage: loadingMessage,
      showErrorLoading: showErrorLoading,
      checkConnectivity: checkConnectivity,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  ///
  /// 下载 指定[urlPath] 的文件到指定的目录[savePath]
  ///
  /// `注意` 调用文件下载接口之前，请检查存储权限保证用户已经授权。文件本地存储权限请在单独权限工具类处理，以确保用户授权后可直接开始下载。
  ///
  /// 根据[showLoading]控制是否显示一个下载进度状态弹框，默认值为 false, 如果设置为 true, 需要传入[loadingMessage]。
  ///
  /// 如果需要更改当前请求的 baseUrl / 请求超时时间 / 响应超时时间 等等参数, 请单独配置请求的 [options] 参数，具体可配置参数参照[RequestOptions]。
  ///
  /// eg:
  /// ```dart
  ///   NetworkManager.shared()
  ///   .download(
  ///     fileUrl,
  ///     saveFilePath,
  ///     options: RequestOptions(
  ///       baseUrl: Api.ApkHost,
  ///     )
  ///   );
  /// ```
  ///
  Future<Response> download(
    String urlPath,
    savePath, {
    bool showProgress = true,
    String progressStatus,
    ProgressCallback onReceiveProgress,
    Map<String, dynamic> queryParameters,
    CancelToken cancelToken,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
    data,
    Options options,
    DownloadStart start,
    DownloadCanceled canceled,
    DownloadCompleted completed,
        DownloadError error
  }) async {
    try {
      bool networkUnavailable = await isNetworkUnavailable();
      print("networkUnavailable"+networkUnavailable.toString());
      if (networkUnavailable) {

        return null;
      }
      bool permissOk = true;
      // if (Platform.isAndroid) {
      //   var status = await Permission.storage.status;
      //   if (status.isUndetermined) {
      //     permissOk = await Permission.storage.request().isGranted;
      //   } else {
      //     permissOk = await Permission.storage.isGranted;
      //   }
      //   // permissOk = await PermissionUtils.checkPermiss([PermissionGroup.storage]);
      // }
      if (permissOk) {
        if (start != null) {
          start();
        }
        Response response = await _dio.download(urlPath, savePath,
            onReceiveProgress: (received, total) {
          if (total != -1) {
            if (showProgress) {
              print(
                  "当前进度=" + (received / total * 100).toStringAsFixed(0) + "%");

              var progress = (received / total);
              EasyLoading.showProgress(progress, status: progress.toString());
            }
            if (received == total) {
              EasyLoading.dismiss(animation: false);
            }
          }
          if (onReceiveProgress != null) {
            onReceiveProgress(received, total);
          }
          if (received == total && completed != null) {
            completed();
          }
        },
            queryParameters: queryParameters,
            cancelToken: cancelToken,
            deleteOnError: deleteOnError,
            lengthHeader: lengthHeader,
            data: data,
            options: options);
        return response;
      } else {
        showToast( "请开启存储权限",
            dismissOtherToast: true, position: ToastPosition.bottom);
        return null;
      }
    } on DioError catch (e) {
       if(showProgress){
         EasyLoading.dismiss(animation: false);
         EasyLoading.showError(e.message);
       }
      if (e.message == CANCEL && canceled != null) {
        canceled();
      } else{
        error(e.message);
      }
      return null;
    }
  }

  // MARK: Private Method

  Future<Response<T>> _request<T>(
    String path,
    Method method, {
    Map<String, dynamic> parameters = const {},
    bool showLoading = false,
    String loadingMessage,
    bool showErrorLoading,
    bool checkConnectivity,
    Options options,
    CancelToken cancelToken,
    ProgressCallback onSendProgress,
    ProgressCallback onReceiveProgress,
  }) async {
    Response response;
    try {
      if (checkConnectivity) {
        bool networkUnavailable = await isNetworkUnavailable();
        if (networkUnavailable) {
          EasyLoading.showError("网络不可用");
          return null;
        }
      }

      if (showLoading) {
        EasyLoading.show(status:"??");
      }

      if (method == Method.get) {
        response = await _dio.get(
            path,
            queryParameters: parameters,
            options: options,
            cancelToken: cancelToken,
            onReceiveProgress: onReceiveProgress
        );
      }
      if (method == Method.post) {
        response = await _dio.post(
            path,
            data: parameters,
            options: options,
            cancelToken: cancelToken,
            onSendProgress: onSendProgress,
            onReceiveProgress: onReceiveProgress
        );
      }

      if (showLoading) EasyLoading.dismiss(animation: false);

      if (response.request.baseUrl == Api.baseUrl) {
        final baseModel = BaseModel.fromJson(response.data);
        if (baseModel.code != ResponseStatusCode.success && baseModel.message.isNotNullOrEmpty && showErrorLoading) {
          EasyLoading.showError("${baseModel.message} (code: ${baseModel.code})", duration: Duration(seconds: 2));
        }
      }

      return response;

    } on DioError catch (e) {
      if (showLoading) EasyLoading.dismiss(animation: false);
      if (showErrorLoading) {
        EasyLoading.showError(e.message, duration: Duration(seconds: 2));
      }
      if (e.type == DioErrorType.CANCEL) { return null; }
      return Future.error(e);
     }
  }
}

