import 'package:flutter/material.dart';
import '../utils/purchase_manager.dart';


class ModeToggle extends StatelessWidget {
  final bool isSequential;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onLockedTap;

  const ModeToggle({
    super.key,
    required this.isSequential,
    required this.onModeChanged,
    required this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    
    return Container(
      width: 200,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: isSequential ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 100,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF2C3E50),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onModeChanged(false),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Icon(
                      Icons.shuffle,
                      color: !isSequential ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: PurchaseManager.instance.isPremium,
                  builder: (context, isPremium, child) {
                    return GestureDetector(
                      onTap: isPremium ? () => onModeChanged(true) : onLockedTap,
                      behavior: HitTestBehavior.opaque,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.format_list_numbered,
                            color: isSequential ? Colors.white : Colors.grey.shade600,
                          ),
                          if (!isPremium)
                            const Icon(
                              Icons.lock,
                              size: 32,
                              color: Colors.black45,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
