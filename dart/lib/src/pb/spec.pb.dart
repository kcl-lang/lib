// This is a generated file - do not edit.
//
// Generated from spec.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Message representing an external package for KCL.
/// kcl main.k -E pkg_name=pkg_path
class ExternalPkg extends $pb.GeneratedMessage {
  factory ExternalPkg({
    $core.String? pkgName,
    $core.String? pkgPath,
  }) {
    final result = ExternalPkg._();
    if (pkgName != null) result.pkgName = pkgName;
    if (pkgPath != null) result.pkgPath = pkgPath;
    return result;
  }

  ExternalPkg._();

  factory ExternalPkg.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExternalPkg()..mergeFromBuffer(data, registry);
  factory ExternalPkg.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExternalPkg()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExternalPkg',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: ExternalPkg.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pkgName')
    ..aOS(2, _omitFieldNames ? '' : 'pkgPath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExternalPkg clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExternalPkg copyWith(void Function(ExternalPkg) updates) =>
      super.copyWith((message) => updates(message as ExternalPkg))
          as ExternalPkg;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ExternalPkg() / ExternalPkg.new instead')
  static ExternalPkg create() => ExternalPkg._();
  static $pb.GeneratedMessage $_createMessage() => ExternalPkg._();
  @$core.override
  ExternalPkg createEmptyInstance() => ExternalPkg._();
  @$core.pragma('dart2js:noInline')
  static ExternalPkg getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ExternalPkg>(
          ExternalPkg.$_createMessage);
  static ExternalPkg? _defaultInstance;

  /// Name of the package.
  @$pb.TagNumber(1)
  $core.String get pkgName => $_getSZ(0);
  @$pb.TagNumber(1)
  set pkgName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPkgName() => $_has(0);
  @$pb.TagNumber(1)
  void clearPkgName() => $_clearField(1);

  /// Path of the package.
  @$pb.TagNumber(2)
  $core.String get pkgPath => $_getSZ(1);
  @$pb.TagNumber(2)
  set pkgPath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPkgPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearPkgPath() => $_clearField(2);
}

/// Message representing a key-value argument for KCL.
/// kcl main.k -D name=value
class Argument extends $pb.GeneratedMessage {
  factory Argument({
    $core.String? name,
    $core.String? value,
  }) {
    final result = Argument._();
    if (name != null) result.name = name;
    if (value != null) result.value = value;
    return result;
  }

  Argument._();

  factory Argument.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Argument()..mergeFromBuffer(data, registry);
  factory Argument.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Argument()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Argument',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: Argument.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Argument clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Argument copyWith(void Function(Argument) updates) =>
      super.copyWith((message) => updates(message as Argument)) as Argument;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Argument() / Argument.new instead')
  static Argument create() => Argument._();
  static $pb.GeneratedMessage $_createMessage() => Argument._();
  @$core.override
  Argument createEmptyInstance() => Argument._();
  @$core.pragma('dart2js:noInline')
  static Argument getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Argument>(Argument.$_createMessage);
  static Argument? _defaultInstance;

  /// Name of the argument.
  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  /// Value of the argument.
  @$pb.TagNumber(2)
  $core.String get value => $_getSZ(1);
  @$pb.TagNumber(2)
  set value($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => $_clearField(2);
}

/// Message representing an error.
class Error extends $pb.GeneratedMessage {
  factory Error({
    $core.String? level,
    $core.String? code,
    $core.Iterable<Message>? messages,
  }) {
    final result = Error._();
    if (level != null) result.level = level;
    if (code != null) result.code = code;
    if (messages != null) result.messages.addAll(messages);
    return result;
  }

  Error._();

