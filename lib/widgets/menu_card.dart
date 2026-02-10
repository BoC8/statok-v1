import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? colorOverride;

  const MenuCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.colorOverride,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4, 
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorOverride ?? Colors.white,
                colorOverride != null 
                    ? colorOverride!.withOpacity(0.8) 
                    : Colors.grey.shade50,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: colorOverride != null ? Colors.white : AppTheme.bleuMarine,
              ),
              const SizedBox(height: 12),
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorOverride != null ? Colors.white : AppTheme.bleuMarine,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}