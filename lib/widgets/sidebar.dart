import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/warehouse_provider.dart';
import '../theme/app_theme.dart';

class AppSidebar extends StatelessWidget {
  final int? selectedWarehouseId;

  const AppSidebar({super.key, this.selectedWarehouseId});

  @override
  Widget build(BuildContext context) {
    final whProvider = context.watch<WarehouseProvider>();
    final warehouses = whProvider.warehouses;

    return Container(
      decoration: BoxDecoration(gradient: sidebarGradient()),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0x1AFFFFFF)),
              ),
            ),
            child: Column(
              children: [
                Text('نظام إدارة المستودعات',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.95),
                  )),
                const SizedBox(height: 2),
                Text('Warehouse Management',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 1.5,
                  )),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _SidebarLink(
                  icon: Icons.dashboard_outlined,
                  label: 'لوحة التحكم',
                  path: '/',
                  isActive: _isActive(context, '/'),
                ),
                const SizedBox(height: 4),
                for (final wh in warehouses) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(wh.name,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.35),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            )),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SidebarLink(
                    icon: Icons.inventory_2_outlined,
                    label: wh.name,
                    path: '/w/${wh.id}/inventory',
                    isActive: _isActive(context, '/w/${wh.id}/inventory'),
                    indent: true,
                  ),
                  _SidebarLink(
                    icon: Icons.description_outlined,
                    label: 'الوصولات',
                    path: '/w/${wh.id}/documents',
                    isActive: _isActive(context, '/w/${wh.id}/documents'),
                    indent: true,
                  ),
                  _SidebarLink(
                    icon: Icons.bar_chart_outlined,
                    label: 'التقارير',
                    path: '/w/${wh.id}/reports',
                    isActive: _isActive(context, '/w/${wh.id}/reports'),
                    indent: true,
                  ),
                  const SizedBox(height: 4),
                ],
                const Spacer(),
                const Divider(color: Color(0x14FFFFFF)),
                _SidebarLink(
                  icon: Icons.settings_outlined,
                  label: 'الإعدادات',
                  path: '/settings',
                  isActive: _isActive(context, '/settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isActive(BuildContext context, String path) {
    final location = GoRouterState.of(context).uri.toString();
    if (path == '/') return location == '/' || location == '/dashboard';
    return location.startsWith(path);
  }
}

class _SidebarLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;
  final bool isActive;
  final bool indent;

  const _SidebarLink({
    required this.icon,
    required this.label,
    required this.path,
    required this.isActive,
    this.indent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: isActive
            ? Colors.lightBlue.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go(path),
          child: Padding(
            padding: EdgeInsets.only(
              left: indent ? 26 : 18,
              right: indent ? 26 : 18,
              top: 11,
              bottom: 11,
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.lightBlue.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16,
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.75)),
                ),
                const SizedBox(width: 12),
                Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.72),
                  )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