  factory Error.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Error()..mergeFromBuffer(data, registry);
  factory Error.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Error()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Error',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: Error.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'level')
    ..aOS(2, _omitFieldNames ? '' : 'code')
    ..pPM<Message>(3, _omitFieldNames ? '' : 'messages',
        subBuilder: Message.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Error clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Error copyWith(void Function(Error) updates) =>
      super.copyWith((message) => updates(message as Error)) as Error;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Error() / Error.new instead')
  static Error create() => Error._();
  static $pb.GeneratedMessage $_createMessage() => Error._();
  @$core.override
  Error createEmptyInstance() => Error._();
  @$core.pragma('dart2js:noInline')
  static Error getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Error>(Error.$_createMessage);
  static Error? _defaultInstance;

  /// Level of the error (e.g., "Error", "Warning").
  @$pb.TagNumber(1)
  $core.String get level => $_getSZ(0);
  @$pb.TagNumber(1)
  set level($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLevel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLevel() => $_clearField(1);

  /// Error code. (e.g., "E1001")
  @$pb.TagNumber(2)
  $core.String get code => $_getSZ(1);
  @$pb.TagNumber(2)
  set code($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearCode() => $_clearField(2);

  /// List of error messages.
  @$pb.TagNumber(3)
  $pb.PbList<Message> get messages => $_getList(2);
}

/// Message representing a detailed error message with a position.
class Message extends $pb.GeneratedMessage {
  factory Message({
    $core.String? msg,
    Position? pos,
  }) {
    final result = Message._();
    if (msg != null) result.msg = msg;
    if (pos != null) result.pos = pos;
    return result;
  }

  Message._();

  factory Message.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Message()..mergeFromBuffer(data, registry);
  factory Message.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Message()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Message',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: Message.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'msg')
    ..aOM<Position>(2, _omitFieldNames ? '' : 'pos',
        subBuilder: Position.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Message clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Message copyWith(void Function(Message) updates) =>
      super.copyWith((message) => updates(message as Message)) as Message;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Message() / Message.new instead')
  static Message create() => Message._();
  static $pb.GeneratedMessage $_createMessage() => Message._();
  @$core.override
  Message createEmptyInstance() => Message._();
  @$core.pragma('dart2js:noInline')
  static Message getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Message>(Message.$_createMessage);
  static Message? _defaultInstance;

  /// The error message text.
  @$pb.TagNumber(1)
  $core.String get msg => $_getSZ(0);
  @$pb.TagNumber(1)
  set msg($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMsg() => $_has(0);
  @$pb.TagNumber(1)
  void clearMsg() => $_clearField(1);

  /// The position in the source code where the error occurred.
  @$pb.TagNumber(2)
  Position get pos => $_getN(1);
  @$pb.TagNumber(2)
  set pos(Position value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPos() => $_has(1);
  @$pb.TagNumber(2)
  void clearPos() => $_clearField(2);
  @$pb.TagNumber(2)
  Position ensurePos() => $_ensure(1);
}

/// Message for ping request arguments.
class PingArgs extends $pb.GeneratedMessage {
  factory PingArgs({
    $core.String? value,
  }) {
    final result = PingArgs._();
    if (value != null) result.value = value;
    return result;
  }

  PingArgs._();

  factory PingArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PingArgs()..mergeFromBuffer(data, registry);
  factory PingArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PingArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PingArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: PingArgs.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingArgs copyWith(void Function(PingArgs) updates) =>
      super.copyWith((message) => updates(message as PingArgs)) as PingArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PingArgs() / PingArgs.new instead')
  static PingArgs create() => PingArgs._();
  static $pb.GeneratedMessage $_createMessage() => PingArgs._();
  @$core.override
  PingArgs createEmptyInstance() => PingArgs._();
  @$core.pragma('dart2js:noInline')
  static PingArgs getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PingArgs>(PingArgs.$_createMessage);
  static PingArgs? _defaultInstance;

  /// Value to be sent in the ping request.
  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

/// Message for ping response.
class PingResult extends $pb.GeneratedMessage {
  factory PingResult({
    $core.String? value,
  }) {
    final result = PingResult._();
    if (value != null) result.value = value;
    return result;
  }

  PingResult._();

  factory PingResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PingResult()..mergeFromBuffer(data, registry);
  factory PingResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PingResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PingResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: PingResult.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingResult copyWith(void Function(PingResult) updates) =>
      super.copyWith((message) => updates(message as PingResult)) as PingResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PingResult() / PingResult.new instead')
  static PingResult create() => PingResult._();
  static $pb.GeneratedMessage $_createMessage() => PingResult._();
  @$core.override
  PingResult createEmptyInstance() => PingResult._();
  @$core.pragma('dart2js:noInline')
  static PingResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PingResult>(PingResult.$_createMessage);
  static PingResult? _defaultInstance;

  /// Value received in the ping response.
  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

/// Message for version request arguments. Empty message.
class GetVersionArgs extends $pb.GeneratedMessage {
  factory GetVersionArgs() => GetVersionArgs._();

  GetVersionArgs._();

  factory GetVersionArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetVersionArgs()..mergeFromBuffer(data, registry);
  factory GetVersionArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetVersionArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetVersionArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: GetVersionArgs.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetVersionArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetVersionArgs copyWith(void Function(GetVersionArgs) updates) =>
      super.copyWith((message) => updates(message as GetVersionArgs))
          as GetVersionArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetVersionArgs() / GetVersionArgs.new instead')
  static GetVersionArgs create() => GetVersionArgs._();
  static $pb.GeneratedMessage $_createMessage() => GetVersionArgs._();
  @$core.override
  GetVersionArgs createEmptyInstance() => GetVersionArgs._();
  @$core.pragma('dart2js:noInline')
  static GetVersionArgs getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetVersionArgs>(
          GetVersionArgs.$_createMessage);
  static GetVersionArgs? _defaultInstance;
}

/// Message for version response.
class GetVersionResult extends $pb.GeneratedMessage {
  factory GetVersionResult({
    $core.String? version,
    $core.String? checksum,
    $core.String? gitSha,
    $core.String? versionInfo,
  }) {
    final result = GetVersionResult._();
    if (version != null) result.version = version;
    if (checksum != null) result.checksum = checksum;
    if (gitSha != null) result.gitSha = gitSha;
    if (versionInfo != null) result.versionInfo = versionInfo;
    return result;
  }

  GetVersionResult._();

  factory GetVersionResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetVersionResult()..mergeFromBuffer(data, registry);
  factory GetVersionResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetVersionResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetVersionResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: GetVersionResult.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'version')
    ..aOS(2, _omitFieldNames ? '' : 'checksum')
    ..aOS(3, _omitFieldNames ? '' : 'gitSha')
    ..aOS(4, _omitFieldNames ? '' : 'versionInfo')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetVersionResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetVersionResult copyWith(void Function(GetVersionResult) updates) =>
      super.copyWith((message) => updates(message as GetVersionResult))
          as GetVersionResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetVersionResult() / GetVersionResult.new instead')
  static GetVersionResult create() => GetVersionResult._();
  static $pb.GeneratedMessage $_createMessage() => GetVersionResult._();
  @$core.override
  GetVersionResult createEmptyInstance() => GetVersionResult._();
  @$core.pragma('dart2js:noInline')
  static GetVersionResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetVersionResult>(
          GetVersionResult.$_createMessage);
  static GetVersionResult? _defaultInstance;

  /// KCL version.
  @$pb.TagNumber(1)
  $core.String get version => $_getSZ(0);
  @$pb.TagNumber(1)
  set version($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => $_clearField(1);

  /// Checksum of the KCL version.
  @$pb.TagNumber(2)
  $core.String get checksum => $_getSZ(1);
  @$pb.TagNumber(2)
  set checksum($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChecksum() => $_has(1);
  @$pb.TagNumber(2)
  void clearChecksum() => $_clearField(2);

  /// Git Git SHA of the KCL code repo.
  @$pb.TagNumber(3)
  $core.String get gitSha => $_getSZ(2);
  @$pb.TagNumber(3)
  set gitSha($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGitSha() => $_has(2);
  @$pb.TagNumber(3)
  void clearGitSha() => $_clearField(3);

  /// Detailed version information as a string.
  @$pb.TagNumber(4)
  $core.String get versionInfo => $_getSZ(3);
  @$pb.TagNumber(4)
  set versionInfo($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVersionInfo() => $_has(3);
  @$pb.TagNumber(4)
  void clearVersionInfo() => $_clearField(4);
}

/// Message for list method request arguments. Empty message.
class ListMethodArgs extends $pb.GeneratedMessage {
  factory ListMethodArgs() => ListMethodArgs._();

  ListMethodArgs._();

  factory ListMethodArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListMethodArgs()..mergeFromBuffer(data, registry);
  factory ListMethodArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListMethodArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListMethodArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: ListMethodArgs.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListMethodArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListMethodArgs copyWith(void Function(ListMethodArgs) updates) =>
      super.copyWith((message) => updates(message as ListMethodArgs))
          as ListMethodArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListMethodArgs() / ListMethodArgs.new instead')
  static ListMethodArgs create() => ListMethodArgs._();
  static $pb.GeneratedMessage $_createMessage() => ListMethodArgs._();
  @$core.override
  ListMethodArgs createEmptyInstance() => ListMethodArgs._();
  @$core.pragma('dart2js:noInline')
  static ListMethodArgs getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListMethodArgs>(
          ListMethodArgs.$_createMessage);
  static ListMethodArgs? _defaultInstance;
}

/// Message for list method response.
class ListMethodResult extends $pb.GeneratedMessage {
  factory ListMethodResult({
    $core.Iterable<$core.String>? methodNameList,
  }) {
    final result = ListMethodResult._();
    if (methodNameList != null) result.methodNameList.addAll(methodNameList);
    return result;
  }

  ListMethodResult._();

  factory ListMethodResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListMethodResult()..mergeFromBuffer(data, registry);
  factory ListMethodResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListMethodResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListMethodResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: ListMethodResult.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'methodNameList')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListMethodResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListMethodResult copyWith(void Function(ListMethodResult) updates) =>
      super.copyWith((message) => updates(message as ListMethodResult))
          as ListMethodResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListMethodResult() / ListMethodResult.new instead')
  static ListMethodResult create() => ListMethodResult._();
  static $pb.GeneratedMessage $_createMessage() => ListMethodResult._();
  @$core.override
  ListMethodResult createEmptyInstance() => ListMethodResult._();
  @$core.pragma('dart2js:noInline')
  static ListMethodResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListMethodResult>(
          ListMethodResult.$_createMessage);
  static ListMethodResult? _defaultInstance;

  /// List of available method names.
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get methodNameList => $_getList(0);
}

/// Message for parse file request arguments.
class ParseFileArgs extends $pb.GeneratedMessage {
  factory ParseFileArgs({
    $core.String? path,
    $core.String? source,
    $core.Iterable<ExternalPkg>? externalPkgs,
  }) {
    final result = ParseFileArgs._();
    if (path != null) result.path = path;
    if (source != null) result.source = source;
    if (externalPkgs != null) result.externalPkgs.addAll(externalPkgs);
    return result;
  }

  ParseFileArgs._();

  factory ParseFileArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ParseFileArgs()..mergeFromBuffer(data, registry);
  factory ParseFileArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ParseFileArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ParseFileArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: ParseFileArgs.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOS(2, _omitFieldNames ? '' : 'source')
    ..pPM<ExternalPkg>(3, _omitFieldNames ? '' : 'externalPkgs',
        subBuilder: ExternalPkg.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ParseFileArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ParseFileArgs copyWith(void Function(ParseFileArgs) updates) =>
      super.copyWith((message) => updates(message as ParseFileArgs))
          as ParseFileArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ParseFileArgs() / ParseFileArgs.new instead')
  static ParseFileArgs create() => ParseFileArgs._();
  static $pb.GeneratedMessage $_createMessage() => ParseFileArgs._();
  @$core.override
  ParseFileArgs createEmptyInstance() => ParseFileArgs._();
  @$core.pragma('dart2js:noInline')
  static ParseFileArgs getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ParseFileArgs>(
          ParseFileArgs.$_createMessage);
  static ParseFileArgs? _defaultInstance;

  /// Path of the file to be parsed.
  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  /// Source code to be parsed.
  @$pb.TagNumber(2)
  $core.String get source => $_getSZ(1);
  @$pb.TagNumber(2)
  set source($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSource() => $_has(1);
  @$pb.TagNumber(2)
  void clearSource() => $_clearField(2);

  /// External packages path.
  @$pb.TagNumber(3)
  $pb.PbList<ExternalPkg> get externalPkgs => $_getList(2);
}

/// Message for parse file response.
class ParseFileResult extends $pb.GeneratedMessage {
  factory ParseFileResult({
    $core.String? astJson,
    $core.Iterable<$core.String>? deps,
    $core.Iterable<Error>? errors,
  }) {
    final result = ParseFileResult._();
    if (astJson != null) result.astJson = astJson;
    if (deps != null) result.deps.addAll(deps);
    if (errors != null) result.errors.addAll(errors);
    return result;
  }

  ParseFileResult._();

  factory ParseFileResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ParseFileResult()..mergeFromBuffer(data, registry);
  factory ParseFileResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ParseFileResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ParseFileResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: ParseFileResult.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'astJson')
    ..pPS(2, _omitFieldNames ? '' : 'deps')
    ..pPM<Error>(3, _omitFieldNames ? '' : 'errors',
        subBuilder: Error.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ParseFileResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ParseFileResult copyWith(void Function(ParseFileResult) updates) =>
      super.copyWith((message) => updates(message as ParseFileResult))
          as ParseFileResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ParseFileResult() / ParseFileResult.new instead')
  static ParseFileResult create() => ParseFileResult._();
  static $pb.GeneratedMessage $_createMessage() => ParseFileResult._();
  @$core.override
  ParseFileResult createEmptyInstance() => ParseFileResult._();
  @$core.pragma('dart2js:noInline')
  static ParseFileResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ParseFileResult>(
          ParseFileResult.$_createMessage);
  static ParseFileResult? _defaultInstance;

  /// Abstract Syntax Tree (AST) in JSON format.
  @$pb.TagNumber(1)
  $core.String get astJson => $_getSZ(0);
  @$pb.TagNumber(1)
  set astJson($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAstJson() => $_has(0);
  @$pb.TagNumber(1)
  void clearAstJson() => $_clearField(1);

  /// File dependency paths.
  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get deps => $_getList(1);

  /// List of parse errors.
  @$pb.TagNumber(3)
  $pb.PbList<Error> get errors => $_getList(2);
}

/// Message for parse program request arguments.
class ParseProgramArgs extends $pb.GeneratedMessage {
  factory ParseProgramArgs({
    $core.Iterable<$core.String>? paths,
    $core.Iterable<$core.String>? sources,
    $core.Iterable<ExternalPkg>? externalPkgs,
  }) {
    final result = ParseProgramArgs._();
    if (paths != null) result.paths.addAll(paths);
    if (sources != null) result.sources.addAll(sources);
    if (externalPkgs != null) result.externalPkgs.addAll(externalPkgs);
    return result;
  }

  ParseProgramArgs._();

  factory ParseProgramArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ParseProgramArgs()..mergeFromBuffer(data, registry);
  factory ParseProgramArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ParseProgramArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ParseProgramArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: ParseProgramArgs.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'paths')
    ..pPS(2, _omitFieldNames ? '' : 'sources')
    ..pPM<ExternalPkg>(3, _omitFieldNames ? '' : 'externalPkgs',
        subBuilder: ExternalPkg.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ParseProgramArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ParseProgramArgs copyWith(void Function(ParseProgramArgs) updates) =>
      super.copyWith((message) => updates(message as ParseProgramArgs))
          as ParseProgramArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ParseProgramArgs() / ParseProgramArgs.new instead')
  static ParseProgramArgs create() => ParseProgramArgs._();
  static $pb.GeneratedMessage $_createMessage() => ParseProgramArgs._();
  @$core.override
  ParseProgramArgs createEmptyInstance() => ParseProgramArgs._();
  @$core.pragma('dart2js:noInline')
  static ParseProgramArgs getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ParseProgramArgs>(
          ParseProgramArgs.$_createMessage);
  static ParseProgramArgs? _defaultInstance;

  /// Paths of the program files to be parsed.
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get paths => $_getList(0);

  /// Source codes to be parsed.
  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get sources => $_getList(1);

  /// External packages path.
  @$pb.TagNumber(3)
  $pb.PbList<ExternalPkg> get externalPkgs => $_getList(2);
}

/// Message for parse program response.
class ParseProgramResult extends $pb.GeneratedMessage {
  factory ParseProgramResult({
    $core.String? astJson,
    $core.Iterable<$core.String>? paths,
    $core.Iterable<Error>? errors,
  }) {
    final result = ParseProgramResult._();
    if (astJson != null) result.astJson = astJson;
    if (paths != null) result.paths.addAll(paths);
    if (errors != null) result.errors.addAll(errors);
    return result;
  }

  ParseProgramResult._();

  factory ParseProgramResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ParseProgramResult()..mergeFromBuffer(data, registry);
  factory ParseProgramResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ParseProgramResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ParseProgramResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: ParseProgramResult.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'astJson')
    ..pPS(2, _omitFieldNames ? '' : 'paths')
    ..pPM<Error>(3, _omitFieldNames ? '' : 'errors',
        subBuilder: Error.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ParseProgramResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ParseProgramResult copyWith(void Function(ParseProgramResult) updates) =>
      super.copyWith((message) => updates(message as ParseProgramResult))
          as ParseProgramResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ParseProgramResult() / ParseProgramResult.new instead')
  static ParseProgramResult create() => ParseProgramResult._();
  static $pb.GeneratedMessage $_createMessage() => ParseProgramResult._();
  @$core.override
  ParseProgramResult createEmptyInstance() => ParseProgramResult._();
  @$core.pragma('dart2js:noInline')
  static ParseProgramResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ParseProgramResult>(
          ParseProgramResult.$_createMessage);
  static ParseProgramResult? _defaultInstance;

  /// Abstract Syntax Tree (AST) in JSON format.
  @$pb.TagNumber(1)
  $core.String get astJson => $_getSZ(0);
  @$pb.TagNumber(1)
  set astJson($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAstJson() => $_has(0);
  @$pb.TagNumber(1)
  void clearAstJson() => $_clearField(1);

  /// Returns the files in the order they should be compiled.
  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get paths => $_getList(1);

  /// List of parse errors.
  @$pb.TagNumber(3)
  $pb.PbList<Error> get errors => $_getList(2);
}

/// Message for load package request arguments.
class LoadPackageArgs extends $pb.GeneratedMessage {
  factory LoadPackageArgs({
    ParseProgramArgs? parseArgs,
    $core.bool? resolveAst,
    $core.bool? loadBuiltin,
    $core.bool? withAstIndex,
  }) {
    final result = LoadPackageArgs._();
    if (parseArgs != null) result.parseArgs = parseArgs;
    if (resolveAst != null) result.resolveAst = resolveAst;
    if (loadBuiltin != null) result.loadBuiltin = loadBuiltin;
    if (withAstIndex != null) result.withAstIndex = withAstIndex;
    return result;
  }

  LoadPackageArgs._();

  factory LoadPackageArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LoadPackageArgs()..mergeFromBuffer(data, registry);
  factory LoadPackageArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LoadPackageArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoadPackageArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: LoadPackageArgs.$_createMessage)
    ..aOM<ParseProgramArgs>(1, _omitFieldNames ? '' : 'parseArgs',
        subBuilder: ParseProgramArgs.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'resolveAst')
    ..aOB(3, _omitFieldNames ? '' : 'loadBuiltin')
    ..aOB(4, _omitFieldNames ? '' : 'withAstIndex')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadPackageArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadPackageArgs copyWith(void Function(LoadPackageArgs) updates) =>
      super.copyWith((message) => updates(message as LoadPackageArgs))
          as LoadPackageArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LoadPackageArgs() / LoadPackageArgs.new instead')
  static LoadPackageArgs create() => LoadPackageArgs._();
  static $pb.GeneratedMessage $_createMessage() => LoadPackageArgs._();
  @$core.override
  LoadPackageArgs createEmptyInstance() => LoadPackageArgs._();
  @$core.pragma('dart2js:noInline')
  static LoadPackageArgs getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LoadPackageArgs>(
          LoadPackageArgs.$_createMessage);
  static LoadPackageArgs? _defaultInstance;

  /// Arguments for parsing the program.
  @$pb.TagNumber(1)
  ParseProgramArgs get parseArgs => $_getN(0);
  @$pb.TagNumber(1)
  set parseArgs(ParseProgramArgs value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasParseArgs() => $_has(0);
  @$pb.TagNumber(1)
  void clearParseArgs() => $_clearField(1);
  @$pb.TagNumber(1)
  ParseProgramArgs ensureParseArgs() => $_ensure(0);

  /// Flag indicating whether to resolve AST.
  @$pb.TagNumber(2)
  $core.bool get resolveAst => $_getBF(1);
  @$pb.TagNumber(2)
  set resolveAst($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasResolveAst() => $_has(1);
  @$pb.TagNumber(2)
  void clearResolveAst() => $_clearField(2);

  /// Flag indicating whether to load built-in modules.
  @$pb.TagNumber(3)
  $core.bool get loadBuiltin => $_getBF(2);
  @$pb.TagNumber(3)
  set loadBuiltin($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLoadBuiltin() => $_has(2);
  @$pb.TagNumber(3)
  void clearLoadBuiltin() => $_clearField(3);

  /// Flag indicating whether to include AST index.
  @$pb.TagNumber(4)
  $core.bool get withAstIndex => $_getBF(3);
  @$pb.TagNumber(4)
  set withAstIndex($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasWithAstIndex() => $_has(3);
  @$pb.TagNumber(4)
  void clearWithAstIndex() => $_clearField(4);
}

/// Message for load package response.
class LoadPackageResult extends $pb.GeneratedMessage {
  factory LoadPackageResult({
    $core.String? program,
    $core.Iterable<$core.String>? paths,
    $core.Iterable<Error>? parseErrors,
    $core.Iterable<Error>? typeErrors,
    $core.Iterable<$core.MapEntry<$core.String, Scope>>? scopes,
    $core.Iterable<$core.MapEntry<$core.String, Symbol>>? symbols,
    $core.Iterable<$core.MapEntry<$core.String, SymbolIndex>>? nodeSymbolMap,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? symbolNodeMap,
    $core.Iterable<$core.MapEntry<$core.String, SymbolIndex>>?
        fullyQualifiedNameMap,
    $core.Iterable<$core.MapEntry<$core.String, ScopeIndex>>? pkgScopeMap,
    $core.Iterable<$core.MapEntry<$core.String, FileImports>>? imports,
    KclMod? kclMod,
    $core.Iterable<AppInfo>? apps,
  }) {
    final result = LoadPackageResult._();
    if (program != null) result.program = program;
    if (paths != null) result.paths.addAll(paths);
    if (parseErrors != null) result.parseErrors.addAll(parseErrors);
    if (typeErrors != null) result.typeErrors.addAll(typeErrors);
    if (scopes != null) result.scopes.addEntries(scopes);
    if (symbols != null) result.symbols.addEntries(symbols);
    if (nodeSymbolMap != null) result.nodeSymbolMap.addEntries(nodeSymbolMap);
    if (symbolNodeMap != null) result.symbolNodeMap.addEntries(symbolNodeMap);
    if (fullyQualifiedNameMap != null)
      result.fullyQualifiedNameMap.addEntries(fullyQualifiedNameMap);
    if (pkgScopeMap != null) result.pkgScopeMap.addEntries(pkgScopeMap);
    if (imports != null) result.imports.addEntries(imports);
    if (kclMod != null) result.kclMod = kclMod;
    if (apps != null) result.apps.addAll(apps);
    return result;
  }

  LoadPackageResult._();

  factory LoadPackageResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LoadPackageResult()..mergeFromBuffer(data, registry);
  factory LoadPackageResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LoadPackageResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoadPackageResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: LoadPackageResult.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'program')
    ..pPS(2, _omitFieldNames ? '' : 'paths')
    ..pPM<Error>(3, _omitFieldNames ? '' : 'parseErrors',
        subBuilder: Error.$_createMessage)
    ..pPM<Error>(4, _omitFieldNames ? '' : 'typeErrors',
        subBuilder: Error.$_createMessage)
    ..m<$core.String, Scope>(5, _omitFieldNames ? '' : 'scopes',
        entryClassName: 'LoadPackageResult.ScopesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Scope.$_createMessage,
        valueDefaultOrMaker: Scope.getDefault,
        packageName: const $pb.PackageName('com.kcl.api'))
    ..m<$core.String, Symbol>(6, _omitFieldNames ? '' : 'symbols',
        entryClassName: 'LoadPackageResult.SymbolsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Symbol.$_createMessage,
        valueDefaultOrMaker: Symbol.getDefault,
        packageName: const $pb.PackageName('com.kcl.api'))
    ..m<$core.String, SymbolIndex>(7, _omitFieldNames ? '' : 'nodeSymbolMap',
        entryClassName: 'LoadPackageResult.NodeSymbolMapEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: SymbolIndex.$_createMessage,
        valueDefaultOrMaker: SymbolIndex.getDefault,
        packageName: const $pb.PackageName('com.kcl.api'))
    ..m<$core.String, $core.String>(8, _omitFieldNames ? '' : 'symbolNodeMap',
        entryClassName: 'LoadPackageResult.SymbolNodeMapEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('com.kcl.api'))
    ..m<$core.String, SymbolIndex>(
        9, _omitFieldNames ? '' : 'fullyQualifiedNameMap',
        entryClassName: 'LoadPackageResult.FullyQualifiedNameMapEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: SymbolIndex.$_createMessage,
        valueDefaultOrMaker: SymbolIndex.getDefault,
        packageName: const $pb.PackageName('com.kcl.api'))
    ..m<$core.String, ScopeIndex>(10, _omitFieldNames ? '' : 'pkgScopeMap',
        entryClassName: 'LoadPackageResult.PkgScopeMapEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: ScopeIndex.$_createMessage,
        valueDefaultOrMaker: ScopeIndex.getDefault,
        packageName: const $pb.PackageName('com.kcl.api'))
    ..m<$core.String, FileImports>(11, _omitFieldNames ? '' : 'imports',
        entryClassName: 'LoadPackageResult.ImportsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: FileImports.$_createMessage,
        valueDefaultOrMaker: FileImports.getDefault,
        packageName: const $pb.PackageName('com.kcl.api'))
    ..aOM<KclMod>(12, _omitFieldNames ? '' : 'kclMod',
        subBuilder: KclMod.$_createMessage)
    ..pPM<AppInfo>(13, _omitFieldNames ? '' : 'apps',
        subBuilder: AppInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadPackageResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadPackageResult copyWith(void Function(LoadPackageResult) updates) =>
      super.copyWith((message) => updates(message as LoadPackageResult))
          as LoadPackageResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LoadPackageResult() / LoadPackageResult.new instead')
  static LoadPackageResult create() => LoadPackageResult._();
  static $pb.GeneratedMessage $_createMessage() => LoadPackageResult._();
  @$core.override
  LoadPackageResult createEmptyInstance() => LoadPackageResult._();
  @$core.pragma('dart2js:noInline')
  static LoadPackageResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LoadPackageResult>(
          LoadPackageResult.$_createMessage);
  static LoadPackageResult? _defaultInstance;

  /// Program Abstract Syntax Tree (AST) in JSON format.
  @$pb.TagNumber(1)
  $core.String get program => $_getSZ(0);
  @$pb.TagNumber(1)
  set program($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProgram() => $_has(0);
  @$pb.TagNumber(1)
  void clearProgram() => $_clearField(1);

  /// Returns the files in the order they should be compiled.
  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get paths => $_getList(1);

  /// List of parse errors.
  @$pb.TagNumber(3)
  $pb.PbList<Error> get parseErrors => $_getList(2);

  /// List of type errors.
  @$pb.TagNumber(4)
  $pb.PbList<Error> get typeErrors => $_getList(3);

  /// Map of scopes with scope index as key.
  @$pb.TagNumber(5)
  $pb.PbMap<$core.String, Scope> get scopes => $_getMap(4);

  /// Map of symbols with symbol index as key.
  @$pb.TagNumber(6)
  $pb.PbMap<$core.String, Symbol> get symbols => $_getMap(5);

  /// Map of node-symbol associations with AST index UUID as key.
  @$pb.TagNumber(7)
  $pb.PbMap<$core.String, SymbolIndex> get nodeSymbolMap => $_getMap(6);

  /// Map of symbol-node associations with symbol index as key.
  @$pb.TagNumber(8)
  $pb.PbMap<$core.String, $core.String> get symbolNodeMap => $_getMap(7);

  /// Map of fully qualified names with symbol index as key.
  @$pb.TagNumber(9)
  $pb.PbMap<$core.String, SymbolIndex> get fullyQualifiedNameMap => $_getMap(8);

  /// Map of package scope with package path as key.
  @$pb.TagNumber(10)
  $pb.PbMap<$core.String, ScopeIndex> get pkgScopeMap => $_getMap(9);

  /// Map of direct imports, keyed by the importing file's absolute path.
  /// `path` is the import specifier as written in the source; `resolved` is
  /// the resolved absolute file path (empty for builtins/unresolved imports).
  /// Upstream files = transitive closure; downstream = reverse closure; this
  /// replaces the removed ListDep* RPCs.
  @$pb.TagNumber(11)
  $pb.PbMap<$core.String, FileImports> get imports => $_getMap(10);

  /// Parsed kcl.mod manifest of the package root. Empty when the root has no
  /// kcl.mod.
  @$pb.TagNumber(12)
  KclMod get kclMod => $_getN(11);
  @$pb.TagNumber(12)
  set kclMod(KclMod value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasKclMod() => $_has(11);
  @$pb.TagNumber(12)
  void clearKclMod() => $_clearField(12);
  @$pb.TagNumber(12)
  KclMod ensureKclMod() => $_ensure(11);

  /// Application directories discovered under the package root: every
  /// directory that directly contains at least one .k file. Sorted by path.
  @$pb.TagNumber(13)
  $pb.PbList<AppInfo> get apps => $_getList(12);
}

/// Message representing the direct imports of a single file.
class FileImports extends $pb.GeneratedMessage {
  factory FileImports({
    $core.Iterable<ImportInfo>? imports,
  }) {
    final result = FileImports._();
    if (imports != null) result.imports.addAll(imports);
    return result;
  }

  FileImports._();

  factory FileImports.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FileImports()..mergeFromBuffer(data, registry);
  factory FileImports.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FileImports()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FileImports',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: FileImports.$_createMessage)
    ..pPM<ImportInfo>(1, _omitFieldNames ? '' : 'imports',
        subBuilder: ImportInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FileImports clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FileImports copyWith(void Function(FileImports) updates) =>
      super.copyWith((message) => updates(message as FileImports))
          as FileImports;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FileImports() / FileImports.new instead')
  static FileImports create() => FileImports._();
  static $pb.GeneratedMessage $_createMessage() => FileImports._();
  @$core.override
  FileImports createEmptyInstance() => FileImports._();
  @$core.pragma('dart2js:noInline')
  static FileImports getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FileImports>(
          FileImports.$_createMessage);
  static FileImports? _defaultInstance;

  /// List of direct imports of the file.
  @$pb.TagNumber(1)
  $pb.PbList<ImportInfo> get imports => $_getList(0);
}

/// Message representing a single direct import of a file.
class ImportInfo extends $pb.GeneratedMessage {
  factory ImportInfo({
    $core.String? path,
    $core.String? resolved,
  }) {
    final result = ImportInfo._();
    if (path != null) result.path = path;
    if (resolved != null) result.resolved = resolved;
    return result;
  }

  ImportInfo._();

  factory ImportInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImportInfo()..mergeFromBuffer(data, registry);
  factory ImportInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImportInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImportInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: ImportInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOS(2, _omitFieldNames ? '' : 'resolved')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportInfo copyWith(void Function(ImportInfo) updates) =>
      super.copyWith((message) => updates(message as ImportInfo)) as ImportInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ImportInfo() / ImportInfo.new instead')
  static ImportInfo create() => ImportInfo._();
  static $pb.GeneratedMessage $_createMessage() => ImportInfo._();
  @$core.override
  ImportInfo createEmptyInstance() => ImportInfo._();
  @$core.pragma('dart2js:noInline')
  static ImportInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ImportInfo>(ImportInfo.$_createMessage);
  static ImportInfo? _defaultInstance;

  /// Import specifier as written in the source.
  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  /// Resolved absolute file path of the import.
  @$pb.TagNumber(2)
  $core.String get resolved => $_getSZ(1);
  @$pb.TagNumber(2)
  set resolved($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasResolved() => $_has(1);
  @$pb.TagNumber(2)
  void clearResolved() => $_clearField(2);
}

/// Message representing a parsed kcl.mod manifest.
class KclMod extends $pb.GeneratedMessage {
  factory KclMod({
    KclModPackage? package,
    KclModProfile? profile,
    $core.Iterable<$core.MapEntry<$core.String, KclModDependency>>?
        dependencies,
  }) {
    final result = KclMod._();
    if (package != null) result.package = package;
    if (profile != null) result.profile = profile;
    if (dependencies != null) result.dependencies.addEntries(dependencies);
    return result;
  }

  KclMod._();

  factory KclMod.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KclMod()..mergeFromBuffer(data, registry);
  factory KclMod.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KclMod()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KclMod',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: KclMod.$_createMessage)
    ..aOM<KclModPackage>(1, _omitFieldNames ? '' : 'package',
        subBuilder: KclModPackage.$_createMessage)
    ..aOM<KclModProfile>(2, _omitFieldNames ? '' : 'profile',
        subBuilder: KclModProfile.$_createMessage)
    ..m<$core.String, KclModDependency>(
        3, _omitFieldNames ? '' : 'dependencies',
        entryClassName: 'KclMod.DependenciesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: KclModDependency.$_createMessage,
        valueDefaultOrMaker: KclModDependency.getDefault,
        packageName: const $pb.PackageName('com.kcl.api'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KclMod clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KclMod copyWith(void Function(KclMod) updates) =>
      super.copyWith((message) => updates(message as KclMod)) as KclMod;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use KclMod() / KclMod.new instead')
  static KclMod create() => KclMod._();
  static $pb.GeneratedMessage $_createMessage() => KclMod._();
  @$core.override
  KclMod createEmptyInstance() => KclMod._();
  @$core.pragma('dart2js:noInline')
  static KclMod getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<KclMod>(KclMod.$_createMessage);
  static KclMod? _defaultInstance;

  /// Package section of the manifest.
  @$pb.TagNumber(1)
  KclModPackage get package => $_getN(0);
  @$pb.TagNumber(1)
  set package(KclModPackage value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPackage() => $_has(0);
  @$pb.TagNumber(1)
  void clearPackage() => $_clearField(1);
  @$pb.TagNumber(1)
  KclModPackage ensurePackage() => $_ensure(0);

  /// Profile section of the manifest.
  @$pb.TagNumber(2)
  KclModProfile get profile => $_getN(1);
  @$pb.TagNumber(2)
  set profile(KclModProfile value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasProfile() => $_has(1);
  @$pb.TagNumber(2)
  void clearProfile() => $_clearField(2);
  @$pb.TagNumber(2)
  KclModProfile ensureProfile() => $_ensure(1);

  /// Mirrors the untagged toml dependency: exactly one of version/git/oci/local is set.
  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, KclModDependency> get dependencies => $_getMap(2);
}

/// Message representing the package section of a kcl.mod manifest.
class KclModPackage extends $pb.GeneratedMessage {
  factory KclModPackage({
    $core.String? name,
    $core.String? edition,
    $core.String? version,
    $core.String? description,
    $core.Iterable<$core.String>? include,
    $core.Iterable<$core.String>? exclude,
  }) {
    final result = KclModPackage._();
    if (name != null) result.name = name;
    if (edition != null) result.edition = edition;
    if (version != null) result.version = version;
    if (description != null) result.description = description;
    if (include != null) result.include.addAll(include);
    if (exclude != null) result.exclude.addAll(exclude);
    return result;
  }

  KclModPackage._();

  factory KclModPackage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KclModPackage()..mergeFromBuffer(data, registry);
  factory KclModPackage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KclModPackage()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KclModPackage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: KclModPackage.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'edition')
    ..aOS(3, _omitFieldNames ? '' : 'version')
    ..aOS(4, _omitFieldNames ? '' : 'description')
    ..pPS(5, _omitFieldNames ? '' : 'include')
    ..pPS(6, _omitFieldNames ? '' : 'exclude')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KclModPackage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KclModPackage copyWith(void Function(KclModPackage) updates) =>
      super.copyWith((message) => updates(message as KclModPackage))
          as KclModPackage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use KclModPackage() / KclModPackage.new instead')
  static KclModPackage create() => KclModPackage._();
  static $pb.GeneratedMessage $_createMessage() => KclModPackage._();
  @$core.override
  KclModPackage createEmptyInstance() => KclModPackage._();
  @$core.pragma('dart2js:noInline')
  static KclModPackage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KclModPackage>(
          KclModPackage.$_createMessage);
  static KclModPackage? _defaultInstance;

  /// Name of the package.
  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  /// KCL compiler edition of the package.
  @$pb.TagNumber(2)
  $core.String get edition => $_getSZ(1);
  @$pb.TagNumber(2)
  set edition($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEdition() => $_has(1);
  @$pb.TagNumber(2)
  void clearEdition() => $_clearField(2);

  /// Version of the package.
  @$pb.TagNumber(3)
  $core.String get version => $_getSZ(2);
  @$pb.TagNumber(3)
  set version($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearVersion() => $_clearField(3);

  /// Description of the package.
  @$pb.TagNumber(4)
  $core.String get description => $_getSZ(3);
  @$pb.TagNumber(4)
  set description($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDescription() => $_has(3);
  @$pb.TagNumber(4)
  void clearDescription() => $_clearField(4);

  /// Files to include when publishing.
  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get include => $_getList(4);

  /// Files to exclude when publishing.
  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get exclude => $_getList(5);
}

/// Message representing the profile section of a kcl.mod manifest.
class KclModProfile extends $pb.GeneratedMessage {
  factory KclModProfile({
    $core.Iterable<$core.String>? entries,
    $core.bool? disableNone,
    $core.bool? sortKeys,
    $core.Iterable<$core.String>? selectors,
    $core.Iterable<$core.String>? overrides,
    $core.Iterable<$core.String>? options,
  }) {
    final result = KclModProfile._();
    if (entries != null) result.entries.addAll(entries);
    if (disableNone != null) result.disableNone = disableNone;
    if (sortKeys != null) result.sortKeys = sortKeys;
    if (selectors != null) result.selectors.addAll(selectors);
    if (overrides != null) result.overrides.addAll(overrides);
    if (options != null) result.options.addAll(options);
    return result;
  }

  KclModProfile._();

  factory KclModProfile.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KclModProfile()..mergeFromBuffer(data, registry);
  factory KclModProfile.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KclModProfile()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KclModProfile',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: KclModProfile.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'entries')
    ..aOB(2, _omitFieldNames ? '' : 'disableNone')
    ..aOB(3, _omitFieldNames ? '' : 'sortKeys')
    ..pPS(4, _omitFieldNames ? '' : 'selectors')
    ..pPS(5, _omitFieldNames ? '' : 'overrides')
    ..pPS(6, _omitFieldNames ? '' : 'options')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KclModProfile clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KclModProfile copyWith(void Function(KclModProfile) updates) =>
      super.copyWith((message) => updates(message as KclModProfile))
          as KclModProfile;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use KclModProfile() / KclModProfile.new instead')
  static KclModProfile create() => KclModProfile._();
  static $pb.GeneratedMessage $_createMessage() => KclModProfile._();
  @$core.override
  KclModProfile createEmptyInstance() => KclModProfile._();
  @$core.pragma('dart2js:noInline')
  static KclModProfile getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KclModProfile>(
          KclModProfile.$_createMessage);
  static KclModProfile? _defaultInstance;

  /// List of entry-point files.
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get entries => $_getList(0);

  /// Flag that, when true, disables the emission of the special 'none' value in the output.
  @$pb.TagNumber(2)
  $core.bool get disableNone => $_getBF(1);
  @$pb.TagNumber(2)
  set disableNone($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDisableNone() => $_has(1);
  @$pb.TagNumber(2)
  void clearDisableNone() => $_clearField(2);

  /// Flag that, when true, ensures keys in maps are sorted.
  @$pb.TagNumber(3)
  $core.bool get sortKeys => $_getBF(2);
  @$pb.TagNumber(3)
  set sortKeys($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSortKeys() => $_has(2);
  @$pb.TagNumber(3)
  void clearSortKeys() => $_clearField(3);

  /// List of attribute selectors for conditional compilation.
  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get selectors => $_getList(3);

  /// List of override paths.
  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get overrides => $_getList(4);

  /// List of additional options for the KCL compiler.
  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get options => $_getList(5);
}

/// Message representing a single dependency of a kcl.mod manifest.
class KclModDependency extends $pb.GeneratedMessage {
  factory KclModDependency({
    $core.String? version,
    KclModGitSource? git,
    KclModOciSource? oci,
    KclModLocalSource? local,
  }) {
    final result = KclModDependency._();
    if (version != null) result.version = version;
    if (git != null) result.git = git;
    if (oci != null) result.oci = oci;
    if (local != null) result.local = local;
    return result;
  }

  KclModDependency._();

  factory KclModDependency.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KclModDependency()..mergeFromBuffer(data, registry);
  factory KclModDependency.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KclModDependency()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KclModDependency',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: KclModDependency.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'version')
    ..aOM<KclModGitSource>(2, _omitFieldNames ? '' : 'git',
        subBuilder: KclModGitSource.$_createMessage)
    ..aOM<KclModOciSource>(3, _omitFieldNames ? '' : 'oci',
        subBuilder: KclModOciSource.$_createMessage)
    ..aOM<KclModLocalSource>(4, _omitFieldNames ? '' : 'local',
        subBuilder: KclModLocalSource.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KclModDependency clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KclModDependency copyWith(void Function(KclModDependency) updates) =>
      super.copyWith((message) => updates(message as KclModDependency))
          as KclModDependency;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use KclModDependency() / KclModDependency.new instead')
  static KclModDependency create() => KclModDependency._();
  static $pb.GeneratedMessage $_createMessage() => KclModDependency._();
  @$core.override
  KclModDependency createEmptyInstance() => KclModDependency._();
  @$core.pragma('dart2js:noInline')
  static KclModDependency getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KclModDependency>(
          KclModDependency.$_createMessage);
  static KclModDependency? _defaultInstance;

  /// Version of the dependency, e.g. "1.0.0".
  @$pb.TagNumber(1)
  $core.String get version => $_getSZ(0);
  @$pb.TagNumber(1)
  set version($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => $_clearField(1);

  /// Git source of the dependency.
  @$pb.TagNumber(2)
  KclModGitSource get git => $_getN(1);
  @$pb.TagNumber(2)
  set git(KclModGitSource value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasGit() => $_has(1);
  @$pb.TagNumber(2)
  void clearGit() => $_clearField(2);
  @$pb.TagNumber(2)
  KclModGitSource ensureGit() => $_ensure(1);

  /// OCI source of the dependency.
  @$pb.TagNumber(3)
  KclModOciSource get oci => $_getN(2);
  @$pb.TagNumber(3)
  set oci(KclModOciSource value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasOci() => $_has(2);
  @$pb.TagNumber(3)
  void clearOci() => $_clearField(3);
  @$pb.TagNumber(3)
  KclModOciSource ensureOci() => $_ensure(2);

  /// Local path source of the dependency.
  @$pb.TagNumber(4)
  KclModLocalSource get local => $_getN(3);
  @$pb.TagNumber(4)
  set local(KclModLocalSource value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasLocal() => $_has(3);
  @$pb.TagNumber(4)
  void clearLocal() => $_clearField(4);
  @$pb.TagNumber(4)
  KclModLocalSource ensureLocal() => $_ensure(3);
}

/// Message representing a Git source of a kcl.mod dependency.
class KclModGitSource extends $pb.GeneratedMessage {
  factory KclModGitSource({
    $core.String? git,
    $core.String? branch,
    $core.String? commit,
    $core.String? tag,
    $core.String? version,
  }) {
    final result = KclModGitSource._();
    if (git != null) result.git = git;
    if (branch != null) result.branch = branch;
    if (commit != null) result.commit = commit;
    if (tag != null) result.tag = tag;
    if (version != null) result.version = version;
    return result;
  }

  KclModGitSource._();

  factory KclModGitSource.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KclModGitSource()..mergeFromBuffer(data, registry);
  factory KclModGitSource.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KclModGitSource()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KclModGitSource',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: KclModGitSource.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'git')
    ..aOS(2, _omitFieldNames ? '' : 'branch')
    ..aOS(3, _omitFieldNames ? '' : 'commit')
    ..aOS(4, _omitFieldNames ? '' : 'tag')
    ..aOS(5, _omitFieldNames ? '' : 'version')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KclModGitSource clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KclModGitSource copyWith(void Function(KclModGitSource) updates) =>
      super.copyWith((message) => updates(message as KclModGitSource))
          as KclModGitSource;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use KclModGitSource() / KclModGitSource.new instead')
  static KclModGitSource create() => KclModGitSource._();
  static $pb.GeneratedMessage $_createMessage() => KclModGitSource._();
  @$core.override
  KclModGitSource createEmptyInstance() => KclModGitSource._();
  @$core.pragma('dart2js:noInline')
  static KclModGitSource getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KclModGitSource>(
          KclModGitSource.$_createMessage);
  static KclModGitSource? _defaultInstance;

  /// URL of the Git repository.
  @$pb.TagNumber(1)
  $core.String get git => $_getSZ(0);
  @$pb.TagNumber(1)
  set git($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGit() => $_has(0);
  @$pb.TagNumber(1)
  void clearGit() => $_clearField(1);

  /// Optional branch name within the Git repository.
  @$pb.TagNumber(2)
  $core.String get branch => $_getSZ(1);
  @$pb.TagNumber(2)
  set branch($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBranch() => $_has(1);
  @$pb.TagNumber(2)
  void clearBranch() => $_clearField(2);

  /// Optional commit hash to check out from the Git repository.
  @$pb.TagNumber(3)
  $core.String get commit => $_getSZ(2);
  @$pb.TagNumber(3)
  set commit($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCommit() => $_has(2);
  @$pb.TagNumber(3)
  void clearCommit() => $_clearField(3);

  /// Optional tag name to check out from the Git repository.
  @$pb.TagNumber(4)
  $core.String get tag => $_getSZ(3);
  @$pb.TagNumber(4)
  set tag($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTag() => $_has(3);
  @$pb.TagNumber(4)
  void clearTag() => $_clearField(4);

  /// Optional version specification associated with the Git source.
  @$pb.TagNumber(5)
  $core.String get version => $_getSZ(4);
  @$pb.TagNumber(5)
  set version($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasVersion() => $_has(4);
  @$pb.TagNumber(5)
  void clearVersion() => $_clearField(5);
}

/// Message representing an OCI source of a kcl.mod dependency.
class KclModOciSource extends $pb.GeneratedMessage {
  factory KclModOciSource({
    $core.String? oci,
    $core.String? tag,
  }) {
    final result = KclModOciSource._();
    if (oci != null) result.oci = oci;
    if (tag != null) result.tag = tag;
    return result;
  }

  KclModOciSource._();

  factory KclModOciSource.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KclModOciSource()..mergeFromBuffer(data, registry);
  factory KclModOciSource.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KclModOciSource()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KclModOciSource',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: KclModOciSource.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'oci')
    ..aOS(2, _omitFieldNames ? '' : 'tag')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KclModOciSource clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KclModOciSource copyWith(void Function(KclModOciSource) updates) =>
      super.copyWith((message) => updates(message as KclModOciSource))
          as KclModOciSource;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use KclModOciSource() / KclModOciSource.new instead')
  static KclModOciSource create() => KclModOciSource._();
  static $pb.GeneratedMessage $_createMessage() => KclModOciSource._();
  @$core.override
  KclModOciSource createEmptyInstance() => KclModOciSource._();
  @$core.pragma('dart2js:noInline')
  static KclModOciSource getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KclModOciSource>(
          KclModOciSource.$_createMessage);
  static KclModOciSource? _defaultInstance;

  /// URI of the OCI repository.
  @$pb.TagNumber(1)
  $core.String get oci => $_getSZ(0);
  @$pb.TagNumber(1)
  set oci($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOci() => $_has(0);
  @$pb.TagNumber(1)
  void clearOci() => $_clearField(1);

  /// Optional tag of the OCI package in the registry.
  @$pb.TagNumber(2)
  $core.String get tag => $_getSZ(1);
  @$pb.TagNumber(2)
  set tag($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTag() => $_has(1);
  @$pb.TagNumber(2)
  void clearTag() => $_clearField(2);
}

/// Message representing a local path source of a kcl.mod dependency.
class KclModLocalSource extends $pb.GeneratedMessage {
  factory KclModLocalSource({
    $core.String? path,
  }) {
    final result = KclModLocalSource._();
    if (path != null) result.path = path;
    return result;
  }

  KclModLocalSource._();

  factory KclModLocalSource.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KclModLocalSource()..mergeFromBuffer(data, registry);
  factory KclModLocalSource.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KclModLocalSource()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KclModLocalSource',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: KclModLocalSource.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KclModLocalSource clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KclModLocalSource copyWith(void Function(KclModLocalSource) updates) =>
      super.copyWith((message) => updates(message as KclModLocalSource))
          as KclModLocalSource;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use KclModLocalSource() / KclModLocalSource.new instead')
  static KclModLocalSource create() => KclModLocalSource._();
  static $pb.GeneratedMessage $_createMessage() => KclModLocalSource._();
  @$core.override
  KclModLocalSource createEmptyInstance() => KclModLocalSource._();
  @$core.pragma('dart2js:noInline')
  static KclModLocalSource getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KclModLocalSource>(
          KclModLocalSource.$_createMessage);
  static KclModLocalSource? _defaultInstance;

  /// Path to the local directory or file.
  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);
}

/// Message representing an application directory discovered under a package root.
class AppInfo extends $pb.GeneratedMessage {
  factory AppInfo({
    $core.String? path,
    $core.bool? hasKclMod,
  }) {
    final result = AppInfo._();
    if (path != null) result.path = path;
    if (hasKclMod != null) result.hasKclMod = hasKclMod;
    return result;
  }

  AppInfo._();

  factory AppInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AppInfo()..mergeFromBuffer(data, registry);
  factory AppInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AppInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AppInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: AppInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOB(2, _omitFieldNames ? '' : 'hasKclMod')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppInfo copyWith(void Function(AppInfo) updates) =>
      super.copyWith((message) => updates(message as AppInfo)) as AppInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AppInfo() / AppInfo.new instead')
  static AppInfo create() => AppInfo._();
  static $pb.GeneratedMessage $_createMessage() => AppInfo._();
  @$core.override
  AppInfo createEmptyInstance() => AppInfo._();
  @$core.pragma('dart2js:noInline')
  static AppInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AppInfo>(AppInfo.$_createMessage);
  static AppInfo? _defaultInstance;

  /// Absolute path of the application directory.
  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  /// True when the directory contains a kcl.mod manifest.
  @$pb.TagNumber(2)
  $core.bool get hasKclMod => $_getBF(1);
  @$pb.TagNumber(2)
  set hasKclMod($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHasKclMod() => $_has(1);
  @$pb.TagNumber(2)
  void clearHasKclMod() => $_clearField(2);
}

/// Message for list options response.
class ListOptionsResult extends $pb.GeneratedMessage {
  factory ListOptionsResult({
    $core.Iterable<OptionHelp>? options,
  }) {
    final result = ListOptionsResult._();
    if (options != null) result.options.addAll(options);
    return result;
  }

  ListOptionsResult._();

  factory ListOptionsResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListOptionsResult()..mergeFromBuffer(data, registry);
  factory ListOptionsResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListOptionsResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListOptionsResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: ListOptionsResult.$_createMessage)
    ..pPM<OptionHelp>(2, _omitFieldNames ? '' : 'options',
        subBuilder: OptionHelp.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListOptionsResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListOptionsResult copyWith(void Function(ListOptionsResult) updates) =>
      super.copyWith((message) => updates(message as ListOptionsResult))
          as ListOptionsResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListOptionsResult() / ListOptionsResult.new instead')
  static ListOptionsResult create() => ListOptionsResult._();
  static $pb.GeneratedMessage $_createMessage() => ListOptionsResult._();
  @$core.override
  ListOptionsResult createEmptyInstance() => ListOptionsResult._();
  @$core.pragma('dart2js:noInline')
  static ListOptionsResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListOptionsResult>(
          ListOptionsResult.$_createMessage);
  static ListOptionsResult? _defaultInstance;

  /// List of available options.
  @$pb.TagNumber(2)
  $pb.PbList<OptionHelp> get options => $_getList(0);
}

/// Message representing a help option.
class OptionHelp extends $pb.GeneratedMessage {
  factory OptionHelp({
    $core.String? name,
    $core.String? type,
    $core.bool? required,
    $core.String? defaultValue,
    $core.String? help,
  }) {
    final result = OptionHelp._();
    if (name != null) result.name = name;
    if (type != null) result.type = type;
    if (required != null) result.required = required;
    if (defaultValue != null) result.defaultValue = defaultValue;
    if (help != null) result.help = help;
    return result;
  }

  OptionHelp._();

  factory OptionHelp.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OptionHelp()..mergeFromBuffer(data, registry);
  factory OptionHelp.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OptionHelp()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OptionHelp',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: OptionHelp.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'type')
    ..aOB(3, _omitFieldNames ? '' : 'required')
    ..aOS(4, _omitFieldNames ? '' : 'defaultValue')
    ..aOS(5, _omitFieldNames ? '' : 'help')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OptionHelp clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OptionHelp copyWith(void Function(OptionHelp) updates) =>
      super.copyWith((message) => updates(message as OptionHelp)) as OptionHelp;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use OptionHelp() / OptionHelp.new instead')
  static OptionHelp create() => OptionHelp._();
  static $pb.GeneratedMessage $_createMessage() => OptionHelp._();
  @$core.override
  OptionHelp createEmptyInstance() => OptionHelp._();
  @$core.pragma('dart2js:noInline')
  static OptionHelp getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OptionHelp>(OptionHelp.$_createMessage);
  static OptionHelp? _defaultInstance;

  /// Name of the option.
  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  /// Type of the option.
  @$pb.TagNumber(2)
  $core.String get type => $_getSZ(1);
  @$pb.TagNumber(2)
  set type($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => $_clearField(2);

  /// Flag indicating if the option is required.
  @$pb.TagNumber(3)
  $core.bool get required => $_getBF(2);
  @$pb.TagNumber(3)
  set required($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRequired() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequired() => $_clearField(3);

  /// Default value of the option.
  @$pb.TagNumber(4)
  $core.String get defaultValue => $_getSZ(3);
  @$pb.TagNumber(4)
  set defaultValue($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDefaultValue() => $_has(3);
  @$pb.TagNumber(4)
  void clearDefaultValue() => $_clearField(4);

  /// Help text for the option.
  @$pb.TagNumber(5)
  $core.String get help => $_getSZ(4);
  @$pb.TagNumber(5)
  set help($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasHelp() => $_has(4);
  @$pb.TagNumber(5)
  void clearHelp() => $_clearField(5);
}

/// Message representing a symbol in KCL.
class Symbol extends $pb.GeneratedMessage {
  factory Symbol({
    KclType? ty,
    $core.String? name,
    SymbolIndex? owner,
    SymbolIndex? def,
    $core.Iterable<SymbolIndex>? attrs,
    $core.bool? isGlobal,
  }) {
    final result = Symbol._();
    if (ty != null) result.ty = ty;
    if (name != null) result.name = name;
    if (owner != null) result.owner = owner;
    if (def != null) result.def = def;
    if (attrs != null) result.attrs.addAll(attrs);
    if (isGlobal != null) result.isGlobal = isGlobal;
    return result;
  }

  Symbol._();

  factory Symbol.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Symbol()..mergeFromBuffer(data, registry);
  factory Symbol.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Symbol()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Symbol',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: Symbol.$_createMessage)
    ..aOM<KclType>(1, _omitFieldNames ? '' : 'ty',
        subBuilder: KclType.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOM<SymbolIndex>(3, _omitFieldNames ? '' : 'owner',
        subBuilder: SymbolIndex.$_createMessage)
    ..aOM<SymbolIndex>(4, _omitFieldNames ? '' : 'def',
        subBuilder: SymbolIndex.$_createMessage)
    ..pPM<SymbolIndex>(5, _omitFieldNames ? '' : 'attrs',
        subBuilder: SymbolIndex.$_createMessage)
    ..aOB(6, _omitFieldNames ? '' : 'isGlobal')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Symbol clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Symbol copyWith(void Function(Symbol) updates) =>
      super.copyWith((message) => updates(message as Symbol)) as Symbol;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Symbol() / Symbol.new instead')
  static Symbol create() => Symbol._();
  static $pb.GeneratedMessage $_createMessage() => Symbol._();
  @$core.override
  Symbol createEmptyInstance() => Symbol._();
  @$core.pragma('dart2js:noInline')
  static Symbol getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Symbol>(Symbol.$_createMessage);
  static Symbol? _defaultInstance;

  /// Type of the symbol.
  @$pb.TagNumber(1)
  KclType get ty => $_getN(0);
  @$pb.TagNumber(1)
  set ty(KclType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTy() => $_has(0);
  @$pb.TagNumber(1)
  void clearTy() => $_clearField(1);
  @$pb.TagNumber(1)
  KclType ensureTy() => $_ensure(0);

  /// Name of the symbol.
  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  /// Owner of the symbol.
  @$pb.TagNumber(3)
  SymbolIndex get owner => $_getN(2);
  @$pb.TagNumber(3)
  set owner(SymbolIndex value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasOwner() => $_has(2);
  @$pb.TagNumber(3)
  void clearOwner() => $_clearField(3);
  @$pb.TagNumber(3)
  SymbolIndex ensureOwner() => $_ensure(2);

  /// Definition of the symbol.
  @$pb.TagNumber(4)
  SymbolIndex get def => $_getN(3);
  @$pb.TagNumber(4)
  set def(SymbolIndex value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasDef() => $_has(3);
  @$pb.TagNumber(4)
  void clearDef() => $_clearField(4);
  @$pb.TagNumber(4)
  SymbolIndex ensureDef() => $_ensure(3);

  /// Attributes of the symbol.
  @$pb.TagNumber(5)
  $pb.PbList<SymbolIndex> get attrs => $_getList(4);

  /// Flag indicating if the symbol is global.
  @$pb.TagNumber(6)
  $core.bool get isGlobal => $_getBF(5);
  @$pb.TagNumber(6)
  set isGlobal($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIsGlobal() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsGlobal() => $_clearField(6);
}

/// Message representing a scope in KCL.
class Scope extends $pb.GeneratedMessage {
  factory Scope({
    $core.String? kind,
    ScopeIndex? parent,
    SymbolIndex? owner,
    $core.Iterable<ScopeIndex>? children,
    $core.Iterable<SymbolIndex>? defs,
  }) {
    final result = Scope._();
    if (kind != null) result.kind = kind;
    if (parent != null) result.parent = parent;
    if (owner != null) result.owner = owner;
    if (children != null) result.children.addAll(children);
    if (defs != null) result.defs.addAll(defs);
    return result;
  }

  Scope._();

  factory Scope.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Scope()..mergeFromBuffer(data, registry);
  factory Scope.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Scope()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Scope',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: Scope.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'kind')
    ..aOM<ScopeIndex>(2, _omitFieldNames ? '' : 'parent',
        subBuilder: ScopeIndex.$_createMessage)
    ..aOM<SymbolIndex>(3, _omitFieldNames ? '' : 'owner',
        subBuilder: SymbolIndex.$_createMessage)
    ..pPM<ScopeIndex>(4, _omitFieldNames ? '' : 'children',
        subBuilder: ScopeIndex.$_createMessage)
    ..pPM<SymbolIndex>(5, _omitFieldNames ? '' : 'defs',
        subBuilder: SymbolIndex.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Scope clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Scope copyWith(void Function(Scope) updates) =>
      super.copyWith((message) => updates(message as Scope)) as Scope;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Scope() / Scope.new instead')
  static Scope create() => Scope._();
  static $pb.GeneratedMessage $_createMessage() => Scope._();
  @$core.override
  Scope createEmptyInstance() => Scope._();
  @$core.pragma('dart2js:noInline')
  static Scope getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Scope>(Scope.$_createMessage);
  static Scope? _defaultInstance;

  /// Type of the scope.
  @$pb.TagNumber(1)
  $core.String get kind => $_getSZ(0);
  @$pb.TagNumber(1)
  set kind($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => $_clearField(1);

  /// Parent scope.
  @$pb.TagNumber(2)
  ScopeIndex get parent => $_getN(1);
  @$pb.TagNumber(2)
  set parent(ScopeIndex value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasParent() => $_has(1);
  @$pb.TagNumber(2)
  void clearParent() => $_clearField(2);
  @$pb.TagNumber(2)
  ScopeIndex ensureParent() => $_ensure(1);

  /// Owner of the scope.
  @$pb.TagNumber(3)
  SymbolIndex get owner => $_getN(2);
  @$pb.TagNumber(3)
  set owner(SymbolIndex value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasOwner() => $_has(2);
  @$pb.TagNumber(3)
  void clearOwner() => $_clearField(3);
  @$pb.TagNumber(3)
  SymbolIndex ensureOwner() => $_ensure(2);

  /// Children of the scope.
  @$pb.TagNumber(4)
  $pb.PbList<ScopeIndex> get children => $_getList(3);

  /// Definitions in the scope.
  @$pb.TagNumber(5)
  $pb.PbList<SymbolIndex> get defs => $_getList(4);
}

/// Message representing a symbol index.
class SymbolIndex extends $pb.GeneratedMessage {
  factory SymbolIndex({
    $fixnum.Int64? i,
    $fixnum.Int64? g,
    $core.String? kind,
  }) {
    final result = SymbolIndex._();
    if (i != null) result.i = i;
    if (g != null) result.g = g;
    if (kind != null) result.kind = kind;
    return result;
  }

  SymbolIndex._();

  factory SymbolIndex.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SymbolIndex()..mergeFromBuffer(data, registry);
  factory SymbolIndex.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SymbolIndex()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SymbolIndex',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: SymbolIndex.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'i', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'g', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(3, _omitFieldNames ? '' : 'kind')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SymbolIndex clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SymbolIndex copyWith(void Function(SymbolIndex) updates) =>
      super.copyWith((message) => updates(message as SymbolIndex))
          as SymbolIndex;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SymbolIndex() / SymbolIndex.new instead')
  static SymbolIndex create() => SymbolIndex._();
  static $pb.GeneratedMessage $_createMessage() => SymbolIndex._();
  @$core.override
  SymbolIndex createEmptyInstance() => SymbolIndex._();
  @$core.pragma('dart2js:noInline')
  static SymbolIndex getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SymbolIndex>(
          SymbolIndex.$_createMessage);
  static SymbolIndex? _defaultInstance;

  /// Index identifier.
  @$pb.TagNumber(1)
  $fixnum.Int64 get i => $_getI64(0);
  @$pb.TagNumber(1)
  set i($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasI() => $_has(0);
  @$pb.TagNumber(1)
  void clearI() => $_clearField(1);

  /// Global identifier.
  @$pb.TagNumber(2)
  $fixnum.Int64 get g => $_getI64(1);
  @$pb.TagNumber(2)
  set g($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasG() => $_has(1);
  @$pb.TagNumber(2)
  void clearG() => $_clearField(2);

  /// Type of the symbol or scope.
  @$pb.TagNumber(3)
  $core.String get kind => $_getSZ(2);
  @$pb.TagNumber(3)
  set kind($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasKind() => $_has(2);
  @$pb.TagNumber(3)
  void clearKind() => $_clearField(3);
}

/// Message representing a scope index.
class ScopeIndex extends $pb.GeneratedMessage {
  factory ScopeIndex({
    $fixnum.Int64? i,
    $fixnum.Int64? g,
    $core.String? kind,
  }) {
    final result = ScopeIndex._();
    if (i != null) result.i = i;
    if (g != null) result.g = g;
    if (kind != null) result.kind = kind;
    return result;
  }

  ScopeIndex._();

  factory ScopeIndex.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ScopeIndex()..mergeFromBuffer(data, registry);
  factory ScopeIndex.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ScopeIndex()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScopeIndex',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: ScopeIndex.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'i', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'g', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(3, _omitFieldNames ? '' : 'kind')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScopeIndex clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScopeIndex copyWith(void Function(ScopeIndex) updates) =>
      super.copyWith((message) => updates(message as ScopeIndex)) as ScopeIndex;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ScopeIndex() / ScopeIndex.new instead')
  static ScopeIndex create() => ScopeIndex._();
  static $pb.GeneratedMessage $_createMessage() => ScopeIndex._();
  @$core.override
  ScopeIndex createEmptyInstance() => ScopeIndex._();
  @$core.pragma('dart2js:noInline')
  static ScopeIndex getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ScopeIndex>(ScopeIndex.$_createMessage);
  static ScopeIndex? _defaultInstance;

  /// Index identifier.
  @$pb.TagNumber(1)
  $fixnum.Int64 get i => $_getI64(0);
  @$pb.TagNumber(1)
  set i($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasI() => $_has(0);
  @$pb.TagNumber(1)
  void clearI() => $_clearField(1);

  /// Global identifier.
  @$pb.TagNumber(2)
  $fixnum.Int64 get g => $_getI64(1);
  @$pb.TagNumber(2)
  set g($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasG() => $_has(1);
  @$pb.TagNumber(2)
  void clearG() => $_clearField(2);

  /// Type of the scope.
  @$pb.TagNumber(3)
  $core.String get kind => $_getSZ(2);
  @$pb.TagNumber(3)
  set kind($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasKind() => $_has(2);
  @$pb.TagNumber(3)
  void clearKind() => $_clearField(3);
}

/// Message for execute program request arguments.
class ExecProgramArgs extends $pb.GeneratedMessage {
  factory ExecProgramArgs({
    $core.String? workDir,
    $core.Iterable<$core.String>? kFilenameList,
    $core.Iterable<$core.String>? kCodeList,
    $core.Iterable<Argument>? args,
    $core.Iterable<$core.String>? overrides,
    $core.bool? disableYamlResult,
    $core.bool? printOverrideAst,
    $core.bool? strictRangeCheck,
    $core.bool? disableNone,
    $core.int? verbose,
    $core.int? debug,
    $core.bool? sortKeys,
    $core.Iterable<ExternalPkg>? externalPkgs,
    $core.bool? includeSchemaTypePath,
    $core.bool? compileOnly,
    $core.bool? showHidden,
    $core.Iterable<$core.String>? pathSelector,
    $core.bool? fastEval,
    $core.String? errorFormat,
    $core.String? format,
    $core.bool? emitAttributeMetadata,
    $core.String? sourcemapOutput,
  }) {
    final result = ExecProgramArgs._();
    if (workDir != null) result.workDir = workDir;
    if (kFilenameList != null) result.kFilenameList.addAll(kFilenameList);
    if (kCodeList != null) result.kCodeList.addAll(kCodeList);
    if (args != null) result.args.addAll(args);
    if (overrides != null) result.overrides.addAll(overrides);
    if (disableYamlResult != null) result.disableYamlResult = disableYamlResult;
    if (printOverrideAst != null) result.printOverrideAst = printOverrideAst;
    if (strictRangeCheck != null) result.strictRangeCheck = strictRangeCheck;
    if (disableNone != null) result.disableNone = disableNone;
    if (verbose != null) result.verbose = verbose;
    if (debug != null) result.debug = debug;
    if (sortKeys != null) result.sortKeys = sortKeys;
    if (externalPkgs != null) result.externalPkgs.addAll(externalPkgs);
    if (includeSchemaTypePath != null)
      result.includeSchemaTypePath = includeSchemaTypePath;
    if (compileOnly != null) result.compileOnly = compileOnly;
    if (showHidden != null) result.showHidden = showHidden;
    if (pathSelector != null) result.pathSelector.addAll(pathSelector);
    if (fastEval != null) result.fastEval = fastEval;
    if (errorFormat != null) result.errorFormat = errorFormat;
    if (format != null) result.format = format;
    if (emitAttributeMetadata != null)
      result.emitAttributeMetadata = emitAttributeMetadata;
    if (sourcemapOutput != null) result.sourcemapOutput = sourcemapOutput;
    return result;
  }

  ExecProgramArgs._();

  factory ExecProgramArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExecProgramArgs()..mergeFromBuffer(data, registry);
  factory ExecProgramArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExecProgramArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExecProgramArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: ExecProgramArgs.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'workDir')
    ..pPS(2, _omitFieldNames ? '' : 'kFilenameList')
    ..pPS(3, _omitFieldNames ? '' : 'kCodeList')
    ..pPM<Argument>(4, _omitFieldNames ? '' : 'args',
        subBuilder: Argument.$_createMessage)
    ..pPS(5, _omitFieldNames ? '' : 'overrides')
    ..aOB(6, _omitFieldNames ? '' : 'disableYamlResult')
    ..aOB(7, _omitFieldNames ? '' : 'printOverrideAst')
    ..aOB(8, _omitFieldNames ? '' : 'strictRangeCheck')
    ..aOB(9, _omitFieldNames ? '' : 'disableNone')
    ..aI(10, _omitFieldNames ? '' : 'verbose')
    ..aI(11, _omitFieldNames ? '' : 'debug')
    ..aOB(12, _omitFieldNames ? '' : 'sortKeys')
    ..pPM<ExternalPkg>(13, _omitFieldNames ? '' : 'externalPkgs',
        subBuilder: ExternalPkg.$_createMessage)
    ..aOB(14, _omitFieldNames ? '' : 'includeSchemaTypePath')
    ..aOB(15, _omitFieldNames ? '' : 'compileOnly')
    ..aOB(16, _omitFieldNames ? '' : 'showHidden')
    ..pPS(17, _omitFieldNames ? '' : 'pathSelector')
    ..aOB(18, _omitFieldNames ? '' : 'fastEval')
    ..aOS(19, _omitFieldNames ? '' : 'errorFormat')
    ..aOS(20, _omitFieldNames ? '' : 'format')
    ..aOB(21, _omitFieldNames ? '' : 'emitAttributeMetadata')
    ..aOS(22, _omitFieldNames ? '' : 'sourcemapOutput')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExecProgramArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExecProgramArgs copyWith(void Function(ExecProgramArgs) updates) =>
      super.copyWith((message) => updates(message as ExecProgramArgs))
          as ExecProgramArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ExecProgramArgs() / ExecProgramArgs.new instead')
  static ExecProgramArgs create() => ExecProgramArgs._();
  static $pb.GeneratedMessage $_createMessage() => ExecProgramArgs._();
  @$core.override
  ExecProgramArgs createEmptyInstance() => ExecProgramArgs._();
  @$core.pragma('dart2js:noInline')
  static ExecProgramArgs getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ExecProgramArgs>(
          ExecProgramArgs.$_createMessage);
  static ExecProgramArgs? _defaultInstance;

  /// Working directory.
  @$pb.TagNumber(1)
  $core.String get workDir => $_getSZ(0);
  @$pb.TagNumber(1)
  set workDir($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkDir() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkDir() => $_clearField(1);

  /// List of KCL filenames.
  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get kFilenameList => $_getList(1);

  /// List of KCL codes.
  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get kCodeList => $_getList(2);

  /// Arguments for the program.
  @$pb.TagNumber(4)
  $pb.PbList<Argument> get args => $_getList(3);

  /// Override configurations.
  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get overrides => $_getList(4);

  /// Flag to disable YAML result.
  @$pb.TagNumber(6)
  $core.bool get disableYamlResult => $_getBF(5);
  @$pb.TagNumber(6)
  set disableYamlResult($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDisableYamlResult() => $_has(5);
  @$pb.TagNumber(6)
  void clearDisableYamlResult() => $_clearField(6);

  /// Flag to print override AST.
  @$pb.TagNumber(7)
  $core.bool get printOverrideAst => $_getBF(6);
  @$pb.TagNumber(7)
  set printOverrideAst($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPrintOverrideAst() => $_has(6);
  @$pb.TagNumber(7)
  void clearPrintOverrideAst() => $_clearField(7);

  /// Flag for strict range check.
  @$pb.TagNumber(8)
  $core.bool get strictRangeCheck => $_getBF(7);
  @$pb.TagNumber(8)
  set strictRangeCheck($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasStrictRangeCheck() => $_has(7);
  @$pb.TagNumber(8)
  void clearStrictRangeCheck() => $_clearField(8);

  /// Flag to disable none values.
  @$pb.TagNumber(9)
  $core.bool get disableNone => $_getBF(8);
  @$pb.TagNumber(9)
  set disableNone($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasDisableNone() => $_has(8);
  @$pb.TagNumber(9)
  void clearDisableNone() => $_clearField(9);

  /// Verbose level.
  @$pb.TagNumber(10)
  $core.int get verbose => $_getIZ(9);
  @$pb.TagNumber(10)
  set verbose($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasVerbose() => $_has(9);
  @$pb.TagNumber(10)
  void clearVerbose() => $_clearField(10);

  /// Debug level.
  @$pb.TagNumber(11)
  $core.int get debug => $_getIZ(10);
  @$pb.TagNumber(11)
  set debug($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasDebug() => $_has(10);
  @$pb.TagNumber(11)
  void clearDebug() => $_clearField(11);

  /// Flag to sort keys in YAML/JSON results.
  @$pb.TagNumber(12)
  $core.bool get sortKeys => $_getBF(11);
  @$pb.TagNumber(12)
  set sortKeys($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasSortKeys() => $_has(11);
  @$pb.TagNumber(12)
  void clearSortKeys() => $_clearField(12);

  /// External packages path.
  @$pb.TagNumber(13)
  $pb.PbList<ExternalPkg> get externalPkgs => $_getList(12);

  /// Flag to include schema type path in results.
  @$pb.TagNumber(14)
  $core.bool get includeSchemaTypePath => $_getBF(13);
  @$pb.TagNumber(14)
  set includeSchemaTypePath($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(14)
  $core.bool hasIncludeSchemaTypePath() => $_has(13);
  @$pb.TagNumber(14)
  void clearIncludeSchemaTypePath() => $_clearField(14);

  /// Flag to compile only without execution.
  @$pb.TagNumber(15)
  $core.bool get compileOnly => $_getBF(14);
  @$pb.TagNumber(15)
  set compileOnly($core.bool value) => $_setBool(14, value);
  @$pb.TagNumber(15)
  $core.bool hasCompileOnly() => $_has(14);
  @$pb.TagNumber(15)
  void clearCompileOnly() => $_clearField(15);

  /// Flag to show hidden attributes.
  @$pb.TagNumber(16)
  $core.bool get showHidden => $_getBF(15);
  @$pb.TagNumber(16)
  set showHidden($core.bool value) => $_setBool(15, value);
  @$pb.TagNumber(16)
  $core.bool hasShowHidden() => $_has(15);
  @$pb.TagNumber(16)
  void clearShowHidden() => $_clearField(16);

  /// Path selectors for results.
  @$pb.TagNumber(17)
  $pb.PbList<$core.String> get pathSelector => $_getList(16);

  /// Flag for fast evaluation.
  @$pb.TagNumber(18)
  $core.bool get fastEval => $_getBF(17);
  @$pb.TagNumber(18)
  set fastEval($core.bool value) => $_setBool(17, value);
  @$pb.TagNumber(18)
  $core.bool hasFastEval() => $_has(17);
  @$pb.TagNumber(18)
  void clearFastEval() => $_clearField(18);

  /// Diagnostic output format. One of: pretty, short, arcanist, sarif.
  /// When set to anything other than "pretty", compile/eval errors are
  /// emitted to stderr in the chosen machine-readable format. Falls back
  /// to the `KCL_ERROR_FORMAT` environment variable when empty.
  @$pb.TagNumber(19)
  $core.String get errorFormat => $_getSZ(18);
  @$pb.TagNumber(19)
  set errorFormat($core.String value) => $_setString(18, value);
  @$pb.TagNumber(19)
  $core.bool hasErrorFormat() => $_has(18);
  @$pb.TagNumber(19)
  void clearErrorFormat() => $_clearField(19);

  /// Output format selector. One of: yaml, json.
  /// When empty the runtime generates both formats (legacy behaviour).
  @$pb.TagNumber(20)
  $core.String get format => $_getSZ(19);
  @$pb.TagNumber(20)
  set format($core.String value) => $_setString(19, value);
  @$pb.TagNumber(20)
  $core.bool hasFormat() => $_has(19);
  @$pb.TagNumber(20)
  void clearFormat() => $_clearField(20);

  /// Emit a side-channel marker in the planned YAML/JSON that names
  /// schema attributes to be carried over to downstream emitters. The
  /// marker is the sibling key `__kcl_info_meta__` whose value is a
  /// list of attribute names (e.g. those decorated with
  /// `@info(type="attr")`). Consumers (CLI/kcl-go) interpret it when
  /// emitting XML. Defaults to false to keep `-o json` / `-o yaml`
  /// output byte-identical to pre-change.
  @$pb.TagNumber(21)
  $core.bool get emitAttributeMetadata => $_getBF(20);
  @$pb.TagNumber(21)
  set emitAttributeMetadata($core.bool value) => $_setBool(20, value);
  @$pb.TagNumber(21)
  $core.bool hasEmitAttributeMetadata() => $_has(20);
  @$pb.TagNumber(21)
  void clearEmitAttributeMetadata() => $_clearField(21);

  /// Optional path of the Source Map v3 (tc39.es/source-map) document to
  /// emit for the generated YAML. When non-empty, the runtime records the
  /// mapping between generated YAML lines and the originating KCL source
  /// locations, returns it in `ExecProgramResult.sourcemap` and writes it
  /// to the given path. Empty disables source map generation.
  @$pb.TagNumber(22)
  $core.String get sourcemapOutput => $_getSZ(21);
  @$pb.TagNumber(22)
  set sourcemapOutput($core.String value) => $_setString(21, value);
  @$pb.TagNumber(22)
  $core.bool hasSourcemapOutput() => $_has(21);
  @$pb.TagNumber(22)
  void clearSourcemapOutput() => $_clearField(22);
}

/// Message for execute program response.
class ExecProgramResult extends $pb.GeneratedMessage {
  factory ExecProgramResult({
    $core.String? jsonResult,
    $core.String? yamlResult,
    $core.String? logMessage,
    $core.String? errMessage,
    $core.String? sourcemap,
  }) {
    final result = ExecProgramResult._();
    if (jsonResult != null) result.jsonResult = jsonResult;
    if (yamlResult != null) result.yamlResult = yamlResult;
    if (logMessage != null) result.logMessage = logMessage;
    if (errMessage != null) result.errMessage = errMessage;
    if (sourcemap != null) result.sourcemap = sourcemap;
    return result;
  }

  ExecProgramResult._();

  factory ExecProgramResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExecProgramResult()..mergeFromBuffer(data, registry);
  factory ExecProgramResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExecProgramResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExecProgramResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: ExecProgramResult.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'jsonResult')
    ..aOS(2, _omitFieldNames ? '' : 'yamlResult')
    ..aOS(3, _omitFieldNames ? '' : 'logMessage')
    ..aOS(4, _omitFieldNames ? '' : 'errMessage')
    ..aOS(5, _omitFieldNames ? '' : 'sourcemap')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExecProgramResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExecProgramResult copyWith(void Function(ExecProgramResult) updates) =>
      super.copyWith((message) => updates(message as ExecProgramResult))
          as ExecProgramResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ExecProgramResult() / ExecProgramResult.new instead')
  static ExecProgramResult create() => ExecProgramResult._();
  static $pb.GeneratedMessage $_createMessage() => ExecProgramResult._();
  @$core.override
  ExecProgramResult createEmptyInstance() => ExecProgramResult._();
  @$core.pragma('dart2js:noInline')
  static ExecProgramResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ExecProgramResult>(
          ExecProgramResult.$_createMessage);
  static ExecProgramResult? _defaultInstance;

  /// Result in JSON format.
  @$pb.TagNumber(1)
  $core.String get jsonResult => $_getSZ(0);
  @$pb.TagNumber(1)
  set jsonResult($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasJsonResult() => $_has(0);
  @$pb.TagNumber(1)
  void clearJsonResult() => $_clearField(1);

  /// Result in YAML format.
  @$pb.TagNumber(2)
  $core.String get yamlResult => $_getSZ(1);
  @$pb.TagNumber(2)
  set yamlResult($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasYamlResult() => $_has(1);
  @$pb.TagNumber(2)
  void clearYamlResult() => $_clearField(2);

  /// Log message from execution.
  @$pb.TagNumber(3)
  $core.String get logMessage => $_getSZ(2);
  @$pb.TagNumber(3)
  set logMessage($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLogMessage() => $_has(2);
  @$pb.TagNumber(3)
  void clearLogMessage() => $_clearField(3);

  /// Error message from execution.
  @$pb.TagNumber(4)
  $core.String get errMessage => $_getSZ(3);
  @$pb.TagNumber(4)
  set errMessage($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasErrMessage() => $_has(3);
  @$pb.TagNumber(4)
  void clearErrMessage() => $_clearField(4);

  /// Source Map v3 (tc39.es/source-map) JSON mapping the generated YAML
  /// back to the originating KCL source. Populated only when the caller
  /// requests a source map; empty otherwise.
  @$pb.TagNumber(5)
  $core.String get sourcemap => $_getSZ(4);
  @$pb.TagNumber(5)
  set sourcemap($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSourcemap() => $_has(4);
  @$pb.TagNumber(5)
  void clearSourcemap() => $_clearField(5);
}

/// Message for format code request arguments.
class FormatCodeArgs extends $pb.GeneratedMessage {
  factory FormatCodeArgs({
    $core.String? source,
  }) {
    final result = FormatCodeArgs._();
    if (source != null) result.source = source;
    return result;
  }

  FormatCodeArgs._();

  factory FormatCodeArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FormatCodeArgs()..mergeFromBuffer(data, registry);
  factory FormatCodeArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FormatCodeArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FormatCodeArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: FormatCodeArgs.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'source')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FormatCodeArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FormatCodeArgs copyWith(void Function(FormatCodeArgs) updates) =>
      super.copyWith((message) => updates(message as FormatCodeArgs))
          as FormatCodeArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FormatCodeArgs() / FormatCodeArgs.new instead')
  static FormatCodeArgs create() => FormatCodeArgs._();
  static $pb.GeneratedMessage $_createMessage() => FormatCodeArgs._();
  @$core.override
  FormatCodeArgs createEmptyInstance() => FormatCodeArgs._();
  @$core.pragma('dart2js:noInline')
  static FormatCodeArgs getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FormatCodeArgs>(
          FormatCodeArgs.$_createMessage);
  static FormatCodeArgs? _defaultInstance;

  /// Source code to be formatted.
  @$pb.TagNumber(1)
  $core.String get source => $_getSZ(0);
  @$pb.TagNumber(1)
  set source($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSource() => $_has(0);
  @$pb.TagNumber(1)
  void clearSource() => $_clearField(1);
}

/// Message for format code response.
class FormatCodeResult extends $pb.GeneratedMessage {
  factory FormatCodeResult({
    $core.List<$core.int>? formatted,
  }) {
    final result = FormatCodeResult._();
    if (formatted != null) result.formatted = formatted;
    return result;
  }

  FormatCodeResult._();

  factory FormatCodeResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FormatCodeResult()..mergeFromBuffer(data, registry);
  factory FormatCodeResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FormatCodeResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FormatCodeResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: FormatCodeResult.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'formatted', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FormatCodeResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FormatCodeResult copyWith(void Function(FormatCodeResult) updates) =>
      super.copyWith((message) => updates(message as FormatCodeResult))
          as FormatCodeResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FormatCodeResult() / FormatCodeResult.new instead')
  static FormatCodeResult create() => FormatCodeResult._();
  static $pb.GeneratedMessage $_createMessage() => FormatCodeResult._();
  @$core.override
  FormatCodeResult createEmptyInstance() => FormatCodeResult._();
  @$core.pragma('dart2js:noInline')
  static FormatCodeResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FormatCodeResult>(
          FormatCodeResult.$_createMessage);
  static FormatCodeResult? _defaultInstance;

  /// Formatted code as bytes.
  @$pb.TagNumber(1)
  $core.List<$core.int> get formatted => $_getN(0);
  @$pb.TagNumber(1)
  set formatted($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFormatted() => $_has(0);
  @$pb.TagNumber(1)
  void clearFormatted() => $_clearField(1);
}

/// Message for format file path request arguments.
class FormatPathArgs extends $pb.GeneratedMessage {
  factory FormatPathArgs({
    $core.String? path,
    $core.bool? dryRun,
  }) {
    final result = FormatPathArgs._();
    if (path != null) result.path = path;
    if (dryRun != null) result.dryRun = dryRun;
    return result;
  }

  FormatPathArgs._();

  factory FormatPathArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FormatPathArgs()..mergeFromBuffer(data, registry);
  factory FormatPathArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FormatPathArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FormatPathArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: FormatPathArgs.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOB(2, _omitFieldNames ? '' : 'dryRun')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FormatPathArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FormatPathArgs copyWith(void Function(FormatPathArgs) updates) =>
      super.copyWith((message) => updates(message as FormatPathArgs))
          as FormatPathArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FormatPathArgs() / FormatPathArgs.new instead')
  static FormatPathArgs create() => FormatPathArgs._();
  static $pb.GeneratedMessage $_createMessage() => FormatPathArgs._();
  @$core.override
  FormatPathArgs createEmptyInstance() => FormatPathArgs._();
  @$core.pragma('dart2js:noInline')
  static FormatPathArgs getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FormatPathArgs>(
          FormatPathArgs.$_createMessage);
  static FormatPathArgs? _defaultInstance;

  /// Path of the file to format.
  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  /// Whether to dry run the formatting.
  @$pb.TagNumber(2)
  $core.bool get dryRun => $_getBF(1);
  @$pb.TagNumber(2)
  set dryRun($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDryRun() => $_has(1);
  @$pb.TagNumber(2)
  void clearDryRun() => $_clearField(2);
}

/// Message for format file path response.
class FormatPathResult extends $pb.GeneratedMessage {
  factory FormatPathResult({
    $core.Iterable<$core.String>? changedPaths,
  }) {
    final result = FormatPathResult._();
    if (changedPaths != null) result.changedPaths.addAll(changedPaths);
    return result;
  }

  FormatPathResult._();

  factory FormatPathResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FormatPathResult()..mergeFromBuffer(data, registry);
  factory FormatPathResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FormatPathResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FormatPathResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: FormatPathResult.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'changedPaths')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FormatPathResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FormatPathResult copyWith(void Function(FormatPathResult) updates) =>
      super.copyWith((message) => updates(message as FormatPathResult))
          as FormatPathResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FormatPathResult() / FormatPathResult.new instead')
  static FormatPathResult create() => FormatPathResult._();
  static $pb.GeneratedMessage $_createMessage() => FormatPathResult._();
  @$core.override
  FormatPathResult createEmptyInstance() => FormatPathResult._();
  @$core.pragma('dart2js:noInline')
  static FormatPathResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FormatPathResult>(
          FormatPathResult.$_createMessage);
  static FormatPathResult? _defaultInstance;

  /// List of changed file paths.
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get changedPaths => $_getList(0);
}

/// Message for lint file path request arguments.
class LintPathArgs extends $pb.GeneratedMessage {
  factory LintPathArgs({
    $core.Iterable<$core.String>? paths,
  }) {
    final result = LintPathArgs._();
    if (paths != null) result.paths.addAll(paths);
    return result;
  }

  LintPathArgs._();

  factory LintPathArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LintPathArgs()..mergeFromBuffer(data, registry);
  factory LintPathArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LintPathArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LintPathArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: LintPathArgs.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'paths')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LintPathArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LintPathArgs copyWith(void Function(LintPathArgs) updates) =>
      super.copyWith((message) => updates(message as LintPathArgs))
          as LintPathArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LintPathArgs() / LintPathArgs.new instead')
  static LintPathArgs create() => LintPathArgs._();
  static $pb.GeneratedMessage $_createMessage() => LintPathArgs._();
  @$core.override
  LintPathArgs createEmptyInstance() => LintPathArgs._();
  @$core.pragma('dart2js:noInline')
  static LintPathArgs getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LintPathArgs>(
          LintPathArgs.$_createMessage);
  static LintPathArgs? _defaultInstance;

  /// Paths of the files to lint.
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get paths => $_getList(0);
}

/// Message for lint file path response.
class LintPathResult extends $pb.GeneratedMessage {
  factory LintPathResult({
    $core.Iterable<$core.String>? results,
  }) {
    final result = LintPathResult._();
    if (results != null) result.results.addAll(results);
    return result;
  }

  LintPathResult._();

  factory LintPathResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LintPathResult()..mergeFromBuffer(data, registry);
  factory LintPathResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LintPathResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LintPathResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: LintPathResult.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'results')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LintPathResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LintPathResult copyWith(void Function(LintPathResult) updates) =>
      super.copyWith((message) => updates(message as LintPathResult))
          as LintPathResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LintPathResult() / LintPathResult.new instead')
  static LintPathResult create() => LintPathResult._();
  static $pb.GeneratedMessage $_createMessage() => LintPathResult._();
  @$core.override
  LintPathResult createEmptyInstance() => LintPathResult._();
  @$core.pragma('dart2js:noInline')
  static LintPathResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LintPathResult>(
          LintPathResult.$_createMessage);
  static LintPathResult? _defaultInstance;

  /// List of lint results.
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get results => $_getList(0);
}

/// Message for override file request arguments.
class OverrideFileArgs extends $pb.GeneratedMessage {
  factory OverrideFileArgs({
    $core.String? file,
    $core.Iterable<$core.String>? specs,
    $core.Iterable<$core.String>? importPaths,
  }) {
    final result = OverrideFileArgs._();
    if (file != null) result.file = file;
    if (specs != null) result.specs.addAll(specs);
    if (importPaths != null) result.importPaths.addAll(importPaths);
    return result;
  }

  OverrideFileArgs._();

  factory OverrideFileArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OverrideFileArgs()..mergeFromBuffer(data, registry);
  factory OverrideFileArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OverrideFileArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OverrideFileArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: OverrideFileArgs.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'file')
    ..pPS(2, _omitFieldNames ? '' : 'specs')
    ..pPS(3, _omitFieldNames ? '' : 'importPaths')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OverrideFileArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OverrideFileArgs copyWith(void Function(OverrideFileArgs) updates) =>
      super.copyWith((message) => updates(message as OverrideFileArgs))
          as OverrideFileArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use OverrideFileArgs() / OverrideFileArgs.new instead')
  static OverrideFileArgs create() => OverrideFileArgs._();
  static $pb.GeneratedMessage $_createMessage() => OverrideFileArgs._();
  @$core.override
  OverrideFileArgs createEmptyInstance() => OverrideFileArgs._();
  @$core.pragma('dart2js:noInline')
  static OverrideFileArgs getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<OverrideFileArgs>(
          OverrideFileArgs.$_createMessage);
  static OverrideFileArgs? _defaultInstance;

  /// Path of the file to override.
  @$pb.TagNumber(1)
  $core.String get file => $_getSZ(0);
  @$pb.TagNumber(1)
  set file($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFile() => $_has(0);
  @$pb.TagNumber(1)
  void clearFile() => $_clearField(1);

  /// List of override specifications.
  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get specs => $_getList(1);

  /// List of import paths.
  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get importPaths => $_getList(2);
}

/// Message for override file response.
class OverrideFileResult extends $pb.GeneratedMessage {
  factory OverrideFileResult({
    $core.bool? result,
    $core.Iterable<Error>? parseErrors,
  }) {
    final result$ = OverrideFileResult._();
    if (result != null) result$.result = result;
    if (parseErrors != null) result$.parseErrors.addAll(parseErrors);
    return result$;
  }

  OverrideFileResult._();

  factory OverrideFileResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OverrideFileResult()..mergeFromBuffer(data, registry);
  factory OverrideFileResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OverrideFileResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OverrideFileResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: OverrideFileResult.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'result')
    ..pPM<Error>(2, _omitFieldNames ? '' : 'parseErrors',
        subBuilder: Error.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OverrideFileResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OverrideFileResult copyWith(void Function(OverrideFileResult) updates) =>
      super.copyWith((message) => updates(message as OverrideFileResult))
          as OverrideFileResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use OverrideFileResult() / OverrideFileResult.new instead')
  static OverrideFileResult create() => OverrideFileResult._();
  static $pb.GeneratedMessage $_createMessage() => OverrideFileResult._();
  @$core.override
  OverrideFileResult createEmptyInstance() => OverrideFileResult._();
  @$core.pragma('dart2js:noInline')
  static OverrideFileResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OverrideFileResult>(
          OverrideFileResult.$_createMessage);
  static OverrideFileResult? _defaultInstance;

  /// Result of the override operation.
  @$pb.TagNumber(1)
  $core.bool get result => $_getBF(0);
  @$pb.TagNumber(1)
  set result($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasResult() => $_has(0);
  @$pb.TagNumber(1)
  void clearResult() => $_clearField(1);

  /// List of parse errors encountered.
  @$pb.TagNumber(2)
  $pb.PbList<Error> get parseErrors => $_getList(1);
}

/// Message for list variables options.
class ListVariablesOptions extends $pb.GeneratedMessage {
  factory ListVariablesOptions({
    $core.bool? mergeProgram,
  }) {
    final result = ListVariablesOptions._();
    if (mergeProgram != null) result.mergeProgram = mergeProgram;
    return result;
  }

  ListVariablesOptions._();

  factory ListVariablesOptions.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListVariablesOptions()..mergeFromBuffer(data, registry);
  factory ListVariablesOptions.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListVariablesOptions()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListVariablesOptions',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: ListVariablesOptions.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'mergeProgram')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListVariablesOptions clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListVariablesOptions copyWith(void Function(ListVariablesOptions) updates) =>
      super.copyWith((message) => updates(message as ListVariablesOptions))
          as ListVariablesOptions;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListVariablesOptions() / ListVariablesOptions.new instead')
  static ListVariablesOptions create() => ListVariablesOptions._();
  static $pb.GeneratedMessage $_createMessage() => ListVariablesOptions._();
  @$core.override
  ListVariablesOptions createEmptyInstance() => ListVariablesOptions._();
  @$core.pragma('dart2js:noInline')
  static ListVariablesOptions getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListVariablesOptions>(
          ListVariablesOptions.$_createMessage);
  static ListVariablesOptions? _defaultInstance;

  /// Flag to merge program configuration.
  @$pb.TagNumber(1)
  $core.bool get mergeProgram => $_getBF(0);
  @$pb.TagNumber(1)
  set mergeProgram($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMergeProgram() => $_has(0);
  @$pb.TagNumber(1)
  void clearMergeProgram() => $_clearField(1);
}

/// Message representing a list of variables.
class VariableList extends $pb.GeneratedMessage {
  factory VariableList({
    $core.Iterable<Variable>? variables,
  }) {
    final result = VariableList._();
    if (variables != null) result.variables.addAll(variables);
    return result;
  }

  VariableList._();

  factory VariableList.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VariableList()..mergeFromBuffer(data, registry);
  factory VariableList.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VariableList()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VariableList',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: VariableList.$_createMessage)
    ..pPM<Variable>(1, _omitFieldNames ? '' : 'variables',
        subBuilder: Variable.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VariableList clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VariableList copyWith(void Function(VariableList) updates) =>
      super.copyWith((message) => updates(message as VariableList))
          as VariableList;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use VariableList() / VariableList.new instead')
  static VariableList create() => VariableList._();
  static $pb.GeneratedMessage $_createMessage() => VariableList._();
  @$core.override
  VariableList createEmptyInstance() => VariableList._();
  @$core.pragma('dart2js:noInline')
  static VariableList getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<VariableList>(
          VariableList.$_createMessage);
  static VariableList? _defaultInstance;

  /// List of variables.
  @$pb.TagNumber(1)
  $pb.PbList<Variable> get variables => $_getList(0);
}

/// Message for list variables request arguments.
class ListVariablesArgs extends $pb.GeneratedMessage {
  factory ListVariablesArgs({
    $core.Iterable<$core.String>? files,
    $core.Iterable<$core.String>? specs,
    ListVariablesOptions? options,
  }) {
    final result = ListVariablesArgs._();
    if (files != null) result.files.addAll(files);
    if (specs != null) result.specs.addAll(specs);
    if (options != null) result.options = options;
    return result;
  }

  ListVariablesArgs._();

  factory ListVariablesArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListVariablesArgs()..mergeFromBuffer(data, registry);
  factory ListVariablesArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListVariablesArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListVariablesArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: ListVariablesArgs.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'files')
    ..pPS(2, _omitFieldNames ? '' : 'specs')
    ..aOM<ListVariablesOptions>(3, _omitFieldNames ? '' : 'options',
        subBuilder: ListVariablesOptions.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListVariablesArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListVariablesArgs copyWith(void Function(ListVariablesArgs) updates) =>
      super.copyWith((message) => updates(message as ListVariablesArgs))
          as ListVariablesArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListVariablesArgs() / ListVariablesArgs.new instead')
  static ListVariablesArgs create() => ListVariablesArgs._();
  static $pb.GeneratedMessage $_createMessage() => ListVariablesArgs._();
  @$core.override
  ListVariablesArgs createEmptyInstance() => ListVariablesArgs._();
  @$core.pragma('dart2js:noInline')
  static ListVariablesArgs getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListVariablesArgs>(
          ListVariablesArgs.$_createMessage);
  static ListVariablesArgs? _defaultInstance;

  /// Files to be processed.
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get files => $_getList(0);

  /// Specifications for variables.
  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get specs => $_getList(1);

  /// Options for listing variables.
  @$pb.TagNumber(3)
  ListVariablesOptions get options => $_getN(2);
  @$pb.TagNumber(3)
  set options(ListVariablesOptions value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasOptions() => $_has(2);
  @$pb.TagNumber(3)
  void clearOptions() => $_clearField(3);
  @$pb.TagNumber(3)
  ListVariablesOptions ensureOptions() => $_ensure(2);
}

/// Message for list variables response.
class ListVariablesResult extends $pb.GeneratedMessage {
  factory ListVariablesResult({
    $core.Iterable<$core.MapEntry<$core.String, VariableList>>? variables,
    $core.Iterable<$core.String>? unsupportedCodes,
    $core.Iterable<Error>? parseErrors,
  }) {
    final result = ListVariablesResult._();
    if (variables != null) result.variables.addEntries(variables);
    if (unsupportedCodes != null)
      result.unsupportedCodes.addAll(unsupportedCodes);
    if (parseErrors != null) result.parseErrors.addAll(parseErrors);
    return result;
  }

  ListVariablesResult._();

  factory ListVariablesResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListVariablesResult()..mergeFromBuffer(data, registry);
  factory ListVariablesResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListVariablesResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListVariablesResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: ListVariablesResult.$_createMessage)
    ..m<$core.String, VariableList>(1, _omitFieldNames ? '' : 'variables',
        entryClassName: 'ListVariablesResult.VariablesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: VariableList.$_createMessage,
        valueDefaultOrMaker: VariableList.getDefault,
        packageName: const $pb.PackageName('com.kcl.api'))
    ..pPS(2, _omitFieldNames ? '' : 'unsupportedCodes')
    ..pPM<Error>(3, _omitFieldNames ? '' : 'parseErrors',
        subBuilder: Error.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListVariablesResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListVariablesResult copyWith(void Function(ListVariablesResult) updates) =>
      super.copyWith((message) => updates(message as ListVariablesResult))
          as ListVariablesResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use ListVariablesResult() / ListVariablesResult.new instead')
  static ListVariablesResult create() => ListVariablesResult._();
  static $pb.GeneratedMessage $_createMessage() => ListVariablesResult._();
  @$core.override
  ListVariablesResult createEmptyInstance() => ListVariablesResult._();
  @$core.pragma('dart2js:noInline')
  static ListVariablesResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListVariablesResult>(
          ListVariablesResult.$_createMessage);
  static ListVariablesResult? _defaultInstance;

  /// Map of variable lists by file.
  @$pb.TagNumber(1)
  $pb.PbMap<$core.String, VariableList> get variables => $_getMap(0);

  /// List of unsupported codes.
  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get unsupportedCodes => $_getList(1);

  /// List of parse errors encountered.
  @$pb.TagNumber(3)
  $pb.PbList<Error> get parseErrors => $_getList(2);
}

/// Message representing a variable.
class Variable extends $pb.GeneratedMessage {
  factory Variable({
    $core.String? value,
    $core.String? typeName,
    $core.String? opSym,
    $core.Iterable<Variable>? listItems,
    $core.Iterable<MapEntry>? dictEntries,
  }) {
    final result = Variable._();
    if (value != null) result.value = value;
    if (typeName != null) result.typeName = typeName;
    if (opSym != null) result.opSym = opSym;
    if (listItems != null) result.listItems.addAll(listItems);
    if (dictEntries != null) result.dictEntries.addAll(dictEntries);
    return result;
  }

  Variable._();

  factory Variable.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Variable()..mergeFromBuffer(data, registry);
  factory Variable.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Variable()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Variable',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: Variable.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..aOS(2, _omitFieldNames ? '' : 'typeName')
    ..aOS(3, _omitFieldNames ? '' : 'opSym')
    ..pPM<Variable>(4, _omitFieldNames ? '' : 'listItems',
        subBuilder: Variable.$_createMessage)
    ..pPM<MapEntry>(5, _omitFieldNames ? '' : 'dictEntries',
        subBuilder: MapEntry.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Variable clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Variable copyWith(void Function(Variable) updates) =>
      super.copyWith((message) => updates(message as Variable)) as Variable;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Variable() / Variable.new instead')
  static Variable create() => Variable._();
  static $pb.GeneratedMessage $_createMessage() => Variable._();
  @$core.override
  Variable createEmptyInstance() => Variable._();
  @$core.pragma('dart2js:noInline')
  static Variable getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Variable>(Variable.$_createMessage);
  static Variable? _defaultInstance;

  /// Value of the variable.
  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);

  /// Type name of the variable.
  @$pb.TagNumber(2)
  $core.String get typeName => $_getSZ(1);
  @$pb.TagNumber(2)
  set typeName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTypeName() => $_has(1);
  @$pb.TagNumber(2)
  void clearTypeName() => $_clearField(2);

  /// Operation symbol associated with the variable.
  @$pb.TagNumber(3)
  $core.String get opSym => $_getSZ(2);
  @$pb.TagNumber(3)
  set opSym($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOpSym() => $_has(2);
  @$pb.TagNumber(3)
  void clearOpSym() => $_clearField(3);

  /// List items if the variable is a list.
  @$pb.TagNumber(4)
  $pb.PbList<Variable> get listItems => $_getList(3);

  /// Dictionary entries if the variable is a dictionary.
  @$pb.TagNumber(5)
  $pb.PbList<MapEntry> get dictEntries => $_getList(4);
}

/// Message representing a map entry.
class MapEntry extends $pb.GeneratedMessage {
  factory MapEntry({
    $core.String? key,
    Variable? value,
  }) {
    final result = MapEntry._();
    if (key != null) result.key = key;
    if (value != null) result.value = value;
    return result;
  }

  MapEntry._();

  factory MapEntry.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MapEntry()..mergeFromBuffer(data, registry);
  factory MapEntry.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MapEntry()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MapEntry',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: MapEntry.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..aOM<Variable>(2, _omitFieldNames ? '' : 'value',
        subBuilder: Variable.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MapEntry clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MapEntry copyWith(void Function(MapEntry) updates) =>
      super.copyWith((message) => updates(message as MapEntry)) as MapEntry;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MapEntry() / MapEntry.new instead')
  static MapEntry create() => MapEntry._();
  static $pb.GeneratedMessage $_createMessage() => MapEntry._();
  @$core.override
  MapEntry createEmptyInstance() => MapEntry._();
  @$core.pragma('dart2js:noInline')
  static MapEntry getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MapEntry>(MapEntry.$_createMessage);
  static MapEntry? _defaultInstance;

  /// Key of the map entry.
  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  /// Value of the map entry.
  @$pb.TagNumber(2)
  Variable get value => $_getN(1);
  @$pb.TagNumber(2)
  set value(Variable value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => $_clearField(2);
  @$pb.TagNumber(2)
  Variable ensureValue() => $_ensure(1);
}

/// Message for get schema type mapping request arguments.
class GetSchemaTypeMappingArgs extends $pb.GeneratedMessage {
  factory GetSchemaTypeMappingArgs({
    ExecProgramArgs? execArgs,
    $core.String? schemaName,
  }) {
    final result = GetSchemaTypeMappingArgs._();
    if (execArgs != null) result.execArgs = execArgs;
    if (schemaName != null) result.schemaName = schemaName;
    return result;
  }

  GetSchemaTypeMappingArgs._();

  factory GetSchemaTypeMappingArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetSchemaTypeMappingArgs()..mergeFromBuffer(data, registry);
  factory GetSchemaTypeMappingArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetSchemaTypeMappingArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSchemaTypeMappingArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: GetSchemaTypeMappingArgs.$_createMessage)
    ..aOM<ExecProgramArgs>(1, _omitFieldNames ? '' : 'execArgs',
        subBuilder: ExecProgramArgs.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'schemaName')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSchemaTypeMappingArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSchemaTypeMappingArgs copyWith(
          void Function(GetSchemaTypeMappingArgs) updates) =>
      super.copyWith((message) => updates(message as GetSchemaTypeMappingArgs))
          as GetSchemaTypeMappingArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetSchemaTypeMappingArgs() / GetSchemaTypeMappingArgs.new instead')
  static GetSchemaTypeMappingArgs create() => GetSchemaTypeMappingArgs._();
  static $pb.GeneratedMessage $_createMessage() => GetSchemaTypeMappingArgs._();
  @$core.override
  GetSchemaTypeMappingArgs createEmptyInstance() =>
      GetSchemaTypeMappingArgs._();
  @$core.pragma('dart2js:noInline')
  static GetSchemaTypeMappingArgs getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSchemaTypeMappingArgs>(
          GetSchemaTypeMappingArgs.$_createMessage);
  static GetSchemaTypeMappingArgs? _defaultInstance;

  /// Arguments for executing the program.
  @$pb.TagNumber(1)
  ExecProgramArgs get execArgs => $_getN(0);
  @$pb.TagNumber(1)
  set execArgs(ExecProgramArgs value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasExecArgs() => $_has(0);
  @$pb.TagNumber(1)
  void clearExecArgs() => $_clearField(1);
  @$pb.TagNumber(1)
  ExecProgramArgs ensureExecArgs() => $_ensure(0);

  /// Name of the schema.
  @$pb.TagNumber(2)
  $core.String get schemaName => $_getSZ(1);
  @$pb.TagNumber(2)
  set schemaName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSchemaName() => $_has(1);
  @$pb.TagNumber(2)
  void clearSchemaName() => $_clearField(2);
}

/// Message for get schema type mapping response.
class GetSchemaTypeMappingResult extends $pb.GeneratedMessage {
  factory GetSchemaTypeMappingResult({
    $core.Iterable<$core.MapEntry<$core.String, KclType>>? schemaTypeMapping,
  }) {
    final result = GetSchemaTypeMappingResult._();
    if (schemaTypeMapping != null)
      result.schemaTypeMapping.addEntries(schemaTypeMapping);
    return result;
  }

  GetSchemaTypeMappingResult._();

  factory GetSchemaTypeMappingResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetSchemaTypeMappingResult()..mergeFromBuffer(data, registry);
  factory GetSchemaTypeMappingResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetSchemaTypeMappingResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSchemaTypeMappingResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: GetSchemaTypeMappingResult.$_createMessage)
    ..m<$core.String, KclType>(1, _omitFieldNames ? '' : 'schemaTypeMapping',
        entryClassName: 'GetSchemaTypeMappingResult.SchemaTypeMappingEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: KclType.$_createMessage,
        valueDefaultOrMaker: KclType.getDefault,
        packageName: const $pb.PackageName('com.kcl.api'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSchemaTypeMappingResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSchemaTypeMappingResult copyWith(
          void Function(GetSchemaTypeMappingResult) updates) =>
      super.copyWith(
              (message) => updates(message as GetSchemaTypeMappingResult))
          as GetSchemaTypeMappingResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetSchemaTypeMappingResult() / GetSchemaTypeMappingResult.new instead')
  static GetSchemaTypeMappingResult create() => GetSchemaTypeMappingResult._();
  static $pb.GeneratedMessage $_createMessage() =>
      GetSchemaTypeMappingResult._();
  @$core.override
  GetSchemaTypeMappingResult createEmptyInstance() =>
      GetSchemaTypeMappingResult._();
  @$core.pragma('dart2js:noInline')
  static GetSchemaTypeMappingResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSchemaTypeMappingResult>(
          GetSchemaTypeMappingResult.$_createMessage);
  static GetSchemaTypeMappingResult? _defaultInstance;

  /// Map of schema type mappings.
  @$pb.TagNumber(1)
  $pb.PbMap<$core.String, KclType> get schemaTypeMapping => $_getMap(0);
}

/// Message for get schema type mapping response.
class GetSchemaTypeMappingUnderPathResult extends $pb.GeneratedMessage {
  factory GetSchemaTypeMappingUnderPathResult({
    $core.Iterable<$core.MapEntry<$core.String, SchemaTypes>>?
        schemaTypeMapping,
  }) {
    final result = GetSchemaTypeMappingUnderPathResult._();
    if (schemaTypeMapping != null)
      result.schemaTypeMapping.addEntries(schemaTypeMapping);
    return result;
  }

  GetSchemaTypeMappingUnderPathResult._();

  factory GetSchemaTypeMappingUnderPathResult.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetSchemaTypeMappingUnderPathResult()..mergeFromBuffer(data, registry);
  factory GetSchemaTypeMappingUnderPathResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetSchemaTypeMappingUnderPathResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSchemaTypeMappingUnderPathResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: GetSchemaTypeMappingUnderPathResult.$_createMessage)
    ..m<$core.String, SchemaTypes>(
        1, _omitFieldNames ? '' : 'schemaTypeMapping',
        entryClassName:
            'GetSchemaTypeMappingUnderPathResult.SchemaTypeMappingEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: SchemaTypes.$_createMessage,
        valueDefaultOrMaker: SchemaTypes.getDefault,
        packageName: const $pb.PackageName('com.kcl.api'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSchemaTypeMappingUnderPathResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSchemaTypeMappingUnderPathResult copyWith(
          void Function(GetSchemaTypeMappingUnderPathResult) updates) =>
      super.copyWith((message) =>
              updates(message as GetSchemaTypeMappingUnderPathResult))
          as GetSchemaTypeMappingUnderPathResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetSchemaTypeMappingUnderPathResult() / GetSchemaTypeMappingUnderPathResult.new instead')
  static GetSchemaTypeMappingUnderPathResult create() =>
      GetSchemaTypeMappingUnderPathResult._();
  static $pb.GeneratedMessage $_createMessage() =>
      GetSchemaTypeMappingUnderPathResult._();
  @$core.override
  GetSchemaTypeMappingUnderPathResult createEmptyInstance() =>
      GetSchemaTypeMappingUnderPathResult._();
  @$core.pragma('dart2js:noInline')
  static GetSchemaTypeMappingUnderPathResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
              GetSchemaTypeMappingUnderPathResult>(
          GetSchemaTypeMappingUnderPathResult.$_createMessage);
  static GetSchemaTypeMappingUnderPathResult? _defaultInstance;

  /// Map of pkg and schema types mappings.
  @$pb.TagNumber(1)
  $pb.PbMap<$core.String, SchemaTypes> get schemaTypeMapping => $_getMap(0);
}

class SchemaTypes extends $pb.GeneratedMessage {
  factory SchemaTypes({
    $core.Iterable<KclType>? schemaType,
  }) {
    final result = SchemaTypes._();
    if (schemaType != null) result.schemaType.addAll(schemaType);
    return result;
  }

  SchemaTypes._();

  factory SchemaTypes.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SchemaTypes()..mergeFromBuffer(data, registry);
  factory SchemaTypes.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SchemaTypes()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchemaTypes',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: SchemaTypes.$_createMessage)
    ..pPM<KclType>(1, _omitFieldNames ? '' : 'schemaType',
        subBuilder: KclType.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchemaTypes clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchemaTypes copyWith(void Function(SchemaTypes) updates) =>
      super.copyWith((message) => updates(message as SchemaTypes))
          as SchemaTypes;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SchemaTypes() / SchemaTypes.new instead')
  static SchemaTypes create() => SchemaTypes._();
  static $pb.GeneratedMessage $_createMessage() => SchemaTypes._();
  @$core.override
  SchemaTypes createEmptyInstance() => SchemaTypes._();
  @$core.pragma('dart2js:noInline')
  static SchemaTypes getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SchemaTypes>(
          SchemaTypes.$_createMessage);
  static SchemaTypes? _defaultInstance;

  /// List of schema type mappings.
  @$pb.TagNumber(1)
  $pb.PbList<KclType> get schemaType => $_getList(0);
}

/// Message for validate code request arguments.
class ValidateCodeArgs extends $pb.GeneratedMessage {
  factory ValidateCodeArgs({
    $core.String? datafile,
    $core.String? data,
    $core.String? file,
    $core.String? code,
    $core.String? schema,
    $core.String? attributeName,
    $core.String? format,
    $core.Iterable<ExternalPkg>? externalPkgs,
  }) {
    final result = ValidateCodeArgs._();
    if (datafile != null) result.datafile = datafile;
    if (data != null) result.data = data;
    if (file != null) result.file = file;
    if (code != null) result.code = code;
    if (schema != null) result.schema = schema;
    if (attributeName != null) result.attributeName = attributeName;
    if (format != null) result.format = format;
    if (externalPkgs != null) result.externalPkgs.addAll(externalPkgs);
    return result;
  }

  ValidateCodeArgs._();

  factory ValidateCodeArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ValidateCodeArgs()..mergeFromBuffer(data, registry);
  factory ValidateCodeArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ValidateCodeArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ValidateCodeArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: ValidateCodeArgs.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'datafile')
    ..aOS(2, _omitFieldNames ? '' : 'data')
    ..aOS(3, _omitFieldNames ? '' : 'file')
    ..aOS(4, _omitFieldNames ? '' : 'code')
    ..aOS(5, _omitFieldNames ? '' : 'schema')
    ..aOS(6, _omitFieldNames ? '' : 'attributeName')
    ..aOS(7, _omitFieldNames ? '' : 'format')
    ..pPM<ExternalPkg>(8, _omitFieldNames ? '' : 'externalPkgs',
        subBuilder: ExternalPkg.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ValidateCodeArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ValidateCodeArgs copyWith(void Function(ValidateCodeArgs) updates) =>
      super.copyWith((message) => updates(message as ValidateCodeArgs))
          as ValidateCodeArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ValidateCodeArgs() / ValidateCodeArgs.new instead')
  static ValidateCodeArgs create() => ValidateCodeArgs._();
  static $pb.GeneratedMessage $_createMessage() => ValidateCodeArgs._();
  @$core.override
  ValidateCodeArgs createEmptyInstance() => ValidateCodeArgs._();
  @$core.pragma('dart2js:noInline')
  static ValidateCodeArgs getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ValidateCodeArgs>(
          ValidateCodeArgs.$_createMessage);
  static ValidateCodeArgs? _defaultInstance;

  /// Path to the data file.
  @$pb.TagNumber(1)
  $core.String get datafile => $_getSZ(0);
  @$pb.TagNumber(1)
  set datafile($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDatafile() => $_has(0);
  @$pb.TagNumber(1)
  void clearDatafile() => $_clearField(1);

  /// Data content.
  @$pb.TagNumber(2)
  $core.String get data => $_getSZ(1);
  @$pb.TagNumber(2)
  set data($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);

  /// Path to the code file.
  @$pb.TagNumber(3)
  $core.String get file => $_getSZ(2);
  @$pb.TagNumber(3)
  set file($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFile() => $_has(2);
  @$pb.TagNumber(3)
  void clearFile() => $_clearField(3);

  /// Source code content.
  @$pb.TagNumber(4)
  $core.String get code => $_getSZ(3);
  @$pb.TagNumber(4)
  set code($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCode() => $_has(3);
  @$pb.TagNumber(4)
  void clearCode() => $_clearField(4);

  /// Name of the schema.
  @$pb.TagNumber(5)
  $core.String get schema => $_getSZ(4);
  @$pb.TagNumber(5)
  set schema($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSchema() => $_has(4);
  @$pb.TagNumber(5)
  void clearSchema() => $_clearField(5);

  /// Name of the attribute.
  @$pb.TagNumber(6)
  $core.String get attributeName => $_getSZ(5);
  @$pb.TagNumber(6)
  set attributeName($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAttributeName() => $_has(5);
  @$pb.TagNumber(6)
  void clearAttributeName() => $_clearField(6);

  /// Format of the validation (e.g., "json", "yaml").
  @$pb.TagNumber(7)
  $core.String get format => $_getSZ(6);
  @$pb.TagNumber(7)
  set format($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasFormat() => $_has(6);
  @$pb.TagNumber(7)
  void clearFormat() => $_clearField(7);

  /// List of external packages updated.
  @$pb.TagNumber(8)
  $pb.PbList<ExternalPkg> get externalPkgs => $_getList(7);
}

/// Message for validate code response.
class ValidateCodeResult extends $pb.GeneratedMessage {
  factory ValidateCodeResult({
    $core.bool? success,
    $core.String? errMessage,
  }) {
    final result = ValidateCodeResult._();
    if (success != null) result.success = success;
    if (errMessage != null) result.errMessage = errMessage;
    return result;
  }

  ValidateCodeResult._();

  factory ValidateCodeResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ValidateCodeResult()..mergeFromBuffer(data, registry);
  factory ValidateCodeResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ValidateCodeResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ValidateCodeResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: ValidateCodeResult.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'errMessage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ValidateCodeResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ValidateCodeResult copyWith(void Function(ValidateCodeResult) updates) =>
      super.copyWith((message) => updates(message as ValidateCodeResult))
          as ValidateCodeResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ValidateCodeResult() / ValidateCodeResult.new instead')
  static ValidateCodeResult create() => ValidateCodeResult._();
  static $pb.GeneratedMessage $_createMessage() => ValidateCodeResult._();
  @$core.override
  ValidateCodeResult createEmptyInstance() => ValidateCodeResult._();
  @$core.pragma('dart2js:noInline')
  static ValidateCodeResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ValidateCodeResult>(
          ValidateCodeResult.$_createMessage);
  static ValidateCodeResult? _defaultInstance;

  /// Flag indicating if validation was successful.
  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  /// Error message from validation.
  @$pb.TagNumber(2)
  $core.String get errMessage => $_getSZ(1);
  @$pb.TagNumber(2)
  set errMessage($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasErrMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearErrMessage() => $_clearField(2);
}

/// Message representing a position in the source code.
class Position extends $pb.GeneratedMessage {
  factory Position({
    $fixnum.Int64? line,
    $fixnum.Int64? column,
    $core.String? filename,
  }) {
    final result = Position._();
    if (line != null) result.line = line;
    if (column != null) result.column = column;
    if (filename != null) result.filename = filename;
    return result;
  }

  Position._();

  factory Position.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Position()..mergeFromBuffer(data, registry);
  factory Position.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Position()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Position',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: Position.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'line')
    ..aInt64(2, _omitFieldNames ? '' : 'column')
    ..aOS(3, _omitFieldNames ? '' : 'filename')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Position clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Position copyWith(void Function(Position) updates) =>
      super.copyWith((message) => updates(message as Position)) as Position;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Position() / Position.new instead')
  static Position create() => Position._();
  static $pb.GeneratedMessage $_createMessage() => Position._();
  @$core.override
  Position createEmptyInstance() => Position._();
  @$core.pragma('dart2js:noInline')
  static Position getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Position>(Position.$_createMessage);
  static Position? _defaultInstance;

  /// Line number.
  @$pb.TagNumber(1)
  $fixnum.Int64 get line => $_getI64(0);
  @$pb.TagNumber(1)
  set line($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLine() => $_has(0);
  @$pb.TagNumber(1)
  void clearLine() => $_clearField(1);

  /// Column number.
  @$pb.TagNumber(2)
  $fixnum.Int64 get column => $_getI64(1);
  @$pb.TagNumber(2)
  set column($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasColumn() => $_has(1);
  @$pb.TagNumber(2)
  void clearColumn() => $_clearField(2);

  /// Filename the position refers to.
  @$pb.TagNumber(3)
  $core.String get filename => $_getSZ(2);
  @$pb.TagNumber(3)
  set filename($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFilename() => $_has(2);
  @$pb.TagNumber(3)
  void clearFilename() => $_clearField(3);
}

/// Message for load settings files request arguments.
class LoadSettingsFilesArgs extends $pb.GeneratedMessage {
  factory LoadSettingsFilesArgs({
    $core.String? workDir,
    $core.Iterable<$core.String>? files,
  }) {
    final result = LoadSettingsFilesArgs._();
    if (workDir != null) result.workDir = workDir;
    if (files != null) result.files.addAll(files);
    return result;
  }

  LoadSettingsFilesArgs._();

  factory LoadSettingsFilesArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LoadSettingsFilesArgs()..mergeFromBuffer(data, registry);
  factory LoadSettingsFilesArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LoadSettingsFilesArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoadSettingsFilesArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: LoadSettingsFilesArgs.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'workDir')
    ..pPS(2, _omitFieldNames ? '' : 'files')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadSettingsFilesArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadSettingsFilesArgs copyWith(
          void Function(LoadSettingsFilesArgs) updates) =>
      super.copyWith((message) => updates(message as LoadSettingsFilesArgs))
          as LoadSettingsFilesArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use LoadSettingsFilesArgs() / LoadSettingsFilesArgs.new instead')
  static LoadSettingsFilesArgs create() => LoadSettingsFilesArgs._();
  static $pb.GeneratedMessage $_createMessage() => LoadSettingsFilesArgs._();
  @$core.override
  LoadSettingsFilesArgs createEmptyInstance() => LoadSettingsFilesArgs._();
  @$core.pragma('dart2js:noInline')
  static LoadSettingsFilesArgs getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoadSettingsFilesArgs>(
          LoadSettingsFilesArgs.$_createMessage);
  static LoadSettingsFilesArgs? _defaultInstance;

  /// Working directory.
  @$pb.TagNumber(1)
  $core.String get workDir => $_getSZ(0);
  @$pb.TagNumber(1)
  set workDir($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkDir() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkDir() => $_clearField(1);

  /// Setting files to load.
  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get files => $_getList(1);
}

/// Message for load settings files response.
class LoadSettingsFilesResult extends $pb.GeneratedMessage {
  factory LoadSettingsFilesResult({
    CliConfig? kclCliConfigs,
    $core.Iterable<KeyValuePair>? kclOptions,
  }) {
    final result = LoadSettingsFilesResult._();
    if (kclCliConfigs != null) result.kclCliConfigs = kclCliConfigs;
    if (kclOptions != null) result.kclOptions.addAll(kclOptions);
    return result;
  }

  LoadSettingsFilesResult._();

  factory LoadSettingsFilesResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LoadSettingsFilesResult()..mergeFromBuffer(data, registry);
  factory LoadSettingsFilesResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LoadSettingsFilesResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoadSettingsFilesResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: LoadSettingsFilesResult.$_createMessage)
    ..aOM<CliConfig>(1, _omitFieldNames ? '' : 'kclCliConfigs',
        subBuilder: CliConfig.$_createMessage)
    ..pPM<KeyValuePair>(2, _omitFieldNames ? '' : 'kclOptions',
        subBuilder: KeyValuePair.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadSettingsFilesResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoadSettingsFilesResult copyWith(
          void Function(LoadSettingsFilesResult) updates) =>
      super.copyWith((message) => updates(message as LoadSettingsFilesResult))
          as LoadSettingsFilesResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use LoadSettingsFilesResult() / LoadSettingsFilesResult.new instead')
  static LoadSettingsFilesResult create() => LoadSettingsFilesResult._();
  static $pb.GeneratedMessage $_createMessage() => LoadSettingsFilesResult._();
  @$core.override
  LoadSettingsFilesResult createEmptyInstance() => LoadSettingsFilesResult._();
  @$core.pragma('dart2js:noInline')
  static LoadSettingsFilesResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoadSettingsFilesResult>(
          LoadSettingsFilesResult.$_createMessage);
  static LoadSettingsFilesResult? _defaultInstance;

  /// KCL CLI configuration.
  @$pb.TagNumber(1)
  CliConfig get kclCliConfigs => $_getN(0);
  @$pb.TagNumber(1)
  set kclCliConfigs(CliConfig value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKclCliConfigs() => $_has(0);
  @$pb.TagNumber(1)
  void clearKclCliConfigs() => $_clearField(1);
  @$pb.TagNumber(1)
  CliConfig ensureKclCliConfigs() => $_ensure(0);

  /// List of KCL options as key-value pairs.
  @$pb.TagNumber(2)
  $pb.PbList<KeyValuePair> get kclOptions => $_getList(1);
}

/// Message representing KCL CLI configuration.
class CliConfig extends $pb.GeneratedMessage {
  factory CliConfig({
    $core.Iterable<$core.String>? files,
    $core.String? output,
    $core.Iterable<$core.String>? overrides,
    $core.Iterable<$core.String>? pathSelector,
    $core.bool? strictRangeCheck,
    $core.bool? disableNone,
    $fixnum.Int64? verbose,
    $core.bool? debug,
    $core.bool? sortKeys,
    $core.bool? showHidden,
    $core.bool? includeSchemaTypePath,
    $core.bool? fastEval,
  }) {
    final result = CliConfig._();
    if (files != null) result.files.addAll(files);
    if (output != null) result.output = output;
    if (overrides != null) result.overrides.addAll(overrides);
    if (pathSelector != null) result.pathSelector.addAll(pathSelector);
    if (strictRangeCheck != null) result.strictRangeCheck = strictRangeCheck;
    if (disableNone != null) result.disableNone = disableNone;
    if (verbose != null) result.verbose = verbose;
    if (debug != null) result.debug = debug;
    if (sortKeys != null) result.sortKeys = sortKeys;
    if (showHidden != null) result.showHidden = showHidden;
    if (includeSchemaTypePath != null)
      result.includeSchemaTypePath = includeSchemaTypePath;
    if (fastEval != null) result.fastEval = fastEval;
    return result;
  }

  CliConfig._();

  factory CliConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CliConfig()..mergeFromBuffer(data, registry);
  factory CliConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CliConfig()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CliConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: CliConfig.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'files')
    ..aOS(2, _omitFieldNames ? '' : 'output')
    ..pPS(3, _omitFieldNames ? '' : 'overrides')
    ..pPS(4, _omitFieldNames ? '' : 'pathSelector')
    ..aOB(5, _omitFieldNames ? '' : 'strictRangeCheck')
    ..aOB(6, _omitFieldNames ? '' : 'disableNone')
    ..aInt64(7, _omitFieldNames ? '' : 'verbose')
    ..aOB(8, _omitFieldNames ? '' : 'debug')
    ..aOB(9, _omitFieldNames ? '' : 'sortKeys')
    ..aOB(10, _omitFieldNames ? '' : 'showHidden')
    ..aOB(11, _omitFieldNames ? '' : 'includeSchemaTypePath')
    ..aOB(12, _omitFieldNames ? '' : 'fastEval')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CliConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CliConfig copyWith(void Function(CliConfig) updates) =>
      super.copyWith((message) => updates(message as CliConfig)) as CliConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CliConfig() / CliConfig.new instead')
  static CliConfig create() => CliConfig._();
  static $pb.GeneratedMessage $_createMessage() => CliConfig._();
  @$core.override
  CliConfig createEmptyInstance() => CliConfig._();
  @$core.pragma('dart2js:noInline')
  static CliConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CliConfig>(CliConfig.$_createMessage);
  static CliConfig? _defaultInstance;

  /// List of files.
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get files => $_getList(0);

  /// Output path.
  @$pb.TagNumber(2)
  $core.String get output => $_getSZ(1);
  @$pb.TagNumber(2)
  set output($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOutput() => $_has(1);
  @$pb.TagNumber(2)
  void clearOutput() => $_clearField(2);

  /// List of overrides.
  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get overrides => $_getList(2);

  /// Path selectors.
  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get pathSelector => $_getList(3);

  /// Flag for strict range check.
  @$pb.TagNumber(5)
  $core.bool get strictRangeCheck => $_getBF(4);
  @$pb.TagNumber(5)
  set strictRangeCheck($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStrictRangeCheck() => $_has(4);
  @$pb.TagNumber(5)
  void clearStrictRangeCheck() => $_clearField(5);

  /// Flag to disable none values.
  @$pb.TagNumber(6)
  $core.bool get disableNone => $_getBF(5);
  @$pb.TagNumber(6)
  set disableNone($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDisableNone() => $_has(5);
  @$pb.TagNumber(6)
  void clearDisableNone() => $_clearField(6);

  /// Verbose level.
  @$pb.TagNumber(7)
  $fixnum.Int64 get verbose => $_getI64(6);
  @$pb.TagNumber(7)
  set verbose($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasVerbose() => $_has(6);
  @$pb.TagNumber(7)
  void clearVerbose() => $_clearField(7);

  /// Debug flag.
  @$pb.TagNumber(8)
  $core.bool get debug => $_getBF(7);
  @$pb.TagNumber(8)
  set debug($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasDebug() => $_has(7);
  @$pb.TagNumber(8)
  void clearDebug() => $_clearField(8);

  /// Flag to sort keys in YAML/JSON results.
  @$pb.TagNumber(9)
  $core.bool get sortKeys => $_getBF(8);
  @$pb.TagNumber(9)
  set sortKeys($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSortKeys() => $_has(8);
  @$pb.TagNumber(9)
  void clearSortKeys() => $_clearField(9);

  /// Flag to show hidden attributes.
  @$pb.TagNumber(10)
  $core.bool get showHidden => $_getBF(9);
  @$pb.TagNumber(10)
  set showHidden($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasShowHidden() => $_has(9);
  @$pb.TagNumber(10)
  void clearShowHidden() => $_clearField(10);

  /// Flag to include schema type path in results.
  @$pb.TagNumber(11)
  $core.bool get includeSchemaTypePath => $_getBF(10);
  @$pb.TagNumber(11)
  set includeSchemaTypePath($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasIncludeSchemaTypePath() => $_has(10);
  @$pb.TagNumber(11)
  void clearIncludeSchemaTypePath() => $_clearField(11);

  /// Flag for fast evaluation.
  @$pb.TagNumber(12)
  $core.bool get fastEval => $_getBF(11);
  @$pb.TagNumber(12)
  set fastEval($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasFastEval() => $_has(11);
  @$pb.TagNumber(12)
  void clearFastEval() => $_clearField(12);
}

/// Message representing a key-value pair.
class KeyValuePair extends $pb.GeneratedMessage {
  factory KeyValuePair({
    $core.String? key,
    $core.String? value,
  }) {
    final result = KeyValuePair._();
    if (key != null) result.key = key;
    if (value != null) result.value = value;
    return result;
  }

  KeyValuePair._();

  factory KeyValuePair.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KeyValuePair()..mergeFromBuffer(data, registry);
  factory KeyValuePair.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KeyValuePair()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KeyValuePair',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: KeyValuePair.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..aOS(2, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyValuePair clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyValuePair copyWith(void Function(KeyValuePair) updates) =>
      super.copyWith((message) => updates(message as KeyValuePair))
          as KeyValuePair;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use KeyValuePair() / KeyValuePair.new instead')
  static KeyValuePair create() => KeyValuePair._();
  static $pb.GeneratedMessage $_createMessage() => KeyValuePair._();
  @$core.override
  KeyValuePair createEmptyInstance() => KeyValuePair._();
  @$core.pragma('dart2js:noInline')
  static KeyValuePair getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KeyValuePair>(
          KeyValuePair.$_createMessage);
  static KeyValuePair? _defaultInstance;

  /// Key of the pair.
  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  /// Value of the pair.
  @$pb.TagNumber(2)
  $core.String get value => $_getSZ(1);
  @$pb.TagNumber(2)
  set value($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => $_clearField(2);
}

/// Message for rename request arguments.
class RenameArgs extends $pb.GeneratedMessage {
  factory RenameArgs({
    $core.String? packageRoot,
    $core.String? symbolPath,
    $core.Iterable<$core.String>? filePaths,
    $core.String? newName,
  }) {
    final result = RenameArgs._();
    if (packageRoot != null) result.packageRoot = packageRoot;
    if (symbolPath != null) result.symbolPath = symbolPath;
    if (filePaths != null) result.filePaths.addAll(filePaths);
    if (newName != null) result.newName = newName;
    return result;
  }

  RenameArgs._();

  factory RenameArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameArgs()..mergeFromBuffer(data, registry);
  factory RenameArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenameArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: RenameArgs.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'packageRoot')
    ..aOS(2, _omitFieldNames ? '' : 'symbolPath')
    ..pPS(3, _omitFieldNames ? '' : 'filePaths')
    ..aOS(4, _omitFieldNames ? '' : 'newName')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameArgs copyWith(void Function(RenameArgs) updates) =>
      super.copyWith((message) => updates(message as RenameArgs)) as RenameArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RenameArgs() / RenameArgs.new instead')
  static RenameArgs create() => RenameArgs._();
  static $pb.GeneratedMessage $_createMessage() => RenameArgs._();
  @$core.override
  RenameArgs createEmptyInstance() => RenameArgs._();
  @$core.pragma('dart2js:noInline')
  static RenameArgs getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RenameArgs>(RenameArgs.$_createMessage);
  static RenameArgs? _defaultInstance;

  /// File path to the package root.
  @$pb.TagNumber(1)
  $core.String get packageRoot => $_getSZ(0);
  @$pb.TagNumber(1)
  set packageRoot($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPackageRoot() => $_has(0);
  @$pb.TagNumber(1)
  void clearPackageRoot() => $_clearField(1);

  /// Path to the target symbol to be renamed.
  @$pb.TagNumber(2)
  $core.String get symbolPath => $_getSZ(1);
  @$pb.TagNumber(2)
  set symbolPath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSymbolPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearSymbolPath() => $_clearField(2);

  /// Paths to the source code files.
  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get filePaths => $_getList(2);

  /// New name of the symbol.
  @$pb.TagNumber(4)
  $core.String get newName => $_getSZ(3);
  @$pb.TagNumber(4)
  set newName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNewName() => $_has(3);
  @$pb.TagNumber(4)
  void clearNewName() => $_clearField(4);
}

/// Message for rename response.
class RenameResult extends $pb.GeneratedMessage {
  factory RenameResult({
    $core.Iterable<$core.String>? changedFiles,
  }) {
    final result = RenameResult._();
    if (changedFiles != null) result.changedFiles.addAll(changedFiles);
    return result;
  }

  RenameResult._();

  factory RenameResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameResult()..mergeFromBuffer(data, registry);
  factory RenameResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenameResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: RenameResult.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'changedFiles')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameResult copyWith(void Function(RenameResult) updates) =>
      super.copyWith((message) => updates(message as RenameResult))
          as RenameResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RenameResult() / RenameResult.new instead')
  static RenameResult create() => RenameResult._();
  static $pb.GeneratedMessage $_createMessage() => RenameResult._();
  @$core.override
  RenameResult createEmptyInstance() => RenameResult._();
  @$core.pragma('dart2js:noInline')
  static RenameResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RenameResult>(
          RenameResult.$_createMessage);
  static RenameResult? _defaultInstance;

  /// List of file paths that got changed.
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get changedFiles => $_getList(0);
}

/// Message for rename code request arguments.
class RenameCodeArgs extends $pb.GeneratedMessage {
  factory RenameCodeArgs({
    $core.String? packageRoot,
    $core.String? symbolPath,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? sourceCodes,
    $core.String? newName,
  }) {
    final result = RenameCodeArgs._();
    if (packageRoot != null) result.packageRoot = packageRoot;
    if (symbolPath != null) result.symbolPath = symbolPath;
    if (sourceCodes != null) result.sourceCodes.addEntries(sourceCodes);
    if (newName != null) result.newName = newName;
    return result;
  }

  RenameCodeArgs._();

  factory RenameCodeArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameCodeArgs()..mergeFromBuffer(data, registry);
  factory RenameCodeArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameCodeArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenameCodeArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: RenameCodeArgs.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'packageRoot')
    ..aOS(2, _omitFieldNames ? '' : 'symbolPath')
    ..m<$core.String, $core.String>(3, _omitFieldNames ? '' : 'sourceCodes',
        entryClassName: 'RenameCodeArgs.SourceCodesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('com.kcl.api'))
    ..aOS(4, _omitFieldNames ? '' : 'newName')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameCodeArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameCodeArgs copyWith(void Function(RenameCodeArgs) updates) =>
      super.copyWith((message) => updates(message as RenameCodeArgs))
          as RenameCodeArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RenameCodeArgs() / RenameCodeArgs.new instead')
  static RenameCodeArgs create() => RenameCodeArgs._();
  static $pb.GeneratedMessage $_createMessage() => RenameCodeArgs._();
  @$core.override
  RenameCodeArgs createEmptyInstance() => RenameCodeArgs._();
  @$core.pragma('dart2js:noInline')
  static RenameCodeArgs getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RenameCodeArgs>(
          RenameCodeArgs.$_createMessage);
  static RenameCodeArgs? _defaultInstance;

  /// File path to the package root.
  @$pb.TagNumber(1)
  $core.String get packageRoot => $_getSZ(0);
  @$pb.TagNumber(1)
  set packageRoot($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPackageRoot() => $_has(0);
  @$pb.TagNumber(1)
  void clearPackageRoot() => $_clearField(1);

  /// Path to the target symbol to be renamed.
  @$pb.TagNumber(2)
  $core.String get symbolPath => $_getSZ(1);
  @$pb.TagNumber(2)
  set symbolPath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSymbolPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearSymbolPath() => $_clearField(2);

  /// Map of source code with filename as key and code as value.
  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, $core.String> get sourceCodes => $_getMap(2);

  /// New name of the symbol.
  @$pb.TagNumber(4)
  $core.String get newName => $_getSZ(3);
  @$pb.TagNumber(4)
  set newName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNewName() => $_has(3);
  @$pb.TagNumber(4)
  void clearNewName() => $_clearField(4);
}

/// Message for rename code response.
class RenameCodeResult extends $pb.GeneratedMessage {
  factory RenameCodeResult({
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? changedCodes,
  }) {
    final result = RenameCodeResult._();
    if (changedCodes != null) result.changedCodes.addEntries(changedCodes);
    return result;
  }

  RenameCodeResult._();

  factory RenameCodeResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameCodeResult()..mergeFromBuffer(data, registry);
  factory RenameCodeResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameCodeResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenameCodeResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: RenameCodeResult.$_createMessage)
    ..m<$core.String, $core.String>(1, _omitFieldNames ? '' : 'changedCodes',
        entryClassName: 'RenameCodeResult.ChangedCodesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('com.kcl.api'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameCodeResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameCodeResult copyWith(void Function(RenameCodeResult) updates) =>
      super.copyWith((message) => updates(message as RenameCodeResult))
          as RenameCodeResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RenameCodeResult() / RenameCodeResult.new instead')
  static RenameCodeResult create() => RenameCodeResult._();
  static $pb.GeneratedMessage $_createMessage() => RenameCodeResult._();
  @$core.override
  RenameCodeResult createEmptyInstance() => RenameCodeResult._();
  @$core.pragma('dart2js:noInline')
  static RenameCodeResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RenameCodeResult>(
          RenameCodeResult.$_createMessage);
  static RenameCodeResult? _defaultInstance;

  /// Map of changed code with filename as key and modified code as value.
  @$pb.TagNumber(1)
  $pb.PbMap<$core.String, $core.String> get changedCodes => $_getMap(0);
}

/// Message for test request arguments.
class TestArgs extends $pb.GeneratedMessage {
  factory TestArgs({
    ExecProgramArgs? execArgs,
    $core.Iterable<$core.String>? pkgList,
    $core.String? runRegexp,
    $core.bool? failFast,
    $core.bool? coverage,
  }) {
    final result = TestArgs._();
    if (execArgs != null) result.execArgs = execArgs;
    if (pkgList != null) result.pkgList.addAll(pkgList);
    if (runRegexp != null) result.runRegexp = runRegexp;
    if (failFast != null) result.failFast = failFast;
    if (coverage != null) result.coverage = coverage;
    return result;
  }

  TestArgs._();

  factory TestArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestArgs()..mergeFromBuffer(data, registry);
  factory TestArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TestArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: TestArgs.$_createMessage)
    ..aOM<ExecProgramArgs>(1, _omitFieldNames ? '' : 'execArgs',
        subBuilder: ExecProgramArgs.$_createMessage)
    ..pPS(2, _omitFieldNames ? '' : 'pkgList')
    ..aOS(3, _omitFieldNames ? '' : 'runRegexp')
    ..aOB(4, _omitFieldNames ? '' : 'failFast')
    ..aOB(5, _omitFieldNames ? '' : 'coverage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestArgs copyWith(void Function(TestArgs) updates) =>
      super.copyWith((message) => updates(message as TestArgs)) as TestArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TestArgs() / TestArgs.new instead')
  static TestArgs create() => TestArgs._();
  static $pb.GeneratedMessage $_createMessage() => TestArgs._();
  @$core.override
  TestArgs createEmptyInstance() => TestArgs._();
  @$core.pragma('dart2js:noInline')
  static TestArgs getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TestArgs>(TestArgs.$_createMessage);
  static TestArgs? _defaultInstance;

  /// Execution program arguments.
  @$pb.TagNumber(1)
  ExecProgramArgs get execArgs => $_getN(0);
  @$pb.TagNumber(1)
  set execArgs(ExecProgramArgs value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasExecArgs() => $_has(0);
  @$pb.TagNumber(1)
  void clearExecArgs() => $_clearField(1);
  @$pb.TagNumber(1)
  ExecProgramArgs ensureExecArgs() => $_ensure(0);

  /// List of KCL package paths to be tested.
  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get pkgList => $_getList(1);

  /// Regular expression for filtering tests to run.
  @$pb.TagNumber(3)
  $core.String get runRegexp => $_getSZ(2);
  @$pb.TagNumber(3)
  set runRegexp($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRunRegexp() => $_has(2);
  @$pb.TagNumber(3)
  void clearRunRegexp() => $_clearField(3);

  /// Flag to stop the test run on the first failure.
  @$pb.TagNumber(4)
  $core.bool get failFast => $_getBF(3);
  @$pb.TagNumber(4)
  set failFast($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFailFast() => $_has(3);
  @$pb.TagNumber(4)
  void clearFailFast() => $_clearField(4);

  /// Flag to collect line-level coverage data while running tests. When true,
  /// the test tool records, for every top-level KCL statement that executes,
  /// the source file path and line number. The aggregated result is returned
  /// in [TestResult.coverage]. Defaults to false.
  @$pb.TagNumber(5)
  $core.bool get coverage => $_getBF(4);
  @$pb.TagNumber(5)
  set coverage($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCoverage() => $_has(4);
  @$pb.TagNumber(5)
  void clearCoverage() => $_clearField(5);
}

/// Message for test response.
class TestResult extends $pb.GeneratedMessage {
  factory TestResult({
    $core.Iterable<TestCaseInfo>? info,
    TestCoverageReport? coverage,
  }) {
    final result = TestResult._();
    if (info != null) result.info.addAll(info);
    if (coverage != null) result.coverage = coverage;
    return result;
  }

  TestResult._();

  factory TestResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestResult()..mergeFromBuffer(data, registry);
  factory TestResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TestResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: TestResult.$_createMessage)
    ..pPM<TestCaseInfo>(2, _omitFieldNames ? '' : 'info',
        subBuilder: TestCaseInfo.$_createMessage)
    ..aOM<TestCoverageReport>(3, _omitFieldNames ? '' : 'coverage',
        subBuilder: TestCoverageReport.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestResult copyWith(void Function(TestResult) updates) =>
      super.copyWith((message) => updates(message as TestResult)) as TestResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TestResult() / TestResult.new instead')
  static TestResult create() => TestResult._();
  static $pb.GeneratedMessage $_createMessage() => TestResult._();
  @$core.override
  TestResult createEmptyInstance() => TestResult._();
  @$core.pragma('dart2js:noInline')
  static TestResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TestResult>(TestResult.$_createMessage);
  static TestResult? _defaultInstance;

  /// List of test case information.
  @$pb.TagNumber(2)
  $pb.PbList<TestCaseInfo> get info => $_getList(0);

  /// Aggregated coverage report. Populated only when
  /// [TestArgs.coverage] is true; empty otherwise.
  @$pb.TagNumber(3)
  TestCoverageReport get coverage => $_getN(1);
  @$pb.TagNumber(3)
  set coverage(TestCoverageReport value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasCoverage() => $_has(1);
  @$pb.TagNumber(3)
  void clearCoverage() => $_clearField(3);
  @$pb.TagNumber(3)
  TestCoverageReport ensureCoverage() => $_ensure(1);
}

/// Message representing information about a single test case.
class TestCaseInfo extends $pb.GeneratedMessage {
  factory TestCaseInfo({
    $core.String? name,
    $core.String? error,
    $fixnum.Int64? duration,
    $core.String? logMessage,
    $core.Iterable<$core.MapEntry<$core.String, $fixnum.Int64>>? lineHits,
  }) {
    final result = TestCaseInfo._();
    if (name != null) result.name = name;
    if (error != null) result.error = error;
    if (duration != null) result.duration = duration;
    if (logMessage != null) result.logMessage = logMessage;
    if (lineHits != null) result.lineHits.addEntries(lineHits);
    return result;
  }

  TestCaseInfo._();

  factory TestCaseInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestCaseInfo()..mergeFromBuffer(data, registry);
  factory TestCaseInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestCaseInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TestCaseInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: TestCaseInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'error')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'duration', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(4, _omitFieldNames ? '' : 'logMessage')
    ..m<$core.String, $fixnum.Int64>(5, _omitFieldNames ? '' : 'lineHits',
        entryClassName: 'TestCaseInfo.LineHitsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OU6,
        packageName: const $pb.PackageName('com.kcl.api'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestCaseInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestCaseInfo copyWith(void Function(TestCaseInfo) updates) =>
      super.copyWith((message) => updates(message as TestCaseInfo))
          as TestCaseInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TestCaseInfo() / TestCaseInfo.new instead')
  static TestCaseInfo create() => TestCaseInfo._();
  static $pb.GeneratedMessage $_createMessage() => TestCaseInfo._();
  @$core.override
  TestCaseInfo createEmptyInstance() => TestCaseInfo._();
  @$core.pragma('dart2js:noInline')
  static TestCaseInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TestCaseInfo>(
          TestCaseInfo.$_createMessage);
  static TestCaseInfo? _defaultInstance;

  /// Name of the test case.
  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  /// Error message if any.
  @$pb.TagNumber(2)
  $core.String get error => $_getSZ(1);
  @$pb.TagNumber(2)
  set error($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);

  /// Duration of the test case in microseconds.
  @$pb.TagNumber(3)
  $fixnum.Int64 get duration => $_getI64(2);
  @$pb.TagNumber(3)
  set duration($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDuration() => $_has(2);
  @$pb.TagNumber(3)
  void clearDuration() => $_clearField(3);

  /// Log message from the test case.
  @$pb.TagNumber(4)
  $core.String get logMessage => $_getSZ(3);
  @$pb.TagNumber(4)
  set logMessage($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLogMessage() => $_has(3);
  @$pb.TagNumber(4)
  void clearLogMessage() => $_clearField(4);

  /// Per-case line coverage. Populated only when [TestArgs.coverage]
  /// is true; empty otherwise. Each entry maps "filename:line" to the
  /// number of times that line was entered while running this case.
  @$pb.TagNumber(5)
  $pb.PbMap<$core.String, $fixnum.Int64> get lineHits => $_getMap(4);
}

/// Message describing aggregated coverage data for a single source file.
class FileCoverage extends $pb.GeneratedMessage {
  factory FileCoverage({
    $core.String? filename,
    $core.Iterable<$fixnum.Int64>? coveredLines,
    $core.Iterable<$fixnum.Int64>? executableLines,
    $core.Iterable<$core.MapEntry<$fixnum.Int64, $fixnum.Int64>>? lineHits,
  }) {
    final result = FileCoverage._();
    if (filename != null) result.filename = filename;
    if (coveredLines != null) result.coveredLines.addAll(coveredLines);
    if (executableLines != null) result.executableLines.addAll(executableLines);
    if (lineHits != null) result.lineHits.addEntries(lineHits);
    return result;
  }

  FileCoverage._();

  factory FileCoverage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FileCoverage()..mergeFromBuffer(data, registry);
  factory FileCoverage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FileCoverage()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FileCoverage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: FileCoverage.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'filename')
    ..p<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'coveredLines', $pb.PbFieldType.KU6)
    ..p<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'executableLines', $pb.PbFieldType.KU6)
    ..m<$fixnum.Int64, $fixnum.Int64>(4, _omitFieldNames ? '' : 'lineHits',
        entryClassName: 'FileCoverage.LineHitsEntry',
        keyFieldType: $pb.PbFieldType.OU6,
        valueFieldType: $pb.PbFieldType.OU6,
        packageName: const $pb.PackageName('com.kcl.api'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FileCoverage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FileCoverage copyWith(void Function(FileCoverage) updates) =>
      super.copyWith((message) => updates(message as FileCoverage))
          as FileCoverage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FileCoverage() / FileCoverage.new instead')
  static FileCoverage create() => FileCoverage._();
  static $pb.GeneratedMessage $_createMessage() => FileCoverage._();
  @$core.override
  FileCoverage createEmptyInstance() => FileCoverage._();
  @$core.pragma('dart2js:noInline')
  static FileCoverage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FileCoverage>(
          FileCoverage.$_createMessage);
  static FileCoverage? _defaultInstance;

  /// Source file path, relative to the package root when possible.
  @$pb.TagNumber(1)
  $core.String get filename => $_getSZ(0);
  @$pb.TagNumber(1)
  set filename($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFilename() => $_has(0);
  @$pb.TagNumber(1)
  void clearFilename() => $_clearField(1);

  /// Sorted list of lines that executed at least once across all tests
  /// that covered this file.
  @$pb.TagNumber(2)
  $pb.PbList<$fixnum.Int64> get coveredLines => $_getList(1);

  /// Sorted list of lines in this file that contain an executable
  /// statement (i.e. lines that *could* be covered). Lines that contain
  /// only blank lines, comments or non-executable tokens are excluded.
  @$pb.TagNumber(3)
  $pb.PbList<$fixnum.Int64> get executableLines => $_getList(2);

  /// Per-line execution count across all tests that covered this file.
  /// Keys are line numbers (1-based); values are hit counts.
  @$pb.TagNumber(4)
  $pb.PbMap<$fixnum.Int64, $fixnum.Int64> get lineHits => $_getMap(3);
}

/// Message describing aggregated coverage across the entire test run.
class TestCoverageReport extends $pb.GeneratedMessage {
  factory TestCoverageReport({
    $core.Iterable<$core.MapEntry<$core.String, FileCoverage>>? files,
    CoverageSummary? summary,
  }) {
    final result = TestCoverageReport._();
    if (files != null) result.files.addEntries(files);
    if (summary != null) result.summary = summary;
    return result;
  }

  TestCoverageReport._();

  factory TestCoverageReport.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestCoverageReport()..mergeFromBuffer(data, registry);
  factory TestCoverageReport.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TestCoverageReport()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TestCoverageReport',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: TestCoverageReport.$_createMessage)
    ..m<$core.String, FileCoverage>(1, _omitFieldNames ? '' : 'files',
        entryClassName: 'TestCoverageReport.FilesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: FileCoverage.$_createMessage,
        valueDefaultOrMaker: FileCoverage.getDefault,
        packageName: const $pb.PackageName('com.kcl.api'))
    ..aOM<CoverageSummary>(2, _omitFieldNames ? '' : 'summary',
        subBuilder: CoverageSummary.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestCoverageReport clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestCoverageReport copyWith(void Function(TestCoverageReport) updates) =>
      super.copyWith((message) => updates(message as TestCoverageReport))
          as TestCoverageReport;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TestCoverageReport() / TestCoverageReport.new instead')
  static TestCoverageReport create() => TestCoverageReport._();
  static $pb.GeneratedMessage $_createMessage() => TestCoverageReport._();
  @$core.override
  TestCoverageReport createEmptyInstance() => TestCoverageReport._();
  @$core.pragma('dart2js:noInline')
  static TestCoverageReport getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TestCoverageReport>(
          TestCoverageReport.$_createMessage);
  static TestCoverageReport? _defaultInstance;

  /// Per-file coverage keyed by source file path.
  @$pb.TagNumber(1)
  $pb.PbMap<$core.String, FileCoverage> get files => $_getMap(0);

  /// Roll-up of all files in [TestCoverageReport.files].
  @$pb.TagNumber(2)
  CoverageSummary get summary => $_getN(1);
  @$pb.TagNumber(2)
  set summary(CoverageSummary value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSummary() => $_has(1);
  @$pb.TagNumber(2)
  void clearSummary() => $_clearField(2);
  @$pb.TagNumber(2)
  CoverageSummary ensureSummary() => $_ensure(1);
}

/// Roll-up coverage metrics.
class CoverageSummary extends $pb.GeneratedMessage {
  factory CoverageSummary({
    $fixnum.Int64? covered,
    $fixnum.Int64? executable,
    $core.double? percent,
  }) {
    final result = CoverageSummary._();
    if (covered != null) result.covered = covered;
    if (executable != null) result.executable = executable;
    if (percent != null) result.percent = percent;
    return result;
  }

  CoverageSummary._();

  factory CoverageSummary.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CoverageSummary()..mergeFromBuffer(data, registry);
  factory CoverageSummary.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CoverageSummary()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CoverageSummary',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: CoverageSummary.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'covered', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'executable', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aD(3, _omitFieldNames ? '' : 'percent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CoverageSummary clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CoverageSummary copyWith(void Function(CoverageSummary) updates) =>
      super.copyWith((message) => updates(message as CoverageSummary))
          as CoverageSummary;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CoverageSummary() / CoverageSummary.new instead')
  static CoverageSummary create() => CoverageSummary._();
  static $pb.GeneratedMessage $_createMessage() => CoverageSummary._();
  @$core.override
  CoverageSummary createEmptyInstance() => CoverageSummary._();
  @$core.pragma('dart2js:noInline')
  static CoverageSummary getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CoverageSummary>(
          CoverageSummary.$_createMessage);
  static CoverageSummary? _defaultInstance;

  /// Number of executable lines that were hit by at least one test.
  @$pb.TagNumber(1)
  $fixnum.Int64 get covered => $_getI64(0);
  @$pb.TagNumber(1)
  set covered($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCovered() => $_has(0);
  @$pb.TagNumber(1)
  void clearCovered() => $_clearField(1);

  /// Total number of executable lines discovered.
  @$pb.TagNumber(2)
  $fixnum.Int64 get executable => $_getI64(1);
  @$pb.TagNumber(2)
  set executable($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExecutable() => $_has(1);
  @$pb.TagNumber(2)
  void clearExecutable() => $_clearField(2);

  /// Coverage percentage in the inclusive range [0.0, 100.0].
  @$pb.TagNumber(3)
  $core.double get percent => $_getN(2);
  @$pb.TagNumber(3)
  set percent($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPercent() => $_has(2);
  @$pb.TagNumber(3)
  void clearPercent() => $_clearField(3);
}

/// Message for format test report request arguments.
class FormatTestReportArgs extends $pb.GeneratedMessage {
  factory FormatTestReportArgs({
    TestResult? result,
  }) {
    final result$ = FormatTestReportArgs._();
    if (result != null) result$.result = result;
    return result$;
  }

  FormatTestReportArgs._();

  factory FormatTestReportArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FormatTestReportArgs()..mergeFromBuffer(data, registry);
  factory FormatTestReportArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FormatTestReportArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FormatTestReportArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: FormatTestReportArgs.$_createMessage)
    ..aOM<TestResult>(1, _omitFieldNames ? '' : 'result',
        subBuilder: TestResult.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FormatTestReportArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FormatTestReportArgs copyWith(void Function(FormatTestReportArgs) updates) =>
      super.copyWith((message) => updates(message as FormatTestReportArgs))
          as FormatTestReportArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use FormatTestReportArgs() / FormatTestReportArgs.new instead')
  static FormatTestReportArgs create() => FormatTestReportArgs._();
  static $pb.GeneratedMessage $_createMessage() => FormatTestReportArgs._();
  @$core.override
  FormatTestReportArgs createEmptyInstance() => FormatTestReportArgs._();
  @$core.pragma('dart2js:noInline')
  static FormatTestReportArgs getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FormatTestReportArgs>(
          FormatTestReportArgs.$_createMessage);
  static FormatTestReportArgs? _defaultInstance;

  /// The test result to format, as returned by the Test RPC.
  @$pb.TagNumber(1)
  TestResult get result => $_getN(0);
  @$pb.TagNumber(1)
  set result(TestResult value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasResult() => $_has(0);
  @$pb.TagNumber(1)
  void clearResult() => $_clearField(1);
  @$pb.TagNumber(1)
  TestResult ensureResult() => $_ensure(0);
}

/// Message for format test report response.
class FormatTestReportResult extends $pb.GeneratedMessage {
  factory FormatTestReportResult({
    $core.String? report,
  }) {
    final result = FormatTestReportResult._();
    if (report != null) result.report = report;
    return result;
  }

  FormatTestReportResult._();

  factory FormatTestReportResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FormatTestReportResult()..mergeFromBuffer(data, registry);
  factory FormatTestReportResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FormatTestReportResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FormatTestReportResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: FormatTestReportResult.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'report')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FormatTestReportResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FormatTestReportResult copyWith(
          void Function(FormatTestReportResult) updates) =>
      super.copyWith((message) => updates(message as FormatTestReportResult))
          as FormatTestReportResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use FormatTestReportResult() / FormatTestReportResult.new instead')
  static FormatTestReportResult create() => FormatTestReportResult._();
  static $pb.GeneratedMessage $_createMessage() => FormatTestReportResult._();
  @$core.override
  FormatTestReportResult createEmptyInstance() => FormatTestReportResult._();
  @$core.pragma('dart2js:noInline')
  static FormatTestReportResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FormatTestReportResult>(
          FormatTestReportResult.$_createMessage);
  static FormatTestReportResult? _defaultInstance;

  /// The pretty-printed report (see PrettyReporter format docs above).
  @$pb.TagNumber(1)
  $core.String get report => $_getSZ(0);
  @$pb.TagNumber(1)
  set report($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReport() => $_has(0);
  @$pb.TagNumber(1)
  void clearReport() => $_clearField(1);
}

/// Message for update dependencies request arguments.
class UpdateDependenciesArgs extends $pb.GeneratedMessage {
  factory UpdateDependenciesArgs({
    $core.String? manifestPath,
    $core.bool? vendor,
  }) {
    final result = UpdateDependenciesArgs._();
    if (manifestPath != null) result.manifestPath = manifestPath;
    if (vendor != null) result.vendor = vendor;
    return result;
  }

  UpdateDependenciesArgs._();

  factory UpdateDependenciesArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateDependenciesArgs()..mergeFromBuffer(data, registry);
  factory UpdateDependenciesArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateDependenciesArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateDependenciesArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: UpdateDependenciesArgs.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'manifestPath')
    ..aOB(2, _omitFieldNames ? '' : 'vendor')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateDependenciesArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateDependenciesArgs copyWith(
          void Function(UpdateDependenciesArgs) updates) =>
      super.copyWith((message) => updates(message as UpdateDependenciesArgs))
          as UpdateDependenciesArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use UpdateDependenciesArgs() / UpdateDependenciesArgs.new instead')
  static UpdateDependenciesArgs create() => UpdateDependenciesArgs._();
  static $pb.GeneratedMessage $_createMessage() => UpdateDependenciesArgs._();
  @$core.override
  UpdateDependenciesArgs createEmptyInstance() => UpdateDependenciesArgs._();
  @$core.pragma('dart2js:noInline')
  static UpdateDependenciesArgs getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateDependenciesArgs>(
          UpdateDependenciesArgs.$_createMessage);
  static UpdateDependenciesArgs? _defaultInstance;

  /// Path to the manifest file.
  @$pb.TagNumber(1)
  $core.String get manifestPath => $_getSZ(0);
  @$pb.TagNumber(1)
  set manifestPath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasManifestPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearManifestPath() => $_clearField(1);

  /// Flag to vendor dependencies locally.
  @$pb.TagNumber(2)
  $core.bool get vendor => $_getBF(1);
  @$pb.TagNumber(2)
  set vendor($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVendor() => $_has(1);
  @$pb.TagNumber(2)
  void clearVendor() => $_clearField(2);
}

/// Message for update dependencies response.
class UpdateDependenciesResult extends $pb.GeneratedMessage {
  factory UpdateDependenciesResult({
    $core.Iterable<ExternalPkg>? externalPkgs,
  }) {
    final result = UpdateDependenciesResult._();
    if (externalPkgs != null) result.externalPkgs.addAll(externalPkgs);
    return result;
  }

  UpdateDependenciesResult._();

  factory UpdateDependenciesResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateDependenciesResult()..mergeFromBuffer(data, registry);
  factory UpdateDependenciesResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateDependenciesResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateDependenciesResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: UpdateDependenciesResult.$_createMessage)
    ..pPM<ExternalPkg>(3, _omitFieldNames ? '' : 'externalPkgs',
        subBuilder: ExternalPkg.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateDependenciesResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateDependenciesResult copyWith(
          void Function(UpdateDependenciesResult) updates) =>
      super.copyWith((message) => updates(message as UpdateDependenciesResult))
          as UpdateDependenciesResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use UpdateDependenciesResult() / UpdateDependenciesResult.new instead')
  static UpdateDependenciesResult create() => UpdateDependenciesResult._();
  static $pb.GeneratedMessage $_createMessage() => UpdateDependenciesResult._();
  @$core.override
  UpdateDependenciesResult createEmptyInstance() =>
      UpdateDependenciesResult._();
  @$core.pragma('dart2js:noInline')
  static UpdateDependenciesResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateDependenciesResult>(
          UpdateDependenciesResult.$_createMessage);
  static UpdateDependenciesResult? _defaultInstance;

  /// List of external packages updated.
  @$pb.TagNumber(3)
  $pb.PbList<ExternalPkg> get externalPkgs => $_getList(0);
}

/// Message for generate TOML request arguments.
class GenerateTomlArgs extends $pb.GeneratedMessage {
  factory GenerateTomlArgs({
    ExecProgramArgs? execArgs,
    $core.bool? sortKeys,
  }) {
    final result = GenerateTomlArgs._();
    if (execArgs != null) result.execArgs = execArgs;
    if (sortKeys != null) result.sortKeys = sortKeys;
    return result;
  }

  GenerateTomlArgs._();

  factory GenerateTomlArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateTomlArgs()..mergeFromBuffer(data, registry);
  factory GenerateTomlArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateTomlArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateTomlArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: GenerateTomlArgs.$_createMessage)
    ..aOM<ExecProgramArgs>(1, _omitFieldNames ? '' : 'execArgs',
        subBuilder: ExecProgramArgs.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'sortKeys')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateTomlArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateTomlArgs copyWith(void Function(GenerateTomlArgs) updates) =>
      super.copyWith((message) => updates(message as GenerateTomlArgs))
          as GenerateTomlArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GenerateTomlArgs() / GenerateTomlArgs.new instead')
  static GenerateTomlArgs create() => GenerateTomlArgs._();
  static $pb.GeneratedMessage $_createMessage() => GenerateTomlArgs._();
  @$core.override
  GenerateTomlArgs createEmptyInstance() => GenerateTomlArgs._();
  @$core.pragma('dart2js:noInline')
  static GenerateTomlArgs getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GenerateTomlArgs>(
          GenerateTomlArgs.$_createMessage);
  static GenerateTomlArgs? _defaultInstance;

  /// Arguments for executing the program whose result is serialized to TOML.
  @$pb.TagNumber(1)
  ExecProgramArgs get execArgs => $_getN(0);
  @$pb.TagNumber(1)
  set execArgs(ExecProgramArgs value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasExecArgs() => $_has(0);
  @$pb.TagNumber(1)
  void clearExecArgs() => $_clearField(1);
  @$pb.TagNumber(1)
  ExecProgramArgs ensureExecArgs() => $_ensure(0);

  /// Flag to sort keys in the TOML output. Defaults to false (source order).
  @$pb.TagNumber(2)
  $core.bool get sortKeys => $_getBF(1);
  @$pb.TagNumber(2)
  set sortKeys($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSortKeys() => $_has(1);
  @$pb.TagNumber(2)
  void clearSortKeys() => $_clearField(2);
}

/// Message for generate TOML response.
class GenerateTomlResult extends $pb.GeneratedMessage {
  factory GenerateTomlResult({
    $core.String? toml,
  }) {
    final result = GenerateTomlResult._();
    if (toml != null) result.toml = toml;
    return result;
  }

  GenerateTomlResult._();

  factory GenerateTomlResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateTomlResult()..mergeFromBuffer(data, registry);
  factory GenerateTomlResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateTomlResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateTomlResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: GenerateTomlResult.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'toml')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateTomlResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateTomlResult copyWith(void Function(GenerateTomlResult) updates) =>
      super.copyWith((message) => updates(message as GenerateTomlResult))
          as GenerateTomlResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GenerateTomlResult() / GenerateTomlResult.new instead')
  static GenerateTomlResult create() => GenerateTomlResult._();
  static $pb.GeneratedMessage $_createMessage() => GenerateTomlResult._();
  @$core.override
  GenerateTomlResult createEmptyInstance() => GenerateTomlResult._();
  @$core.pragma('dart2js:noInline')
  static GenerateTomlResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateTomlResult>(
          GenerateTomlResult.$_createMessage);
  static GenerateTomlResult? _defaultInstance;

  /// The evaluated result serialized as TOML.
  @$pb.TagNumber(1)
  $core.String get toml => $_getSZ(0);
  @$pb.TagNumber(1)
  set toml($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToml() => $_has(0);
  @$pb.TagNumber(1)
  void clearToml() => $_clearField(1);
}

/// Message for generate KCL request arguments.
class GenerateKclArgs extends $pb.GeneratedMessage {
  factory GenerateKclArgs({
    $core.String? source,
    $core.String? filename,
    $core.String? format,
  }) {
    final result = GenerateKclArgs._();
    if (source != null) result.source = source;
    if (filename != null) result.filename = filename;
    if (format != null) result.format = format;
    return result;
  }

  GenerateKclArgs._();

  factory GenerateKclArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateKclArgs()..mergeFromBuffer(data, registry);
  factory GenerateKclArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateKclArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateKclArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: GenerateKclArgs.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'source')
    ..aOS(2, _omitFieldNames ? '' : 'filename')
    ..aOS(3, _omitFieldNames ? '' : 'format')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateKclArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateKclArgs copyWith(void Function(GenerateKclArgs) updates) =>
      super.copyWith((message) => updates(message as GenerateKclArgs))
          as GenerateKclArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GenerateKclArgs() / GenerateKclArgs.new instead')
  static GenerateKclArgs create() => GenerateKclArgs._();
  static $pb.GeneratedMessage $_createMessage() => GenerateKclArgs._();
  @$core.override
  GenerateKclArgs createEmptyInstance() => GenerateKclArgs._();
  @$core.pragma('dart2js:noInline')
  static GenerateKclArgs getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GenerateKclArgs>(
          GenerateKclArgs.$_createMessage);
  static GenerateKclArgs? _defaultInstance;

  /// The source data content (JSON, YAML or TOML text).
  @$pb.TagNumber(1)
  $core.String get source => $_getSZ(0);
  @$pb.TagNumber(1)
  set source($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSource() => $_has(0);
  @$pb.TagNumber(1)
  void clearSource() => $_clearField(1);

  /// File name hint used for error messages and format detection, e.g. "data.json".
  @$pb.TagNumber(2)
  $core.String get filename => $_getSZ(1);
  @$pb.TagNumber(2)
  set filename($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFilename() => $_has(1);
  @$pb.TagNumber(2)
  void clearFilename() => $_clearField(2);

  /// Data format: "json", "yaml" or "toml". When empty, inferred from the
  /// filename extension, defaulting to "json".
  @$pb.TagNumber(3)
  $core.String get format => $_getSZ(2);
  @$pb.TagNumber(3)
  set format($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFormat() => $_has(2);
  @$pb.TagNumber(3)
  void clearFormat() => $_clearField(3);
}

/// Message for generate KCL response.
class GenerateKclResult extends $pb.GeneratedMessage {
  factory GenerateKclResult({
    $core.String? kcl,
  }) {
    final result = GenerateKclResult._();
    if (kcl != null) result.kcl = kcl;
    return result;
  }

  GenerateKclResult._();

  factory GenerateKclResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateKclResult()..mergeFromBuffer(data, registry);
  factory GenerateKclResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateKclResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateKclResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: GenerateKclResult.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'kcl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateKclResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateKclResult copyWith(void Function(GenerateKclResult) updates) =>
      super.copyWith((message) => updates(message as GenerateKclResult))
          as GenerateKclResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GenerateKclResult() / GenerateKclResult.new instead')
  static GenerateKclResult create() => GenerateKclResult._();
  static $pb.GeneratedMessage $_createMessage() => GenerateKclResult._();
  @$core.override
  GenerateKclResult createEmptyInstance() => GenerateKclResult._();
  @$core.pragma('dart2js:noInline')
  static GenerateKclResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GenerateKclResult>(
          GenerateKclResult.$_createMessage);
  static GenerateKclResult? _defaultInstance;

  /// The generated KCL source.
  @$pb.TagNumber(1)
  $core.String get kcl => $_getSZ(0);
  @$pb.TagNumber(1)
  set kcl($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKcl() => $_has(0);
  @$pb.TagNumber(1)
  void clearKcl() => $_clearField(1);
}

/// Message for generate OpenAPI request arguments.
class GenerateOpenAPIArgs extends $pb.GeneratedMessage {
  factory GenerateOpenAPIArgs({
    ParseProgramArgs? parseArgs,
    $core.String? version,
  }) {
    final result = GenerateOpenAPIArgs._();
    if (parseArgs != null) result.parseArgs = parseArgs;
    if (version != null) result.version = version;
    return result;
  }

  GenerateOpenAPIArgs._();

  factory GenerateOpenAPIArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateOpenAPIArgs()..mergeFromBuffer(data, registry);
  factory GenerateOpenAPIArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateOpenAPIArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateOpenAPIArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: GenerateOpenAPIArgs.$_createMessage)
    ..aOM<ParseProgramArgs>(1, _omitFieldNames ? '' : 'parseArgs',
        subBuilder: ParseProgramArgs.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'version')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateOpenAPIArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateOpenAPIArgs copyWith(void Function(GenerateOpenAPIArgs) updates) =>
      super.copyWith((message) => updates(message as GenerateOpenAPIArgs))
          as GenerateOpenAPIArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use GenerateOpenAPIArgs() / GenerateOpenAPIArgs.new instead')
  static GenerateOpenAPIArgs create() => GenerateOpenAPIArgs._();
  static $pb.GeneratedMessage $_createMessage() => GenerateOpenAPIArgs._();
  @$core.override
  GenerateOpenAPIArgs createEmptyInstance() => GenerateOpenAPIArgs._();
  @$core.pragma('dart2js:noInline')
  static GenerateOpenAPIArgs getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateOpenAPIArgs>(
          GenerateOpenAPIArgs.$_createMessage);
  static GenerateOpenAPIArgs? _defaultInstance;

  /// Arguments for parsing the program whose schemas are exported.
  @$pb.TagNumber(1)
  ParseProgramArgs get parseArgs => $_getN(0);
  @$pb.TagNumber(1)
  set parseArgs(ParseProgramArgs value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasParseArgs() => $_has(0);
  @$pb.TagNumber(1)
  void clearParseArgs() => $_clearField(1);
  @$pb.TagNumber(1)
  ParseProgramArgs ensureParseArgs() => $_ensure(0);

  /// Spec version: "v3" (default) or "v2" (Swagger 2.0).
  @$pb.TagNumber(2)
  $core.String get version => $_getSZ(1);
  @$pb.TagNumber(2)
  set version($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearVersion() => $_clearField(2);
}

/// Message for generate OpenAPI response.
class GenerateOpenAPIResult extends $pb.GeneratedMessage {
  factory GenerateOpenAPIResult({
    $core.String? spec,
  }) {
    final result = GenerateOpenAPIResult._();
    if (spec != null) result.spec = spec;
    return result;
  }

  GenerateOpenAPIResult._();

  factory GenerateOpenAPIResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateOpenAPIResult()..mergeFromBuffer(data, registry);
  factory GenerateOpenAPIResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateOpenAPIResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateOpenAPIResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: GenerateOpenAPIResult.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'spec')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateOpenAPIResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateOpenAPIResult copyWith(
          void Function(GenerateOpenAPIResult) updates) =>
      super.copyWith((message) => updates(message as GenerateOpenAPIResult))
          as GenerateOpenAPIResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GenerateOpenAPIResult() / GenerateOpenAPIResult.new instead')
  static GenerateOpenAPIResult create() => GenerateOpenAPIResult._();
  static $pb.GeneratedMessage $_createMessage() => GenerateOpenAPIResult._();
  @$core.override
  GenerateOpenAPIResult createEmptyInstance() => GenerateOpenAPIResult._();
  @$core.pragma('dart2js:noInline')
  static GenerateOpenAPIResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateOpenAPIResult>(
          GenerateOpenAPIResult.$_createMessage);
  static GenerateOpenAPIResult? _defaultInstance;

  /// The generated spec as a JSON string.
  @$pb.TagNumber(1)
  $core.String get spec => $_getSZ(0);
  @$pb.TagNumber(1)
  set spec($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSpec() => $_has(0);
  @$pb.TagNumber(1)
  void clearSpec() => $_clearField(1);
}

/// Message for generate proto request arguments.
class GenerateProtoArgs extends $pb.GeneratedMessage {
  factory GenerateProtoArgs({
    ParseProgramArgs? parseArgs,
    $core.String? package,
  }) {
    final result = GenerateProtoArgs._();
    if (parseArgs != null) result.parseArgs = parseArgs;
    if (package != null) result.package = package;
    return result;
  }

  GenerateProtoArgs._();

  factory GenerateProtoArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateProtoArgs()..mergeFromBuffer(data, registry);
  factory GenerateProtoArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateProtoArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateProtoArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: GenerateProtoArgs.$_createMessage)
    ..aOM<ParseProgramArgs>(1, _omitFieldNames ? '' : 'parseArgs',
        subBuilder: ParseProgramArgs.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'package')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateProtoArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateProtoArgs copyWith(void Function(GenerateProtoArgs) updates) =>
      super.copyWith((message) => updates(message as GenerateProtoArgs))
          as GenerateProtoArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GenerateProtoArgs() / GenerateProtoArgs.new instead')
  static GenerateProtoArgs create() => GenerateProtoArgs._();
  static $pb.GeneratedMessage $_createMessage() => GenerateProtoArgs._();
  @$core.override
  GenerateProtoArgs createEmptyInstance() => GenerateProtoArgs._();
  @$core.pragma('dart2js:noInline')
  static GenerateProtoArgs getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GenerateProtoArgs>(
          GenerateProtoArgs.$_createMessage);
  static GenerateProtoArgs? _defaultInstance;

  /// Arguments for parsing the program whose schemas are exported.
  @$pb.TagNumber(1)
  ParseProgramArgs get parseArgs => $_getN(0);
  @$pb.TagNumber(1)
  set parseArgs(ParseProgramArgs value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasParseArgs() => $_has(0);
  @$pb.TagNumber(1)
  void clearParseArgs() => $_clearField(1);
  @$pb.TagNumber(1)
  ParseProgramArgs ensureParseArgs() => $_ensure(0);

  /// Proto package name, e.g. "example.v1". Empty means no package clause.
  @$pb.TagNumber(2)
  $core.String get package => $_getSZ(1);
  @$pb.TagNumber(2)
  set package($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPackage() => $_has(1);
  @$pb.TagNumber(2)
  void clearPackage() => $_clearField(2);
}

/// Message for generate proto response.
class GenerateProtoResult extends $pb.GeneratedMessage {
  factory GenerateProtoResult({
    $core.String? proto,
  }) {
    final result = GenerateProtoResult._();
    if (proto != null) result.proto = proto;
    return result;
  }

  GenerateProtoResult._();

  factory GenerateProtoResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateProtoResult()..mergeFromBuffer(data, registry);
  factory GenerateProtoResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateProtoResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateProtoResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: GenerateProtoResult.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'proto')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateProtoResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateProtoResult copyWith(void Function(GenerateProtoResult) updates) =>
      super.copyWith((message) => updates(message as GenerateProtoResult))
          as GenerateProtoResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use GenerateProtoResult() / GenerateProtoResult.new instead')
  static GenerateProtoResult create() => GenerateProtoResult._();
  static $pb.GeneratedMessage $_createMessage() => GenerateProtoResult._();
  @$core.override
  GenerateProtoResult createEmptyInstance() => GenerateProtoResult._();
  @$core.pragma('dart2js:noInline')
  static GenerateProtoResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateProtoResult>(
          GenerateProtoResult.$_createMessage);
  static GenerateProtoResult? _defaultInstance;

  /// The generated proto3 definitions.
  @$pb.TagNumber(1)
  $core.String get proto => $_getSZ(0);
  @$pb.TagNumber(1)
  set proto($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProto() => $_has(0);
  @$pb.TagNumber(1)
  void clearProto() => $_clearField(1);
}

/// Message for generate doc request arguments.
class GenerateDocArgs extends $pb.GeneratedMessage {
  factory GenerateDocArgs({
    ParseProgramArgs? parseArgs,
    $core.String? format,
  }) {
    final result = GenerateDocArgs._();
    if (parseArgs != null) result.parseArgs = parseArgs;
    if (format != null) result.format = format;
    return result;
  }

  GenerateDocArgs._();

  factory GenerateDocArgs.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateDocArgs()..mergeFromBuffer(data, registry);
  factory GenerateDocArgs.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateDocArgs()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateDocArgs',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: GenerateDocArgs.$_createMessage)
    ..aOM<ParseProgramArgs>(1, _omitFieldNames ? '' : 'parseArgs',
        subBuilder: ParseProgramArgs.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'format')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateDocArgs clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateDocArgs copyWith(void Function(GenerateDocArgs) updates) =>
      super.copyWith((message) => updates(message as GenerateDocArgs))
          as GenerateDocArgs;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GenerateDocArgs() / GenerateDocArgs.new instead')
  static GenerateDocArgs create() => GenerateDocArgs._();
  static $pb.GeneratedMessage $_createMessage() => GenerateDocArgs._();
  @$core.override
  GenerateDocArgs createEmptyInstance() => GenerateDocArgs._();
  @$core.pragma('dart2js:noInline')
  static GenerateDocArgs getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GenerateDocArgs>(
          GenerateDocArgs.$_createMessage);
  static GenerateDocArgs? _defaultInstance;

  /// Arguments for parsing the program whose schemas are documented.
  @$pb.TagNumber(1)
  ParseProgramArgs get parseArgs => $_getN(0);
  @$pb.TagNumber(1)
  set parseArgs(ParseProgramArgs value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasParseArgs() => $_has(0);
  @$pb.TagNumber(1)
  void clearParseArgs() => $_clearField(1);
  @$pb.TagNumber(1)
  ParseProgramArgs ensureParseArgs() => $_ensure(0);

  /// Output format: "md" (default, Markdown), "openapi" (Swagger 2.0 spec)
  /// or "json-schema" (JSON Schema draft for each schema). "html" is not
  /// supported yet.
  @$pb.TagNumber(2)
  $core.String get format => $_getSZ(1);
  @$pb.TagNumber(2)
  set format($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFormat() => $_has(1);
  @$pb.TagNumber(2)
  void clearFormat() => $_clearField(2);
}

/// Message for generate doc response.
class GenerateDocResult extends $pb.GeneratedMessage {
  factory GenerateDocResult({
    $core.String? content,
  }) {
    final result = GenerateDocResult._();
    if (content != null) result.content = content;
    return result;
  }

  GenerateDocResult._();

  factory GenerateDocResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateDocResult()..mergeFromBuffer(data, registry);
  factory GenerateDocResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GenerateDocResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateDocResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: GenerateDocResult.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'content')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateDocResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateDocResult copyWith(void Function(GenerateDocResult) updates) =>
      super.copyWith((message) => updates(message as GenerateDocResult))
          as GenerateDocResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GenerateDocResult() / GenerateDocResult.new instead')
  static GenerateDocResult create() => GenerateDocResult._();
  static $pb.GeneratedMessage $_createMessage() => GenerateDocResult._();
  @$core.override
  GenerateDocResult createEmptyInstance() => GenerateDocResult._();
  @$core.pragma('dart2js:noInline')
  static GenerateDocResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GenerateDocResult>(
          GenerateDocResult.$_createMessage);
  static GenerateDocResult? _defaultInstance;

  /// The generated documentation.
  @$pb.TagNumber(1)
  $core.String get content => $_getSZ(0);
  @$pb.TagNumber(1)
  set content($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasContent() => $_has(0);
  @$pb.TagNumber(1)
  void clearContent() => $_clearField(1);
}

/// Message representing a KCL type.
class KclType extends $pb.GeneratedMessage {
  factory KclType({
    $core.String? type,
    $core.Iterable<KclType>? unionTypes,
    $core.String? default_3,
    $core.String? schemaName,
    $core.String? schemaDoc,
    $core.Iterable<$core.MapEntry<$core.String, KclType>>? properties,
    $core.Iterable<$core.String>? required,
    KclType? key,
    KclType? item,
    $core.int? line,
    $core.Iterable<Decorator>? decorators,
    $core.String? filename,
    $core.String? pkgPath,
    $core.String? description,
    $core.Iterable<$core.MapEntry<$core.String, Example>>? examples,
    KclType? baseSchema,
    FunctionType? function,
    IndexSignature? indexSignature,
  }) {
    final result = KclType._();
    if (type != null) result.type = type;
    if (unionTypes != null) result.unionTypes.addAll(unionTypes);
    if (default_3 != null) result.default_3 = default_3;
    if (schemaName != null) result.schemaName = schemaName;
    if (schemaDoc != null) result.schemaDoc = schemaDoc;
    if (properties != null) result.properties.addEntries(properties);
    if (required != null) result.required.addAll(required);
    if (key != null) result.key = key;
    if (item != null) result.item = item;
    if (line != null) result.line = line;
    if (decorators != null) result.decorators.addAll(decorators);
    if (filename != null) result.filename = filename;
    if (pkgPath != null) result.pkgPath = pkgPath;
    if (description != null) result.description = description;
    if (examples != null) result.examples.addEntries(examples);
    if (baseSchema != null) result.baseSchema = baseSchema;
    if (function != null) result.function = function;
    if (indexSignature != null) result.indexSignature = indexSignature;
    return result;
  }

  KclType._();

  factory KclType.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KclType()..mergeFromBuffer(data, registry);
  factory KclType.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KclType()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KclType',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: KclType.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'type')
    ..pPM<KclType>(2, _omitFieldNames ? '' : 'unionTypes',
        subBuilder: KclType.$_createMessage)
    ..aOS(3, _omitFieldNames ? '' : 'default')
    ..aOS(4, _omitFieldNames ? '' : 'schemaName')
    ..aOS(5, _omitFieldNames ? '' : 'schemaDoc')
    ..m<$core.String, KclType>(6, _omitFieldNames ? '' : 'properties',
        entryClassName: 'KclType.PropertiesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: KclType.$_createMessage,
        valueDefaultOrMaker: KclType.getDefault,
        packageName: const $pb.PackageName('com.kcl.api'))
    ..pPS(7, _omitFieldNames ? '' : 'required')
    ..aOM<KclType>(8, _omitFieldNames ? '' : 'key',
        subBuilder: KclType.$_createMessage)
    ..aOM<KclType>(9, _omitFieldNames ? '' : 'item',
        subBuilder: KclType.$_createMessage)
    ..aI(10, _omitFieldNames ? '' : 'line')
    ..pPM<Decorator>(11, _omitFieldNames ? '' : 'decorators',
        subBuilder: Decorator.$_createMessage)
    ..aOS(12, _omitFieldNames ? '' : 'filename')
    ..aOS(13, _omitFieldNames ? '' : 'pkgPath')
    ..aOS(14, _omitFieldNames ? '' : 'description')
    ..m<$core.String, Example>(15, _omitFieldNames ? '' : 'examples',
        entryClassName: 'KclType.ExamplesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Example.$_createMessage,
        valueDefaultOrMaker: Example.getDefault,
        packageName: const $pb.PackageName('com.kcl.api'))
    ..aOM<KclType>(16, _omitFieldNames ? '' : 'baseSchema',
        subBuilder: KclType.$_createMessage)
    ..aOM<FunctionType>(17, _omitFieldNames ? '' : 'function',
        subBuilder: FunctionType.$_createMessage)
    ..aOM<IndexSignature>(18, _omitFieldNames ? '' : 'indexSignature',
        subBuilder: IndexSignature.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KclType clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KclType copyWith(void Function(KclType) updates) =>
      super.copyWith((message) => updates(message as KclType)) as KclType;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use KclType() / KclType.new instead')
  static KclType create() => KclType._();
  static $pb.GeneratedMessage $_createMessage() => KclType._();
  @$core.override
  KclType createEmptyInstance() => KclType._();
  @$core.pragma('dart2js:noInline')
  static KclType getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<KclType>(KclType.$_createMessage);
  static KclType? _defaultInstance;

  /// Type name (e.g., schema, dict, list, str, int, float, bool, any, union, function, number_multiplier).
  @$pb.TagNumber(1)
  $core.String get type => $_getSZ(0);
  @$pb.TagNumber(1)
  set type($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  /// Union types if applicable.
  @$pb.TagNumber(2)
  $pb.PbList<KclType> get unionTypes => $_getList(1);

  /// Default value of the type.
  @$pb.TagNumber(3)
  $core.String get default_3 => $_getSZ(2);
  @$pb.TagNumber(3)
  set default_3($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDefault_3() => $_has(2);
  @$pb.TagNumber(3)
  void clearDefault_3() => $_clearField(3);

  /// Name of the schema if applicable.
  @$pb.TagNumber(4)
  $core.String get schemaName => $_getSZ(3);
  @$pb.TagNumber(4)
  set schemaName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSchemaName() => $_has(3);
  @$pb.TagNumber(4)
  void clearSchemaName() => $_clearField(4);

  /// Documentation for the schema.
  @$pb.TagNumber(5)
  $core.String get schemaDoc => $_getSZ(4);
  @$pb.TagNumber(5)
  set schemaDoc($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSchemaDoc() => $_has(4);
  @$pb.TagNumber(5)
  void clearSchemaDoc() => $_clearField(5);

  /// Properties of the schema as a map with property name as key.
  @$pb.TagNumber(6)
  $pb.PbMap<$core.String, KclType> get properties => $_getMap(5);

  /// List of required schema properties.
  @$pb.TagNumber(7)
  $pb.PbList<$core.String> get required => $_getList(6);

  /// Key type if the KclType is a dictionary.
  @$pb.TagNumber(8)
  KclType get key => $_getN(7);
  @$pb.TagNumber(8)
  set key(KclType value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasKey() => $_has(7);
  @$pb.TagNumber(8)
  void clearKey() => $_clearField(8);
  @$pb.TagNumber(8)
  KclType ensureKey() => $_ensure(7);

  /// Item type if the KclType is a list or dictionary.
  @$pb.TagNumber(9)
  KclType get item => $_getN(8);
  @$pb.TagNumber(9)
  set item(KclType value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasItem() => $_has(8);
  @$pb.TagNumber(9)
  void clearItem() => $_clearField(9);
  @$pb.TagNumber(9)
  KclType ensureItem() => $_ensure(8);

  /// Line number where the type is defined.
  @$pb.TagNumber(10)
  $core.int get line => $_getIZ(9);
  @$pb.TagNumber(10)
  set line($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasLine() => $_has(9);
  @$pb.TagNumber(10)
  void clearLine() => $_clearField(10);

  /// List of decorators for the schema.
  @$pb.TagNumber(11)
  $pb.PbList<Decorator> get decorators => $_getList(10);

  /// Absolute path of the file where the attribute is located.
  @$pb.TagNumber(12)
  $core.String get filename => $_getSZ(11);
  @$pb.TagNumber(12)
  set filename($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasFilename() => $_has(11);
  @$pb.TagNumber(12)
  void clearFilename() => $_clearField(12);

  /// Path of the package where the attribute is located.
  @$pb.TagNumber(13)
  $core.String get pkgPath => $_getSZ(12);
  @$pb.TagNumber(13)
  set pkgPath($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasPkgPath() => $_has(12);
  @$pb.TagNumber(13)
  void clearPkgPath() => $_clearField(13);

  /// Documentation for the attribute.
  @$pb.TagNumber(14)
  $core.String get description => $_getSZ(13);
  @$pb.TagNumber(14)
  set description($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasDescription() => $_has(13);
  @$pb.TagNumber(14)
  void clearDescription() => $_clearField(14);

  /// Map of examples with example name as key.
  @$pb.TagNumber(15)
  $pb.PbMap<$core.String, Example> get examples => $_getMap(14);

  /// Base schema if applicable.
  @$pb.TagNumber(16)
  KclType get baseSchema => $_getN(15);
  @$pb.TagNumber(16)
  set baseSchema(KclType value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasBaseSchema() => $_has(15);
  @$pb.TagNumber(16)
  void clearBaseSchema() => $_clearField(16);
  @$pb.TagNumber(16)
  KclType ensureBaseSchema() => $_ensure(15);

  /// Function type if the KclType is a function.
  @$pb.TagNumber(17)
  FunctionType get function => $_getN(16);
  @$pb.TagNumber(17)
  set function(FunctionType value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasFunction() => $_has(16);
  @$pb.TagNumber(17)
  void clearFunction() => $_clearField(17);
  @$pb.TagNumber(17)
  FunctionType ensureFunction() => $_ensure(16);

  /// Optional schema index signature
  @$pb.TagNumber(18)
  IndexSignature get indexSignature => $_getN(17);
  @$pb.TagNumber(18)
  set indexSignature(IndexSignature value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasIndexSignature() => $_has(17);
  @$pb.TagNumber(18)
  void clearIndexSignature() => $_clearField(18);
  @$pb.TagNumber(18)
  IndexSignature ensureIndexSignature() => $_ensure(17);
}

class FunctionType extends $pb.GeneratedMessage {
  factory FunctionType({
    $core.Iterable<Parameter>? params,
    KclType? returnTy,
  }) {
    final result = FunctionType._();
    if (params != null) result.params.addAll(params);
    if (returnTy != null) result.returnTy = returnTy;
    return result;
  }

  FunctionType._();

  factory FunctionType.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FunctionType()..mergeFromBuffer(data, registry);
  factory FunctionType.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FunctionType()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FunctionType',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: FunctionType.$_createMessage)
    ..pPM<Parameter>(1, _omitFieldNames ? '' : 'params',
        subBuilder: Parameter.$_createMessage)
    ..aOM<KclType>(2, _omitFieldNames ? '' : 'returnTy',
        subBuilder: KclType.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FunctionType clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FunctionType copyWith(void Function(FunctionType) updates) =>
      super.copyWith((message) => updates(message as FunctionType))
          as FunctionType;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FunctionType() / FunctionType.new instead')
  static FunctionType create() => FunctionType._();
  static $pb.GeneratedMessage $_createMessage() => FunctionType._();
  @$core.override
  FunctionType createEmptyInstance() => FunctionType._();
  @$core.pragma('dart2js:noInline')
  static FunctionType getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FunctionType>(
          FunctionType.$_createMessage);
  static FunctionType? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Parameter> get params => $_getList(0);

  @$pb.TagNumber(2)
  KclType get returnTy => $_getN(1);
  @$pb.TagNumber(2)
  set returnTy(KclType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasReturnTy() => $_has(1);
  @$pb.TagNumber(2)
  void clearReturnTy() => $_clearField(2);
  @$pb.TagNumber(2)
  KclType ensureReturnTy() => $_ensure(1);
}

class Parameter extends $pb.GeneratedMessage {
  factory Parameter({
    $core.String? name,
    KclType? ty,
  }) {
    final result = Parameter._();
    if (name != null) result.name = name;
    if (ty != null) result.ty = ty;
    return result;
  }

  Parameter._();

  factory Parameter.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Parameter()..mergeFromBuffer(data, registry);
  factory Parameter.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Parameter()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Parameter',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: Parameter.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOM<KclType>(2, _omitFieldNames ? '' : 'ty',
        subBuilder: KclType.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Parameter clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Parameter copyWith(void Function(Parameter) updates) =>
      super.copyWith((message) => updates(message as Parameter)) as Parameter;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Parameter() / Parameter.new instead')
  static Parameter create() => Parameter._();
  static $pb.GeneratedMessage $_createMessage() => Parameter._();
  @$core.override
  Parameter createEmptyInstance() => Parameter._();
  @$core.pragma('dart2js:noInline')
  static Parameter getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Parameter>(Parameter.$_createMessage);
  static Parameter? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  KclType get ty => $_getN(1);
  @$pb.TagNumber(2)
  set ty(KclType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasTy() => $_has(1);
  @$pb.TagNumber(2)
  void clearTy() => $_clearField(2);
  @$pb.TagNumber(2)
  KclType ensureTy() => $_ensure(1);
}

/// Message representing an index signature in KCL.
class IndexSignature extends $pb.GeneratedMessage {
  factory IndexSignature({
    $core.String? keyName,
    KclType? key,
    KclType? val,
    $core.bool? anyOther,
  }) {
    final result = IndexSignature._();
    if (keyName != null) result.keyName = keyName;
    if (key != null) result.key = key;
    if (val != null) result.val = val;
    if (anyOther != null) result.anyOther = anyOther;
    return result;
  }

  IndexSignature._();

  factory IndexSignature.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      IndexSignature()..mergeFromBuffer(data, registry);
  factory IndexSignature.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      IndexSignature()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IndexSignature',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: IndexSignature.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'keyName')
    ..aOM<KclType>(2, _omitFieldNames ? '' : 'key',
        subBuilder: KclType.$_createMessage)
    ..aOM<KclType>(3, _omitFieldNames ? '' : 'val',
        subBuilder: KclType.$_createMessage)
    ..aOB(4, _omitFieldNames ? '' : 'anyOther')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IndexSignature clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IndexSignature copyWith(void Function(IndexSignature) updates) =>
      super.copyWith((message) => updates(message as IndexSignature))
          as IndexSignature;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use IndexSignature() / IndexSignature.new instead')
  static IndexSignature create() => IndexSignature._();
  static $pb.GeneratedMessage $_createMessage() => IndexSignature._();
  @$core.override
  IndexSignature createEmptyInstance() => IndexSignature._();
  @$core.pragma('dart2js:noInline')
  static IndexSignature getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<IndexSignature>(
          IndexSignature.$_createMessage);
  static IndexSignature? _defaultInstance;

  /// The optional index signature key name
  @$pb.TagNumber(1)
  $core.String get keyName => $_getSZ(0);
  @$pb.TagNumber(1)
  set keyName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKeyName() => $_has(0);
  @$pb.TagNumber(1)
  void clearKeyName() => $_clearField(1);

  /// Key type of the index signature.
  @$pb.TagNumber(2)
  KclType get key => $_getN(1);
  @$pb.TagNumber(2)
  set key(KclType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearKey() => $_clearField(2);
  @$pb.TagNumber(2)
  KclType ensureKey() => $_ensure(1);

  /// Value type of the index signature.
  @$pb.TagNumber(3)
  KclType get val => $_getN(2);
  @$pb.TagNumber(3)
  set val(KclType value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasVal() => $_has(2);
  @$pb.TagNumber(3)
  void clearVal() => $_clearField(3);
  @$pb.TagNumber(3)
  KclType ensureVal() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.bool get anyOther => $_getBF(3);
  @$pb.TagNumber(4)
  set anyOther($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAnyOther() => $_has(3);
  @$pb.TagNumber(4)
  void clearAnyOther() => $_clearField(4);
}

/// Message representing a decorator in KCL.
class Decorator extends $pb.GeneratedMessage {
  factory Decorator({
    $core.String? name,
    $core.Iterable<$core.String>? arguments,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? keywords,
  }) {
    final result = Decorator._();
    if (name != null) result.name = name;
    if (arguments != null) result.arguments.addAll(arguments);
    if (keywords != null) result.keywords.addEntries(keywords);
    return result;
  }

  Decorator._();

  factory Decorator.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Decorator()..mergeFromBuffer(data, registry);
  factory Decorator.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Decorator()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Decorator',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: Decorator.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..pPS(2, _omitFieldNames ? '' : 'arguments')
    ..m<$core.String, $core.String>(3, _omitFieldNames ? '' : 'keywords',
        entryClassName: 'Decorator.KeywordsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('com.kcl.api'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Decorator clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Decorator copyWith(void Function(Decorator) updates) =>
      super.copyWith((message) => updates(message as Decorator)) as Decorator;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Decorator() / Decorator.new instead')
  static Decorator create() => Decorator._();
  static $pb.GeneratedMessage $_createMessage() => Decorator._();
  @$core.override
  Decorator createEmptyInstance() => Decorator._();
  @$core.pragma('dart2js:noInline')
  static Decorator getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Decorator>(Decorator.$_createMessage);
  static Decorator? _defaultInstance;

  /// Name of the decorator.
  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  /// Arguments for the decorator.
  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get arguments => $_getList(1);

  /// Keyword arguments for the decorator as a map with keyword name as key.
  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, $core.String> get keywords => $_getMap(2);
}

/// Message representing an example in KCL.
class Example extends $pb.GeneratedMessage {
  factory Example({
    $core.String? summary,
    $core.String? description,
    $core.String? value,
  }) {
    final result = Example._();
    if (summary != null) result.summary = summary;
    if (description != null) result.description = description;
    if (value != null) result.value = value;
    return result;
  }

  Example._();

  factory Example.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Example()..mergeFromBuffer(data, registry);
  factory Example.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Example()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Example',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'com.kcl.api'),
      createEmptyInstance: Example.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'summary')
    ..aOS(2, _omitFieldNames ? '' : 'description')
    ..aOS(3, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Example clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Example copyWith(void Function(Example) updates) =>
      super.copyWith((message) => updates(message as Example)) as Example;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Example() / Example.new instead')
  static Example create() => Example._();
  static $pb.GeneratedMessage $_createMessage() => Example._();
  @$core.override
  Example createEmptyInstance() => Example._();
  @$core.pragma('dart2js:noInline')
  static Example getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Example>(Example.$_createMessage);
  static Example? _defaultInstance;

  /// Short description for the example.
  @$pb.TagNumber(1)
  $core.String get summary => $_getSZ(0);
  @$pb.TagNumber(1)
  set summary($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSummary() => $_has(0);
  @$pb.TagNumber(1)
  void clearSummary() => $_clearField(1);

  /// Long description for the example.
  @$pb.TagNumber(2)
  $core.String get description => $_getSZ(1);
  @$pb.TagNumber(2)
  set description($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescription() => $_clearField(2);

  /// Embedded literal example.
  @$pb.TagNumber(3)
  $core.String get value => $_getSZ(2);
  @$pb.TagNumber(3)
  set value($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearValue() => $_clearField(3);
}

/// Service for built-in functionality.
class BuiltinServiceApi {
  final $pb.RpcClient _client;

  BuiltinServiceApi(this._client);

  /// Sends a ping request.
  $async.Future<PingResult> ping($pb.ClientContext? ctx, PingArgs request) =>
      _client.invoke<PingResult>(
          ctx, 'BuiltinService', 'Ping', request, PingResult());

  /// Lists available methods.
  $async.Future<ListMethodResult> listMethod(
          $pb.ClientContext? ctx, ListMethodArgs request) =>
      _client.invoke<ListMethodResult>(
          ctx, 'BuiltinService', 'ListMethod', request, ListMethodResult());
}

/// Service for KCL VM interactions.
class KclServiceApi {
  final $pb.RpcClient _client;

  KclServiceApi(this._client);

  /// / Ping KclService, return the same value as the parameter
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "Ping",
  /// /     "params": {
  /// /         "value": "hello"
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "value": "hello"
  /// /     },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<PingResult> ping($pb.ClientContext? ctx, PingArgs request) =>
      _client.invoke<PingResult>(
          ctx, 'KclService', 'Ping', request, PingResult());

  /// / GetVersion KclService, return the kcl service version information
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "GetVersion",
  /// /     "params": {},
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "version": "0.9.1",
  /// /         "checksum": "c020ab3eb4b9179219d6837a57f5d323",
  /// /         "git_sha": "1a9a72942fffc9f62cb8f1ae4e1d5ca32aa1f399",
  /// /         "version_info": "Version: 0.9.1-c020ab3eb4b9179219d6837a57f5d323\nPlatform: aarch64-apple-darwin\nGitCommit: 1a9a72942fffc9f62cb8f1ae4e1d5ca32aa1f399"
  /// /     },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<GetVersionResult> getVersion(
          $pb.ClientContext? ctx, GetVersionArgs request) =>
      _client.invoke<GetVersionResult>(
          ctx, 'KclService', 'GetVersion', request, GetVersionResult());

  /// / Parse KCL program with entry files.
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "ParseProgram",
  /// /     "params": {
  /// /         "paths": ["./src/testdata/test.k"]
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "ast_json": "{...}",
  /// /         "paths": ["./src/testdata/test.k"],
  /// /         "errors": []
  /// /     },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<ParseProgramResult> parseProgram(
          $pb.ClientContext? ctx, ParseProgramArgs request) =>
      _client.invoke<ParseProgramResult>(
          ctx, 'KclService', 'ParseProgram', request, ParseProgramResult());

  /// / Parse KCL single file to Module AST JSON string with import dependencies
  /// / and parse errors.
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "ParseFile",
  /// /     "params": {
  /// /         "path": "./src/testdata/parse/main.k"
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "ast_json": "{...}",
  /// /         "deps": ["./dep1", "./dep2"],
  /// /         "errors": []
  /// /     },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<ParseFileResult> parseFile(
          $pb.ClientContext? ctx, ParseFileArgs request) =>
      _client.invoke<ParseFileResult>(
          ctx, 'KclService', 'ParseFile', request, ParseFileResult());

  /// / load_package provides users with the ability to parse kcl program and semantic model
  /// / information including symbols, types, definitions, etc.
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "LoadPackage",
  /// /     "params": {
  /// /         "parse_args": {
  /// /             "paths": ["./src/testdata/parse/main.k"]
  /// /         },
  /// /         "resolve_ast": true
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "program": "{...}",
  /// /         "paths": ["./src/testdata/parse/main.k"],
  /// /         "parse_errors": [],
  /// /         "type_errors": [],
  /// /         "symbols": { ... },
  /// /         "scopes": { ... },
  /// /         "node_symbol_map": { ... },
  /// /         "symbol_node_map": { ... },
  /// /         "fully_qualified_name_map": { ... },
  /// /         "pkg_scope_map": { ... }
  /// /     },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<LoadPackageResult> loadPackage(
          $pb.ClientContext? ctx, LoadPackageArgs request) =>
      _client.invoke<LoadPackageResult>(
          ctx, 'KclService', 'LoadPackage', request, LoadPackageResult());

  /// / list_options provides users with the ability to parse kcl program and get all option information.
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "ListOptions",
  /// /     "params": {
  /// /         "paths": ["./src/testdata/option/main.k"]
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "options": [
  /// /             { "name": "option1", "type": "str", "required": true, "default_value": "", "help": "option 1 help" },
  /// /             { "name": "option2", "type": "int", "required": false, "default_value": "0", "help": "option 2 help" },
  /// /             { "name": "option3", "type": "bool", "required": false, "default_value": "false", "help": "option 3 help" }
  /// /         ]
  /// /     },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<ListOptionsResult> listOptions(
          $pb.ClientContext? ctx, ParseProgramArgs request) =>
      _client.invoke<ListOptionsResult>(
          ctx, 'KclService', 'ListOptions', request, ListOptionsResult());

  /// / list_variables provides users with the ability to parse kcl program and get all variables by specs.
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "ListVariables",
  /// /     "params": {
  /// /         "files": ["./src/testdata/variables/main.k"],
  /// /         "specs": ["a"]
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "variables": {
  /// /             "a": {
  /// /                 "variables": [
  /// /                     { "value": "1", "type_name": "int", "op_sym": "", "list_items": [], "dict_entries": [] }
  /// /                 ]
  /// /             }
  /// /         },
  /// /         "unsupported_codes": [],
  /// /         "parse_errors": []
  /// /     },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<ListVariablesResult> listVariables(
          $pb.ClientContext? ctx, ListVariablesArgs request) =>
      _client.invoke<ListVariablesResult>(
          ctx, 'KclService', 'ListVariables', request, ListVariablesResult());

  /// / Execute KCL file with args. **Note that it is not thread safe.**
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "ExecProgram",
  /// /     "params": {
  /// /         "work_dir": "./src/testdata",
  /// /         "k_filename_list": ["test.k"]
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "json_result": "{\"alice\": {\"age\": 18}}",
  /// /         "yaml_result": "alice:\n  age: 18",
  /// /         "log_message": "",
  /// /         "err_message": ""
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Request with code
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "ExecProgram",
  /// /     "params": {
  /// /         "k_filename_list": ["file.k"],
  /// /         "k_code_list": ["alice = {age = 18}"]
  /// /     },
  /// /     "id": 2
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "json_result": "{\"alice\": {\"age\": 18}}",
  /// /         "yaml_result": "alice:\n  age: 18",
  /// /         "log_message": "",
  /// /         "err_message": ""
  /// /     },
  /// /     "id": 2
  /// / }
  /// /
  /// / // Error case - cannot find file
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "ExecProgram",
  /// /     "params": {
  /// /         "k_filename_list": ["invalid_file.k"]
  /// /     },
  /// /     "id": 3
  /// / }
  /// /
  /// / // Error Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "error": {
  /// /         "code": -32602,
  /// /         "message": "Cannot find the kcl file"
  /// /     },
  /// /     "id": 3
  /// / }
  /// /
  /// / // Error case - no input files
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "ExecProgram",
  /// /     "params": {
  /// /         "k_filename_list": []
  /// /     },
  /// /     "id": 4
  /// / }
  /// /
  /// / // Error Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "error": {
  /// /         "code": -32602,
  /// /         "message": "No input KCL files or paths"
  /// /     },
  /// /     "id": 4
  /// / }
  /// / ```
  $async.Future<ExecProgramResult> execProgram(
          $pb.ClientContext? ctx, ExecProgramArgs request) =>
      _client.invoke<ExecProgramResult>(
          ctx, 'KclService', 'ExecProgram', request, ExecProgramResult());

  /// / Override KCL file with args.
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "OverrideFile",
  /// /     "params": {
  /// /         "file": "./src/testdata/test.k",
  /// /         "specs": ["alice.age=18"]
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "result": true,
  /// /         "parse_errors": []
  /// /     },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<OverrideFileResult> overrideFile(
          $pb.ClientContext? ctx, OverrideFileArgs request) =>
      _client.invoke<OverrideFileResult>(
          ctx, 'KclService', 'OverrideFile', request, OverrideFileResult());

  /// / Get schema type mapping.
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "GetSchemaTypeMapping",
  /// /     "params": {
  /// /         "exec_args": {
  /// /             "work_dir": "./src/testdata",
  /// /             "k_filename_list": ["main.k"],
  /// /             "external_pkgs": [
  /// /                 {
  /// /                     "pkg_name":"pkg",
  /// /                     "pkg_path": "./src/testdata/pkg"
  /// /                 }
  /// /             ]
  /// /         },
  /// /         "schema_name": "Person"
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "schema_type_mapping": {
  /// /             "Person": {
  /// /                 "type": "schema",
  /// /                 "schema_name": "Person",
  /// /                 "properties": {
  /// /                     "name": { "type": "str" },
  /// /                     "age": { "type": "int" }
  /// /                 },
  /// /                 "required": ["name", "age"],
  /// /                 "decorators": []
  /// /             }
  /// /         }
  /// /     },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<GetSchemaTypeMappingResult> getSchemaTypeMapping(
          $pb.ClientContext? ctx, GetSchemaTypeMappingArgs request) =>
      _client.invoke<GetSchemaTypeMappingResult>(ctx, 'KclService',
          'GetSchemaTypeMapping', request, GetSchemaTypeMappingResult());

  /// / Get schema type mapping under the input paths, including all of their
  /// / external dependency packages. Different from `GetSchemaTypeMapping`,
  /// / the result is keyed by package name (e.g. "__main__", "pkg") and each
  /// / value holds the schema list of that package, so schemas defined in
  /// / kcl.mod `[dependencies]` keep their own pkgpath and base schema.
  /// / See https://github.com/kcl-lang/kcl/issues/1546.
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "GetSchemaTypeMappingUnderPath",
  /// /     "params": {
  /// /         "exec_args": {
  /// /             "work_dir": "./src/testdata",
  /// /             "k_filename_list": ["main.k"]
  /// /         },
  /// /         "schema_name": ""
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "schema_type_mapping": {
  /// /             "__main__": {
  /// /                 "schema_type": [
  /// /                     {
  /// /                         "type": "schema",
  /// /                         "schema_name": "Person",
  /// /                         "properties": {
  /// /                             "name": { "type": "str" }
  /// /                         },
  /// /                         "required": ["name"]
  /// /                     }
  /// /                 ]
  /// /             }
  /// /         }
  /// /     },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<GetSchemaTypeMappingUnderPathResult>
      getSchemaTypeMappingUnderPath(
              $pb.ClientContext? ctx, GetSchemaTypeMappingArgs request) =>
          _client.invoke<GetSchemaTypeMappingUnderPathResult>(
              ctx,
              'KclService',
              'GetSchemaTypeMappingUnderPath',
              request,
              GetSchemaTypeMappingUnderPathResult());

  /// / Format code source.
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "FormatCode",
  /// /     "params": {
  /// /         "source": "schema Person {\n    name: str\n    age: int\n}\nperson = Person {\n    name = \"Alice\"\n    age = 18\n}\n"
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "formatted": "schema Person {\n    name: str\n    age: int\n}\nperson = Person {\n    name = \"Alice\"\n    age = 18\n}\n"
  /// /     },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<FormatCodeResult> formatCode(
          $pb.ClientContext? ctx, FormatCodeArgs request) =>
      _client.invoke<FormatCodeResult>(
          ctx, 'KclService', 'FormatCode', request, FormatCodeResult());

  /// / Format KCL file or directory path contains KCL files and returns the changed file paths.
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "FormatPath",
  /// /     "params": {
  /// /         "path": "./src/testdata/test.k"
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "changed_paths": []
  /// /     },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<FormatPathResult> formatPath(
          $pb.ClientContext? ctx, FormatPathArgs request) =>
      _client.invoke<FormatPathResult>(
          ctx, 'KclService', 'FormatPath', request, FormatPathResult());

  /// / Lint files and return error messages including errors and warnings.
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "LintPath",
  /// /     "params": {
  /// /         "paths": ["./src/testdata/test-lint.k"]
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "results": ["Module 'math' imported but unused"]
  /// /     },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<LintPathResult> lintPath(
          $pb.ClientContext? ctx, LintPathArgs request) =>
      _client.invoke<LintPathResult>(
          ctx, 'KclService', 'LintPath', request, LintPathResult());

  /// / Validate code using schema and data strings.
  /// /
  /// / **Note that it is not thread safe.**
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "ValidateCode",
  /// /     "params": {
  /// /         "code": "schema Person {\n    name: str\n    age: int\n    check: 0 < age < 120\n}",
  /// /         "data": "{\"name\": \"Alice\", \"age\": 10}"
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "success": true,
  /// /         "err_message": ""
  /// /     },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<ValidateCodeResult> validateCode(
          $pb.ClientContext? ctx, ValidateCodeArgs request) =>
      _client.invoke<ValidateCodeResult>(
          ctx, 'KclService', 'ValidateCode', request, ValidateCodeResult());

  /// / Build setting file config from args.
  /// /
  /// / # Examples
  /// /
  /// /
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "LoadSettingsFiles",
  /// /     "params": {
  /// /         "work_dir": "./src/testdata/settings",
  /// /         "files": ["./src/testdata/settings/kcl.yaml"]
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "kcl_cli_configs": {
  /// /             "files": ["./src/testdata/settings/kcl.yaml"],
  /// /             "output": "",
  /// /             "overrides": [],
  /// /             "path_selector": [],
  /// /             "strict_range_check": false,
  /// /             "disable_none": false,
  /// /             "verbose": 0,
  /// /             "debug": false,
  /// /             "sort_keys": false,
  /// /             "show_hidden": false,
  /// /             "include_schema_type_path": false,
  /// /             "fast_eval": false
  /// /         },
  /// /         "kcl_options": []
  /// /     },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<LoadSettingsFilesResult> loadSettingsFiles(
          $pb.ClientContext? ctx, LoadSettingsFilesArgs request) =>
      _client.invoke<LoadSettingsFilesResult>(ctx, 'KclService',
          'LoadSettingsFiles', request, LoadSettingsFilesResult());

  /// / Rename all the occurrences of the target symbol in the files. This API will rewrite files if they contain symbols to be renamed.
  /// / Return the file paths that got changed.
  /// /
  /// / # Examples
  /// /
  /// /
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "Rename",
  /// /     "params": {
  /// /         "package_root": "./src/testdata/rename_doc",
  /// /         "symbol_path": "a",
  /// /         "file_paths": ["./src/testdata/rename_doc/main.k"],
  /// /         "new_name": "a2"
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "changed_files": ["./src/testdata/rename_doc/main.k"]
  /// /     },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<RenameResult> rename(
          $pb.ClientContext? ctx, RenameArgs request) =>
      _client.invoke<RenameResult>(
          ctx, 'KclService', 'Rename', request, RenameResult());

  /// / Rename all the occurrences of the target symbol and return the modified code if any code has been changed. This API won't rewrite files but return the changed code.
  /// /
  /// / # Examples
  /// /
  /// /
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "RenameCode",
  /// /     "params": {
  /// /         "package_root": "/mock/path",
  /// /         "symbol_path": "a",
  /// /         "source_codes": {
  /// /             "/mock/path/main.k": "a = 1\nb = a"
  /// /         },
  /// /         "new_name": "a2"
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "changed_codes": {
  /// /             "/mock/path/main.k": "a2 = 1\nb = a2"
  /// /         }
  /// /     },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<RenameCodeResult> renameCode(
          $pb.ClientContext? ctx, RenameCodeArgs request) =>
      _client.invoke<RenameCodeResult>(
          ctx, 'KclService', 'RenameCode', request, RenameCodeResult());

  /// / Test KCL packages with test arguments.
  /// /
  /// / # Examples
  /// /
  /// /
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "Test",
  /// /     "params": {
  /// /         "exec_args": {
  /// /             "work_dir": "./src/testdata/testing/module",
  /// /             "k_filename_list": ["main.k"]
  /// /         },
  /// /         "pkg_list": ["./src/testdata/testing/module/..."]
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "info": [
  /// /             {"name": "test_case_1", "error": "", "duration": 1000, "log_message": ""},
  /// /             {"name": "test_case_2", "error": "some error", "duration": 2000, "log_message": ""}
  /// /         ]
  /// /     },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<TestResult> test($pb.ClientContext? ctx, TestArgs request) =>
      _client.invoke<TestResult>(
          ctx, 'KclService', 'Test', request, TestResult());

  /// / Format a test result into a human-readable report.
  /// /
  /// / The output is byte-identical to the kcl-go `PrettyReporter` format
  /// / and is deterministic for a given result. Every line, including the
  /// / last one, ends with `\n`:
  /// /
  /// / - One line per case in result order: `{name}: {STATUS} ({duration_ms}ms)`
  /// /   where STATUS is PASS or FAIL (no case can currently be skipped) and
  /// /   the duration is the case duration in microseconds truncated to whole
  /// /   milliseconds (integer division, e.g. 1500µs renders as `1ms`). When
  /// /   a case has a non-empty log message, the log is appended on the next
  /// /   line; otherwise a failed case appends its error string as-is (the
  /// /   error already carries its own prefix, e.g. `Error: ...`).
  /// / - A separator line of exactly 80 `-` characters.
  /// / - Only for non-zero counts, in this order: `PASS: {p}/{total}`,
  /// /   `FAIL: {f}/{total}`, `SKIPPED: {s}/{total}`, where total is the
  /// /   number of cases.
  /// / - When the result is empty (no cases and no coverage) the report is
  /// /   exactly `no test files\n`.
  /// / - When coverage is populated (files non-empty), after the summary
  /// /   lines: one roll-up line `Coverage: {percent:.1}% ({covered}/{executable} lines)`
  /// /   using the pre-computed CoverageSummary fields, then one line per
  /// /   file sorted by filename, indented two spaces:
  /// /   `  {filename}: {covered_lines}/{executable_lines} ({percent:.1}%)`
  /// /   where the per-file percent is `100.0 * covered / executable`, or
  /// /   `0.0%` when the file has no executable lines.
  /// /
  /// / # Examples
  /// /
  /// /
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "FormatTestReport",
  /// /     "params": {
  /// /         "result": {
  /// /             "info": [
  /// /                 {"name": "test_case_1", "error": "", "duration": 1500, "log_message": ""},
  /// /                 {"name": "test_case_2", "error": "Error: assert failed", "duration": 2500, "log_message": ""}
  /// /             ]
  /// /         }
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "report": "test_case_1: PASS (1ms)\ntest_case_2: FAIL (2ms)\nError: assert failed\n--------------------------------------------------------------------------------\nPASS: 1/2\nFAIL: 1/2\n"
  /// /     },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<FormatTestReportResult> formatTestReport(
          $pb.ClientContext? ctx, FormatTestReportArgs request) =>
      _client.invoke<FormatTestReportResult>(ctx, 'KclService',
          'FormatTestReport', request, FormatTestReportResult());

  /// / Download and update dependencies defined in the kcl.mod file.
  /// /
  /// / # Examples
  /// /
  /// /
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "UpdateDependencies",
  /// /     "params": {
  /// /         "manifest_path": "./src/testdata/update_dependencies"
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "external_pkgs": [
  /// /             {"pkg_name": "pkg1", "pkg_path": "./src/testdata/update_dependencies/pkg1"}
  /// /         ]
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Request with vendor flag
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "UpdateDependencies",
  /// /     "params": {
  /// /         "manifest_path": "./src/testdata/update_dependencies",
  /// /         "vendor": true
  /// /     },
  /// /     "id": 2
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": {
  /// /         "external_pkgs": [
  /// /             {"pkg_name": "pkg1", "pkg_path": "./src/testdata/update_dependencies/pkg1"}
  /// /         ]
  /// /     },
  /// /     "id": 2
  /// / }
  /// / ```
  $async.Future<UpdateDependenciesResult> updateDependencies(
          $pb.ClientContext? ctx, UpdateDependenciesArgs request) =>
      _client.invoke<UpdateDependenciesResult>(ctx, 'KclService',
          'UpdateDependencies', request, UpdateDependenciesResult());

  /// / Generate TOML from the evaluated result of a KCL program.
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "GenerateToml",
  /// /     "params": {
  /// /         "exec_args": {
  /// /             "k_filename_list": ["file.k"],
  /// /             "k_code_list": ["a = {b = 1, c = [1, 2]}"]
  /// /         }
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": { "toml": "[a]\nb = 1\nc = [1, 2]\n" },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<GenerateTomlResult> generateToml(
          $pb.ClientContext? ctx, GenerateTomlArgs request) =>
      _client.invoke<GenerateTomlResult>(
          ctx, 'KclService', 'GenerateToml', request, GenerateTomlResult());

  /// / Generate KCL source from data content (JSON, YAML or TOML).
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "GenerateKcl",
  /// /     "params": {
  /// /         "source": "{\"a\": {\"b\": 1}}",
  /// /         "filename": "data.json",
  /// /         "format": "json"
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": { "kcl": "a = {\n    b = 1\n}\n" },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<GenerateKclResult> generateKcl(
          $pb.ClientContext? ctx, GenerateKclArgs request) =>
      _client.invoke<GenerateKclResult>(
          ctx, 'KclService', 'GenerateKcl', request, GenerateKclResult());

  /// / Generate an OpenAPI spec from the schemas of a KCL package.
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "GenerateOpenAPI",
  /// /     "params": {
  /// /         "parse_args": { "paths": ["./src/testdata/gen_openapi/main.k"] },
  /// /         "version": "v3"
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": { "spec": "{ \"openapi\": \"3.0.0\", ... }" },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<GenerateOpenAPIResult> generateOpenAPI(
          $pb.ClientContext? ctx, GenerateOpenAPIArgs request) =>
      _client.invoke<GenerateOpenAPIResult>(ctx, 'KclService',
          'GenerateOpenAPI', request, GenerateOpenAPIResult());

  /// / Generate proto3 definitions from the schemas of a KCL package.
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "GenerateProto",
  /// /     "params": {
  /// /         "parse_args": { "paths": ["./src/testdata/gen_openapi/main.k"] },
  /// /         "package": "example.v1"
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": { "proto": "syntax = \"proto3\"; ..." },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<GenerateProtoResult> generateProto(
          $pb.ClientContext? ctx, GenerateProtoArgs request) =>
      _client.invoke<GenerateProtoResult>(
          ctx, 'KclService', 'GenerateProto', request, GenerateProtoResult());

  /// / Generate documentation from the schemas of a KCL package.
  /// /
  /// / # Examples
  /// /
  /// / ```jsonrpc
  /// / // Request
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "method": "GenerateDoc",
  /// /     "params": {
  /// /         "parse_args": { "paths": ["./src/testdata/gen_openapi/main.k"] },
  /// /         "format": "md"
  /// /     },
  /// /     "id": 1
  /// / }
  /// /
  /// / // Response
  /// / {
  /// /     "jsonrpc": "2.0",
  /// /     "result": { "content": "# Schemas\n\n..." },
  /// /     "id": 1
  /// / }
  /// / ```
  $async.Future<GenerateDocResult> generateDoc(
          $pb.ClientContext? ctx, GenerateDocArgs request) =>
      _client.invoke<GenerateDocResult>(
          ctx, 'KclService', 'GenerateDoc', request, GenerateDocResult());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
