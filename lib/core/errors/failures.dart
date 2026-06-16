import 'package:equatable/equatable.dart';

/// Root failure type used across the app.
sealed class Failure extends Equatable {
  const Failure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class AuthFailure extends Failure { const AuthFailure(super.message); }
class NetworkFailure extends Failure { const NetworkFailure(super.message); }
class ServerFailure extends Failure { const ServerFailure(super.message); }
class ValidationFailure extends Failure { const ValidationFailure(super.message); }
class CacheFailure extends Failure { const CacheFailure(super.message); }
class PermissionFailure extends Failure { const PermissionFailure(super.message); }
class UnknownFailure extends Failure { const UnknownFailure(super.message); }
