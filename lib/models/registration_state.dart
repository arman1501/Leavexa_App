// ─────────────────────────────────────────────────────────────────────────────
//  registration_state.dart  –  Faculty Registration State Machine
// ─────────────────────────────────────────────────────────────────────────────

enum RegistrationStep {
  idle,
  validating,
  checking,
  creatingAuth,
  creatingProfile,
  completed,
  recoverableFailure,
  permanentFailure,
}

class RegistrationState {
  final RegistrationStep step;
  final String? message;
  final String? errorCode;
  final bool isRecoverable;

  const RegistrationState({
    this.step = RegistrationStep.idle,
    this.message,
    this.errorCode,
    this.isRecoverable = false,
  });

  bool get isIdle => step == RegistrationStep.idle;

  bool get isLoading =>
      step == RegistrationStep.validating ||
      step == RegistrationStep.checking ||
      step == RegistrationStep.creatingAuth ||
      step == RegistrationStep.creatingProfile;

  bool get isSuccess => step == RegistrationStep.completed;

  bool get isFailure =>
      step == RegistrationStep.recoverableFailure ||
      step == RegistrationStep.permanentFailure;

  String get stepDescription {
    switch (step) {
      case RegistrationStep.idle:
        return 'Ready';
      case RegistrationStep.validating:
        return 'Validating form details...';
      case RegistrationStep.checking:
        return 'Checking Employee ID availability...';
      case RegistrationStep.creatingAuth:
        return 'Creating secure credentials...';
      case RegistrationStep.creatingProfile:
        return 'Saving faculty profile...';
      case RegistrationStep.completed:
        return 'Registration successful!';
      case RegistrationStep.recoverableFailure:
        return message ?? 'Network error. Please tap retry.';
      case RegistrationStep.permanentFailure:
        return message ?? 'Registration failed.';
    }
  }

  RegistrationState copyWith({
    RegistrationStep? step,
    String? message,
    String? errorCode,
    bool? isRecoverable,
  }) {
    return RegistrationState(
      step: step ?? this.step,
      message: message ?? this.message,
      errorCode: errorCode ?? this.errorCode,
      isRecoverable: isRecoverable ?? this.isRecoverable,
    );
  }

  @override
  String toString() =>
      'RegistrationState($step, message: $message, errorCode: $errorCode, recoverable: $isRecoverable)';
}
