import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

class CreateBoardDialog extends StatefulWidget {
  const CreateBoardDialog({super.key});

  @override
  State<CreateBoardDialog> createState() => _CreateBoardDialogState();
}

class _CreateBoardDialogState extends State<CreateBoardDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _create() {
    final title = _controller.text.trim();

    if (title.isEmpty) {
      return;
    }

    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 24,
      ),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(
          bottom: keyboardHeight > 0 ? 8 : 0,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 520,
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                28,
                28,
                28,
                24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ------------------------------------------------
                  // TITLE
                  // ------------------------------------------------

                  Text(
                    'Create a new board',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ------------------------------------------------
                  // TEXT FIELD
                  // ------------------------------------------------

                  TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _create(),
                    decoration: InputDecoration(
                      labelText: 'Board name',
                      hintText: 'e.g. College Project',
                      prefixIcon: const Icon(
                        Icons.dashboard_customize_outlined,
                        color: AppColors.purple,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: AppColors.purple,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ------------------------------------------------
                  // BUTTONS
                  // ------------------------------------------------

                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            minimumSize: const Size(
                              double.infinity,
                              54,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _create,
                          icon: const Icon(Icons.add),
                          label: const Text('Create'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(
                              double.infinity,
                              54,
                            ),
                            backgroundColor: AppColors.purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
