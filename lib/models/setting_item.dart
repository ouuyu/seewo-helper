import 'package:flutter/material.dart';

/// 设置项类型
enum SettingType {
  /// 文本输入
  text,

  /// 开关
  toggle,

  /// 路径选择
  path,
}

/// 设置分组（第二级标题）
class SettingGroup {
  final String title;
  final List<SettingItem> items;

  SettingGroup({required this.title, required this.items});
}

/// 设置分区（第一级标题）
class SettingSection {
  final String title;
  final List<SettingGroup> groups;
  final bool showInSettings; // 是否在设置页面中显示

  SettingSection({
    required this.title,
    required this.groups,
    this.showInSettings = true, // 默认显示
  });
}

/// 设置项模型
class SettingItem<T> {
  /// 唯一标识
  final String key;

  /// 显示标题
  final String title;

  /// 描述说明
  final String? description;

  /// 设置类型
  final SettingType type;

  /// 默认值
  final T defaultValue;

  /// 当前值
  T value;

  /// 图标
  final IconData? icon;

  /// 验证函数（接受 dynamic 以避免泛型擦除问题）
  final String? Function(dynamic value)? validator;

  SettingItem({
    required this.key,
    required this.title,
    this.description,
    required this.type,
    required this.defaultValue,
    T? initialValue,
    this.icon,
    this.validator,
  }) : value = initialValue ?? defaultValue;

  /// 重置为默认值
  void reset() {
    value = defaultValue;
  }

  /// 转换为 JSON
  dynamic toJson() {
    return value;
  }

  /// 从 JSON 加载
  void fromJson(dynamic json) {
    if (json != null && json is T) {
      value = json;
    }
  }

  SettingItem<T> copyWith({T? value}) {
    return SettingItem<T>(
      key: key,
      title: title,
      description: description,
      type: type,
      defaultValue: defaultValue,
      initialValue: value ?? this.value,
      icon: icon,
      validator: validator,
    );
  }
}
