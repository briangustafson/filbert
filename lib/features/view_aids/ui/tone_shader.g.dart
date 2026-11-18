// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tone_shader.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The viewing-aid shader (`shaders/view_aids.frag`, m2-design §5.3),
/// loaded once.

@ProviderFor(toneProgram)
final toneProgramProvider = ToneProgramProvider._();

/// The viewing-aid shader (`shaders/view_aids.frag`, m2-design §5.3),
/// loaded once.

final class ToneProgramProvider
    extends
        $FunctionalProvider<
          AsyncValue<ui.FragmentProgram>,
          ui.FragmentProgram,
          FutureOr<ui.FragmentProgram>
        >
    with
        $FutureModifier<ui.FragmentProgram>,
        $FutureProvider<ui.FragmentProgram> {
  /// The viewing-aid shader (`shaders/view_aids.frag`, m2-design §5.3),
  /// loaded once.
  ToneProgramProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'toneProgramProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$toneProgramHash();

  @$internal
  @override
  $FutureProviderElement<ui.FragmentProgram> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ui.FragmentProgram> create(Ref ref) {
    return toneProgram(ref);
  }
}

String _$toneProgramHash() => r'7a67e17d2ae2a96f3b156f3d3b3ffc9d3cb3c367';
