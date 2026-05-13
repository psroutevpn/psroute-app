import 'package:freezed_annotation/freezed_annotation.dart';

part 'singbox_rule.freezed.dart';
part 'singbox_rule.g.dart';

@freezed
class SingboxRule with _$SingboxRule {
  const SingboxRule._();

  @JsonSerializable(fieldRename: FieldRename.kebab)
  const factory SingboxRule({
    String? ruleSetUrl,
    String? domains,
    String? ip,
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
