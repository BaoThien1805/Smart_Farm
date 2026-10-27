import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../auth/auth_repository.dart';

/// Stable identities shared by bottom navigation, desktop links and callbacks.
enum WorkspaceDestination {
  overview('Tổng quan', Icons.home_outlined),
  pens('Chuồng trại', Icons.home_work_outlined),
  animals('Vật nuôi', Icons.pets_outlined),
  care('Lịch', Icons.calendar_month_outlined),
  more('Thêm', Icons.more_horiz),
  inventory('Kho thức ăn', Icons.inventory_2_outlined),
  finance('Thu chi', Icons.account_balance_wallet_outlined),
  users('Nhân sự', Icons.people_outline),
  catalog('Danh mục', Icons.category_outlined),
  profile('Tài khoản', Icons.person_outline),
  location('Vị trí trang trại', Icons.location_on_outlined);

  const WorkspaceDestination(this.label, this.icon);
  final String label;
  final IconData icon;
  IconData get selectedIcon => switch (this) {
    overview => Icons.home_rounded,
    pens => Icons.home_work_rounded,
    animals => Icons.pets_rounded,
    care => Icons.calendar_month_rounded,
    _ => icon,
  };
  Color get accent => switch (this) {
    finance => FarmColors.gold,
    users => FarmColors.blue,
    catalog => FarmColors.lilac,
    _ => forest,
  };

  static const primary = [overview, pens, animals, care, more];
  static const secondary = [
    inventory,
    finance,
    users,
    catalog,
    profile,
    location,
  ];
  bool get isSecondary => secondary.contains(this);
  WorkspaceDestination get primaryDestination => isSecondary ? more : this;

  bool allowedFor(FarmUser user) => switch (this) {
    finance => user.canFinance,
    users => user.isAdmin,
    // Catalogs, feed stock and weather already grant authenticated read access.
    _ => true,
  };

  static WorkspaceDestination initialFor(FarmUser user) => switch (user.role) {
    'STAFF' => animals,
    'VET' => care,
    'ACCOUNTANT' => finance,
    _ => overview,
  };

  Color get tint => switch (this) {
    inventory => FarmColors.mint,
    finance || profile => FarmColors.amber,
    users || location => FarmColors.sky,
    catalog => FarmColors.lavender,
    _ => FarmColors.peach,
  };

  String descriptionFor(FarmUser user) => switch (this) {
    inventory =>
      user.canOperate ? 'Tồn kho và nhập xuất thức ăn' : 'Xem tồn kho thức ăn',
    finance => 'Sổ thu chi và báo cáo',
    users => 'Quản lý nhân viên và phân quyền',
    catalog =>
      user.isAdmin
          ? 'Quản lý loài, giống và khu vực'
          : 'Xem loài, giống và khu vực',
    profile => 'Thông tin cá nhân và bảo mật',
    location =>
      user.isAdmin
          ? 'Vị trí và thời tiết trang trại'
          : 'Xem thời tiết trang trại',
    _ => label,
  };
}
