import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../providers/board_provider.dart';
import '../widgets/create_board_dialog.dart';
import '../../whiteboard/screens/whiteboard_screen.dart';
import '../../collaboration/screens/invitations_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // CREATE BOARD
  // ============================================================

  Future<void> _createBoard() async {
    final title = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const CreateBoardDialog(),
    );

    if (!mounted) return;

    if (title == null || title.trim().isEmpty) {
      return;
    }

    try {
      await ref.read(boardRepositoryProvider).createBoard(title.trim());

      ref.invalidate(boardsProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Board created successfully ✨'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not create board.\n$e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // DELETE BOARD
  // ============================================================

  Future<void> _deleteBoard(String boardId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete board?'),
          content: const Text(
            'This will permanently delete this board and its objects.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(boardRepositoryProvider).deleteBoard(boardId);

      ref.invalidate(boardsProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Board deleted.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not delete board.\n$e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    await ref.read(supabaseAuthProvider).auth.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final supabase = ref.watch(supabaseAuthProvider);

    final user = supabase.auth.currentUser;

    final boardsAsync = ref.watch(boardsProvider);

    final name = user?.userMetadata?['name']?.toString() ?? 'Creator';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: AppColors.background,

          // ----------------------------------------------------
          // MOBILE DRAWER
          // ----------------------------------------------------

          drawer: isMobile
              ? Drawer(
                  child: _buildSidebar(
                    isDrawer: true,
                  ),
                )
              : null,

          // ----------------------------------------------------
          // MOBILE APP BAR
          // ----------------------------------------------------

          appBar: isMobile
              ? AppBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  leading: Builder(
                    builder: (context) {
                      return IconButton(
                        icon: const Icon(
                          Icons.menu,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: () {
                          Scaffold.of(context).openDrawer();
                        },
                      );
                    },
                  ),
                  title: Row(
                    children: [
                      _buildLogo(size: 32),
                      const SizedBox(width: 8),
                      Text(
                        'SketchSync',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                )
              : null,

          // ----------------------------------------------------
          // BODY
          // ----------------------------------------------------

          body: isMobile
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildDashboardContent(
                      name,
                      boardsAsync,
                      isMobile: true,
                    ),
                  ),
                )
              : Row(
                  children: [
                    _buildSidebar(),
                    Expanded(
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: _buildDashboardContent(
                            name,
                            boardsAsync,
                            isMobile: false,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  // ============================================================
  // LOGO
  // ============================================================

  Widget _buildLogo({
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.purple,
        borderRadius: BorderRadius.circular(
          size * 0.28,
        ),
      ),
      child: Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: size * 0.52,
      ),
    );
  }

  // ============================================================
  // DASHBOARD CONTENT
  // ============================================================

  Widget _buildDashboardContent(
    String name,
    AsyncValue<List<Map<String, dynamic>>> boardsAsync, {
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          name,
          isMobile: isMobile,
        ),
        const SizedBox(height: 24),
        _buildSearchBar(
          isMobile: isMobile,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: boardsAsync.when(
            loading: () {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.purple,
                ),
              );
            },
            error: (error, stackTrace) {
              return _buildErrorState(
                error.toString(),
              );
            },
            data: (boards) {
              final filteredBoards = boards.where(
                (board) {
                  final title = board['title'].toString().toLowerCase();

                  return title.contains(
                    _searchQuery.toLowerCase(),
                  );
                },
              ).toList();

              if (filteredBoards.isEmpty) {
                return _buildEmptyState();
              }

              return GridView.builder(
                padding: const EdgeInsets.only(
                  bottom: 24,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 180,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: filteredBoards.length,
                itemBuilder: (context, index) {
                  final board = filteredBoards[index];

                  return _buildBoardCard(board);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SIDEBAR
  // ============================================================

  Widget _buildSidebar({
    bool isDrawer = false,
  }) {
    return Container(
      width: isDrawer ? null : 240,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: AppColors.border.withOpacity(0.7),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _buildLogo(size: 38),
                const SizedBox(width: 10),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'SketchSync',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      /*TextSpan(
                        text: ' Lite',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.purple,
                        ),
                      ),*/
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // Workspace label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'WORKSPACE',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: AppColors.textSecondary.withOpacity(0.7),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Boards
          _sidebarItem(
            icon: Icons.grid_view_rounded,
            title: 'Boards',
            selected: true,
          ),

          // Team
          _sidebarItem(
            icon: Icons.people_outline_rounded,
            title: 'Team',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InvitationsScreen(),
                ),
              );
            },
          ),

          // Settings
          _sidebarItem(
            icon: Icons.settings_outlined,
            title: 'Settings',
          ),

          const Spacer(),

          // Logout
          _sidebarItem(
            icon: Icons.logout_rounded,
            title: 'Logout',
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem({
    required IconData icon,
    required String title,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.purple.withOpacity(0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(
                      color: AppColors.purple.withOpacity(0.08),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? AppColors.purple : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color:
                          selected ? AppColors.purple : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.purple,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(
    String name, {
    required bool isMobile,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.purple.withOpacity(0.10),
            AppColors.blue.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.purple.withOpacity(0.08),
        ),
      ),
      child: isMobile
          ? _buildMobileHeaderContent(name)
          : _buildDesktopHeaderContent(name),
    );
  }

  Widget _buildDesktopHeaderContent(String name) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning,',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Turn your ideas into something amazing.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        ElevatedButton.icon(
          onPressed: _createBoard,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Board'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 16,
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileHeaderContent(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.purple,
                size: 22,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _createBoard,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 18),
        /*Text(
          'Good morning,',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),*/
        const SizedBox(height: 3),
        Text(
          name,
          style: GoogleFonts.poppins(
            fontSize: 27,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Turn your ideas into something amazing.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearchBar({
    required bool isMobile,
  }) {
    return SizedBox(
      width: isMobile ? double.infinity : 420,
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search your boards...',
          prefixIcon: const Icon(
            Icons.search,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();

                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(
                    Icons.close,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  // ============================================================
  // BOARD CARD
  // ============================================================

  Widget _buildBoardCard(
    Map<String, dynamic> board,
  ) {
    final title = board['title']?.toString() ?? 'Untitled Board';
    final boardId = board['id']?.toString() ?? '';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: AppColors.border.withOpacity(0.8),
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WhiteboardScreen(
                boardId: boardId,
                boardTitle: title,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview area
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.purple.withOpacity(0.10),
                      AppColors.blue.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative grid
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _BoardGridPainter(),
                      ),
                    ),

                    // Board icon
                    Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.dashboard_customize_outlined,
                          color: AppColors.purple,
                          size: 25,
                        ),
                      ),
                    ),

                    // Menu
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Material(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                        child: PopupMenuButton<String>(
                          tooltip: 'Board options',
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.more_horiz_rounded,
                            size: 21,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onSelected: (value) {
                            if (value == 'delete') {
                              _deleteBoard(boardId);
                            }
                          },
                          itemBuilder: (context) {
                            return const [
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: AppColors.error,
                                    ),
                                    SizedBox(width: 10),
                                    Text('Delete board'),
                                  ],
                                ),
                              ),
                            ];
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Board information
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Collaborative board',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.purple.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: AppColors.purple,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================
  Widget _buildEmptyState() {
    final hasSearch = _searchQuery.trim().isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /*Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 42,
                color: AppColors.purple,
              ),
            ),*/
            SvgPicture.asset(
              'assets/illustrations/empty_board.svg',
              width: 290,
              height: 290,
            ),
            const SizedBox(height: 20),
            Text(
              hasSearch ? 'No boards found' : 'Your canvas is waiting ',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Try searching for another board.'
                  : 'Create your first board and start sketching.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _createBoard,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Board'),
              ),
            ],
          ],
        ),
      ),
    );
  }
  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load boards',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(
                  boardsProvider,
                );
              },
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Try again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withOpacity(0.45)
      ..strokeWidth = 0.6;

    const spacing = 22.0;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
