import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/work_report_models.dart';
import '../theme/work_report_colors.dart';

class ContractBanner extends StatelessWidget {
  final String contractType;
  final String employeeName;
  final String employeeId;

  const ContractBanner({
    super.key,
    required this.contractType,
    required this.employeeName,
    required this.employeeId,
  });

  @override
  Widget build(BuildContext context) {
    final isField = contractType == ContractType.field;
    final fill = isField
        ? WorkReportColors.fieldContract
        : WorkReportColors.adminContract;
    final pillLabel = isField ? 'FIELD CONTRACT' : 'ADMIN CONTRACT';
    final descriptor = isField
        ? 'Time blocks tag to projects or job orders.'
        : 'Time blocks tag to departments or admin projects.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(color: WorkReportColors.midnight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pillLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                employeeId,
                style: const TextStyle(
                  color: WorkReportColors.stone,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => context.push('/work-report/admin/lookups'),
                borderRadius: BorderRadius.circular(999),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.tune,
                    size: 18,
                    color: WorkReportColors.stone,
                    semanticLabel: 'Manage projects & tasks',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            employeeName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            descriptor,
            style: const TextStyle(
              color: WorkReportColors.stone,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
