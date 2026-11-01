import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/diagnostic_log.dart';

/// Maps typed Rust domain failure codes to human-readable Chinese error messages.
String failureMessage(FailureCode? code) {
  if (code != null) {
    DiagnosticLog.shared.record(code, showHint: false);
  }
  return switch (code) {
    FailureCode.invalidRequest => '查询或筛选条件无效，请调整后重试',
    FailureCode.changedResponse => '数据格式无法识别，请重试',
    FailureCode.unsupportedContract => '数据版本暂不支持，请更新应用',
    FailureCode.sessionExpired => '学校会话已失效，请重新登录',
    FailureCode.moduleAuthRequired => '该服务要求重新验证身份，其他功能不受影响；请稍后重试',
    FailureCode.serviceUnavailable => '学校服务暂时不可用，请稍后重试',
    FailureCode.networkUnreachable => '无法连接网络，请检查手机网络或校园网后重试',
    FailureCode.captchaRequired => '学校要求验证码，请重新登录并完成验证',
    FailureCode.invalidCredentials => '账号或密码错误，请检查后重试',
    FailureCode.preLoginTip => '学校登录提示未通过，请稍后重试',
    FailureCode.accessPolicyDenied => '当前网络被学校访问策略拦截，请连接校园网或北航 VPN 后重试',
    FailureCode.redirectLimit => '学校认证跳转次数过多，请稍后重试',
    FailureCode.unsupportedPortal => '当前教务门户不提供该功能，请切换到本科生账号',
    FailureCode.credentialStore => '系统安全存储暂时不可用，请稍后重试',
    FailureCode.businessRejected => '学校业务系统暂未确认这次请求，请稍后刷新；这不代表账号已退出',
    null => '本地服务暂时不可用，请重试',
  };
}

/// The advice line shown under a failed read.
///
/// An offline device cannot open the school website either, so suggesting one
/// would be a dead end; a stale value means the reader already has content and
/// only needs to know it may be out of date.
String failureAdvice({required bool hasStaleValue, FailureCode? failure}) {
  if (hasStaleValue) return '正在显示上次结果。';
  return failure == FailureCode.networkUnreachable
      ? '手机当前连不上网络，恢复网络后重试。'
      : '请稍后重试，或在服务目录中打开官网。';
}
