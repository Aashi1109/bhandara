import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'login_flow.g.dart';

class LoginFlowState {
  LoginFlowState({this.data = const {}});

  final Map<String, dynamic> data;

  String? get email => data['email'] as String?;

  LoginFlowState copyWith({Map<String, dynamic>? data, bool clear = false}) {
    return LoginFlowState(data: clear ? const {} : (data ?? this.data));
  }

  @override
  String toString() => 'LoginFlowState(data: $data)';
}

@Riverpod(keepAlive: true)
class LoginFlow extends _$LoginFlow {
  @override
  LoginFlowState build() {
    return LoginFlowState();
  }

  void update(Map<String, dynamic> newData) {
    state = state.copyWith(
      data: Map<String, dynamic>.from(state.data)
        ..addAll(newData),
    );
  }

  void clear() {
    state = LoginFlowState(data: const {});
  }
}
