import 'dart:async';

/// Emits whenever any source emits, once all three have produced a value.
///
/// Keeps us off `rxdart` for the handful of places the dashboard needs to
/// join a Realtime Database stream with Firestore snapshots.
Stream<R> combineLatest3<A, B, C, R>(
  Stream<A> streamA,
  Stream<B> streamB,
  Stream<C> streamC,
  R Function(A a, B b, C c) combine,
) {
  late StreamController<R> controller;
  final subscriptions = <StreamSubscription<dynamic>>[];

  A? latestA;
  B? latestB;
  C? latestC;
  var hasA = false;
  var hasB = false;
  var hasC = false;

  void emit() {
    if (!hasA || !hasB || !hasC) return;
    try {
      controller.add(combine(latestA as A, latestB as B, latestC as C));
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
    }
  }

  controller = StreamController<R>(
    onListen: () {
      subscriptions.addAll([
        streamA.listen(
          (value) { latestA = value; hasA = true; emit(); },
          onError: controller.addError,
        ),
        streamB.listen(
          (value) { latestB = value; hasB = true; emit(); },
          onError: controller.addError,
        ),
        streamC.listen(
          (value) { latestC = value; hasC = true; emit(); },
          onError: controller.addError,
        ),
      ]);
    },
    onCancel: () async {
      await Future.wait(subscriptions.map((s) => s.cancel()));
      subscriptions.clear();
    },
  );

  return controller.stream;
}
