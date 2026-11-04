/// Dart layer: MutationResult enum mirroring Rust implementation
/// Ensures type-safe handling on the Flutter side

library ginkgo_mirror.mutation_result;

enum MutationResultStatus {
  success,
  partialSuccess,
  failure,
  requiresInput,
  validationError,
}

/// Generic mutation result - matches Rust counterpart
class MutationResult<T> {
  final MutationResultStatus status;
  final T? data;
  final String? warning;
  final ErrorCode? errorCode;
  final String? errorMessage;
  final bool? isRetriable;
  final InputPrompt? inputPrompt;
  final String? context;
  final String? validationField;
  final String? validationReason;

  MutationResult({
    required this.status,
    this.data,
    this.warning,
    this.errorCode,
    this.errorMessage,
    this.isRetriable,
    this.inputPrompt,
    this.context,
    this.validationField,
    this.validationReason,
  });

  bool get isSuccess =>
      status == MutationResultStatus.success ||
      status == MutationResultStatus.partialSuccess;

  bool get isFailed =>
      status == MutationResultStatus.failure ||
      status == MutationResultStatus.validationError;

  bool get needsInput => status == MutationResultStatus.requiresInput;

  /// Factory: Success case
  factory MutationResult.ok(T data) => MutationResult(
    status: MutationResultStatus.success,
    data: data,
  );

  /// Factory: Partial success with warning
  factory MutationResult.partial(T data, String warning) => MutationResult(
    status: MutationResultStatus.partialSuccess,
    data: data,
    warning: warning,
  );

  /// Factory: Failure case
  factory MutationResult.fail({
    required ErrorCode code,
    required String message,
    required bool retriable,
  }) =>
      MutationResult(
        status: MutationResultStatus.failure,
        errorCode: code,
        errorMessage: message,
        isRetriable: retriable,
      );

  /// Factory: Requires user input
  factory MutationResult.needsInput({
    required InputPrompt prompt,
    required String context,
  }) =>
      MutationResult(
        status: MutationResultStatus.requiresInput,
        inputPrompt: prompt,
        context: context,
      );

  /// Factory: Validation error
  factory MutationResult.validationFailed({
    required String field,
    required String reason,
  }) =>
      MutationResult(
        status: MutationResultStatus.validationError,
        validationField: field,
        validationReason: reason,
      );

  /// Map success case
  MutationResult<U> map<U>(U Function(T) f) {
    if (isSuccess && data != null) {
      return MutationResult(
        status: status,
        data: f(data as T),
        warning: warning,
      );
    }
    return MutationResult(
      status: status,
      errorCode: errorCode,
      errorMessage: errorMessage,
      isRetriable: isRetriable,
    );
  }
}

/// Error codes - explicit classification
enum ErrorCode {
  // Authentication
  invalidCredentials,
  captchaRequired,
  sessionExpired,
  accessDenied,

  // Network
  serviceUnavailable,
  connectionFailed,

  // Protocol
  unexpectedResponse,
  invalidRequest,
  businessRejected,

  // Storage
  credentialStore,
  cacheCorrupted,
}

extension ErrorCodeExtension on ErrorCode {
  bool get isRetriable => switch (this) {
    ErrorCode.serviceUnavailable ||
    ErrorCode.connectionFailed ||
    ErrorCode.cacheCorrupted =>
      true,
    _ => false,
  };

  bool get requiresLogin => this == ErrorCode.sessionExpired;

  bool get locksAuthentication => switch (this) {
    ErrorCode.invalidCredentials || ErrorCode.accessDenied => true,
    _ => false,
  };

  String get description => switch (this) {
    ErrorCode.invalidCredentials => '账号或密码错误',
    ErrorCode.captchaRequired => '需要验证码',
    ErrorCode.sessionExpired => '登录已过期',
    ErrorCode.accessDenied => '访问被拒绝',
    ErrorCode.serviceUnavailable => '服务暂时不可用',
    ErrorCode.connectionFailed => '网络连接失败',
    ErrorCode.unexpectedResponse => '收到意外响应',
    ErrorCode.invalidRequest => '请求参数错误',
    ErrorCode.businessRejected => '业务拒绝',
    ErrorCode.credentialStore => '凭据存储错误',
    ErrorCode.cacheCorrupted => '本地数据损坏',
  };
}

/// Input prompts - what UI should display
abstract class InputPrompt {
  String get label;
}

class VerificationCodePrompt implements InputPrompt {
  final String imageBase64;
  final String challengeId;

  VerificationCodePrompt({
    required this.imageBase64,
    required this.challengeId,
  });

  @override
  String get label => '请输入验证码';
}

class PasswordPrompt implements InputPrompt {
  final String reason;

  PasswordPrompt(this.reason);

  @override
  String get label => '请输入密码';
}

class SelectionPrompt implements InputPrompt {
  final List<String> options;

  SelectionPrompt(this.options);

  @override
  String get label => '请选择';
}

/// Usage example (Flutter page)
class AuthPageExample {
  void handleMutationResult<T>(MutationResult<T> result) {
    if (result.isSuccess) {
      // Use result.data
      showSnackBar('成功');
    } else if (result.needsInput) {
      // Show input UI
      final prompt = result.inputPrompt;
      if (prompt is VerificationCodePrompt) {
        showVerificationDialog(prompt.imageBase64, prompt.challengeId);
      }
    } else if (result.isFailed) {
      // Handle error explicitly
      final code = result.errorCode;
      if (code?.requiresLogin ?? false) {
        showLoginScreen();
      } else if (code?.isRetriable ?? false) {
        showRetryButton();
      }
    }
  }

  void showSnackBar(String message) {}
  void showVerificationDialog(String image, String id) {}
  void showLoginScreen() {}
  void showRetryButton() {}
}
