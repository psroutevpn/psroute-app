import 'package:freezed_annotation/freezed_annotation.dart';

part 'singbox_rule.freezed.dart';
part 'singbox_rule.g.dart';

/// Converts a comma-separated string (Dart side) to/from a JSON array (Go side).
/// Go's sing-box expects `domains`, `ip` as []string, but Dart stores them as
/// a single comma-separated string for convenience in the UI layer.
class _CommaSplitConverter implements JsonConverter<String?, List<dynamic>?> {
  const _CommaSplitConverter();

  @override
  String? fromJson(List<dynamic>? json) =>
      json?.map((e) => e.toString()).join(',');

  @override
  List<String>? toJson(String? object) => object
      ?.split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

@freezed
class SingboxRule with _$SingboxRule {
  const SingboxRule._();

  @JsonSerializable(fieldRename: FieldRename.kebab)
  const factory SingboxRule({
    String? ruleSetUrl,
    @_CommaSplitConverter() String? domains,
    @_CommaSplitConverter() String? ip,
    String? port,
    String? protocol,
    @Default(RuleNetwork.tcpAndUdp) RuleNetwork network,
    @Default(RuleOutbound.proxy) RuleOutbound outbound,
  }) = _SingboxRule;

  factory SingboxRule.fromJson(Map<String, dynamic> json) => _$SingboxRuleFromJson(json);
}

@JsonEnum(valueField: 'key')
enum RuleOutbound {
  proxy(0),
  bypass(1),
  block(3);

  const RuleOutbound(this.key);

  final int key;
}

@JsonEnum(valueField: 'key')
enum RuleNetwork {
  tcpAndUdp(0),
  tcp(1),
  udp(2);

  const RuleNetwork(this.key);

  final int key;
}
