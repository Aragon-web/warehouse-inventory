import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/warehouse_provider.dart';
import '../theme/app_theme.dart';
import '../utils/carton_packet.dart';
import '../widgets/confirm_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DashboardProvider>();
    final warehouses = context.watch<WarehouseProvider>().warehouses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('لوحة التحكم',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<int>(
                value: dp.warehouseId,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('جميع المستودعات')),
                  for (final w in warehouses)
                    DropdownMenuItem(value: w.id, child: Text(w.name)),
                ],
                onChanged: (v) {
                  if (v != null) dp.setWarehouse(v);
                },
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('تحديث'),
              onPressed: () => dp.load(warehouseId: dp.warehouseId),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (dp.loading)
          const Expanded(child: LoadingSpinner())
        else if (dp.error != null)
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0x44F43F5E)
                    : const Color(0x33F43F5E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(dp.error!,
                style: const TextStyle(color: Color(0xFFE11D48), fontSize: 13)),
            ),
          )
        else ...[
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 1000 ? 3
                    : constraints.maxWidth > 600 ? 2 : 1;
                return GridView(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.6,
                  ),
                  children: [
                    _StatCard(
                      label: 'عدد المنتجات النشطة',
                      value: '${dp.productCount}',
                      sub: 'منتج',
                      color: AppColors.accent600,
                    ),
                    _StatCard(
                      label: 'إجمالي المخزون',
                      value: formatQty(dp.totalQuantity),
                      sub: 'وحدة أساسية',
                      color: AppColors.cyan600,
                    ),
                    _StatCard(
                      label: 'حركات اليوم',
                      value: '${dp.todayTotal}',
                      sub: 'وارد ${dp.todayProduction} | صادر ${dp.todaySales}',
                      color: AppColors.accent600,
                    ),
                    _StatCard(
                      label: 'أرصدة سالبة',
                      value: '${dp.negativeCount}',
                      sub: 'منتج برصيد أقل من الصفر',
                      color: dp.negativeCount > 0
                          ? AppColors.rose600
                          : AppColors.emerald600,
                    ),
                    _StatCard(
                      label: 'تحت الحد الأدنى',
                      value: '${dp.belowMinCount}',
                      sub: 'منتج وصل للحد الأدنى',
                      color: dp.belowMinCount > 0
                          ? AppColors.amber600
                          : AppColors.emerald600,
                    ),
                    _StatCard(
                      label: 'الكميات الواردة',
                      value: formatQty(dp.monthReceived),
                      sub: 'وحدة أساسية خلال الشهر',
                      color: AppColors.accent600,
                    ),
                    _StatCard(
                      label: 'الكميات المنصرفة',
                      value: formatQty(dp.monthIssued),
                      sub: 'وحدة أساسية خلال الشهر',
                      color: AppColors.amber600,
                    ),
                    _StatCard(
                      label: 'التالف والفاقد',
                      value: formatQty(dp.monthLost),
                      sub: 'وحدة أساسية خلال الشهر',
                      color: AppColors.accent600,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodySmall?.color,
              )),
            const Spacer(),
            Text(value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: -1,
              )),
            const SizedBox(height: 6),
            Text(sub,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              )),
          ],
        ),
      ),
    );
  }
}
