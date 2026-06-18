import 'package:flutter/material.dart';
import 'sidebar.dart';
import 'toast.dart';

class AppLayout extends StatelessWidget {
  final Widget child;
  final int? warehouseId;

  const AppLayout({super.key, required this.child, this.warehouseId});

  @override
  Widget build(BuildContext context) {
    return ToastOverlay(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          if (isWide) {
            return _DesktopLayout(warehouseId: warehouseId, child: child);
          }
          return _MobileLayout(warehouseId: warehouseId, child: child);
        },
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  final int? warehouseId;
  final Widget child;

  const _DesktopLayout({required this.warehouseId, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 240,
            child: AppSidebar(selectedWarehouseId: warehouseId),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final int? warehouseId;
  final Widget child;

  const _MobileLayout({required this.warehouseId, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نظام إدارة المستودعات'),
      ),
      drawer: SizedBox(
        width: 240,
        child: Drawer(
          child: AppSidebar(selectedWarehouseId: warehouseId),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
