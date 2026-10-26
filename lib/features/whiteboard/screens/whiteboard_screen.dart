import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/whiteboard_repository.dart';
import '../../collaboration/widgets/invite_collaborator_dialog.dart';

class WhiteboardScreen extends StatefulWidget {
  final String boardId;
  final String boardTitle;

  const WhiteboardScreen({
    super.key,
    required this.boardId,
    required this.boardTitle,
  });

  @override
  State<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends State<WhiteboardScreen> {
  @override
  void initState() {
    super.initState();

    _loadStickyNotes();
    _loadStrokes();
    _loadShapes();
    _loadBoardRole();

    _boardChannel = Supabase.instance.client
        .channel('board_${widget.boardId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'board_objects',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'board_id',
            value: widget.boardId,
          ),
          callback: (payload) {
            debugPrint(
              'REALTIME INSERT RECEIVED: ${payload.newRecord}',
            );

            final record = payload.newRecord;
            final id = record['id']?.toString();

            if (id == null) return;
            if (!mounted) return;

            setState(() {
              // Prevent duplicate objects
              final alreadyExists = _stickyNotes.any((note) => note.id == id) ||
                  _strokeIds.contains(id) ||
                  _shapes.any((shape) => shape.id == id);

              if (alreadyExists) return;

              final object = _createObjectFromRealtimeRecord(record);

              if (object is StickyNote) {
                _stickyNotes.add(object);
              } else if (object is List<Offset>) {
                _strokes.add(object);
                _strokeIds.add(id);
              } else if (object is WhiteboardShape) {
                _shapes.add(object);
              }
            });
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'board_objects',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'board_id',
            value: widget.boardId,
          ),
          callback: (payload) {
            debugPrint(
              'REALTIME UPDATE RECEIVED: ${payload.newRecord}',
            );

            final record = payload.newRecord;

            if (record['type'] != 'sticky_note') {
              return;
            }

            final id = record['id'] as String;

            final data = Map<String, dynamic>.from(
              record['data'] as Map,
            );

            final updatedNote = StickyNote(
              id: id,
              position: Offset(
                (data['x'] as num).toDouble(),
                (data['y'] as num).toDouble(),
              ),
              text: (data['text'] ?? '').toString(),
            );

            if (!mounted) return;

            setState(() {
              final index = _stickyNotes.indexWhere(
                (note) => note.id == id,
              );

              if (index == -1) {
                return;
              }

              _stickyNotes[index] = updatedNote;

              // Keep the delete/bin icon attached to the updated note.
              if (_selectedStickyNote?.id == id) {
                _selectedStickyNote = updatedNote;
              }
            });
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'board_objects',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'board_id',
            value: widget.boardId,
          ),
          callback: (payload) {
            debugPrint(
              'REALTIME DELETE RECEIVED',
            );

            debugPrint(
              'DELETE OLD RECORD: ${payload.oldRecord}',
            );

            final record = payload.oldRecord;

            final id = record['id']?.toString();

            debugPrint(
              'DELETE OBJECT ID: $id',
            );

            if (id == null) {
              debugPrint(
                'DELETE FAILED: No object ID received',
              );
              return;
            }

            if (!mounted) return;

            setState(() {
              _stickyNotes.removeWhere(
                (note) => note.id == id,
              );

              final strokeIndex = _strokeIds.indexOf(id);

              if (strokeIndex != -1) {
                _strokeIds.removeAt(strokeIndex);
                _strokes.removeAt(strokeIndex);
              }

              _shapes.removeWhere(
                (shape) => shape.id == id,
              );

              if (_selectedStickyNote?.id == id) {
                _selectedStickyNote = null;
              }
            });

            debugPrint(
              'DELETE APPLIED TO CANVAS: $id',
            );
          },
        )
        .subscribe((status, error) {
      debugPrint('Realtime status: $status');

      if (error != null) {
        debugPrint('Realtime error: $error');
      }
    });
  }

  final WhiteboardRepository _repository =
      WhiteboardRepository(Supabase.instance.client);

  RealtimeChannel? _boardChannel;

  final List<List<Offset>> _strokes = [];
  final List<String> _strokeIds = [];
  final List<WhiteboardShape> _shapes = [];
  // final List<String> _shapeIds = [];
  final List<StickyNote> _stickyNotes = [];

  Future<void> _loadStickyNotes() async {
    try {
      final rows = await _repository.getStickyNotes(
        boardId: widget.boardId,
      );

      final notes = rows.map((row) {
        final data = Map<String, dynamic>.from(row['data'] as Map);

        return StickyNote(
          id: row['id'] as String,
          text: (data['text'] ?? '').toString(),
          position: Offset(
            (data['x'] as num).toDouble(),
            (data['y'] as num).toDouble(),
          ),
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _stickyNotes
          ..clear()
          ..addAll(notes);
      });
    } catch (e) {
      debugPrint('Failed to load sticky notes: $e');
    }
  }

  Future<void> _loadStrokes() async {
    try {
      final rows = await _repository.getStrokes(
        boardId: widget.boardId,
      );

      for (final row in rows) {
        final data = Map<String, dynamic>.from(
          row['data'] as Map,
        );

        final points = (data['points'] as List)
            .map(
              (point) => Offset(
                (point['x'] as num).toDouble(),
                (point['y'] as num).toDouble(),
              ),
            )
            .toList();

        if (points.isNotEmpty) {
          _strokes.add(points);
          _strokeIds.add(row['id'] as String);
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to load strokes: $e');
    }
  }

  Future<void> _loadShapes() async {
    try {
      final rows = await _repository.getShapes(
        boardId: widget.boardId,
      );

      for (final row in rows) {
        final data = Map<String, dynamic>.from(row['data'] as Map);

        final start = Offset(
          (data['startX'] as num).toDouble(),
          (data['startY'] as num).toDouble(),
        );

        final end = Offset(
          (data['endX'] as num).toDouble(),
          (data['endY'] as num).toDouble(),
        );

        final type =
            row['type'] == 'rectangle' ? ShapeType.rectangle : ShapeType.circle;

        _shapes.add(
          WhiteboardShape(
            id: row['id'] as String,
            type: type,
            start: start,
            end: end,
          ),
        );

        //_shapeIds.add(row['id'] as String);
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to load shapes: $e');
    }
  }

  dynamic _createObjectFromRealtimeRecord(
    Map<String, dynamic> record,
  ) {
    final type = record['type'] as String;
    final data = Map<String, dynamic>.from(record['data'] as Map);
    final id = record['id'] as String;

    if (type == 'sticky_note') {
      return StickyNote(
        id: id,
        position: Offset(
          (data['x'] as num).toDouble(),
          (data['y'] as num).toDouble(),
        ),
        text: (data['text'] ?? '').toString(),
      );
    }

    if (type == 'stroke') {
      final points = (data['points'] as List)
          .map(
            (point) => Offset(
              (point['x'] as num).toDouble(),
              (point['y'] as num).toDouble(),
            ),
          )
          .toList();

      return points;
    }

    if (type == 'rectangle' || type == 'circle') {
      return WhiteboardShape(
        id: id,
        type: type == 'rectangle' ? ShapeType.rectangle : ShapeType.circle,
        start: Offset(
          (data['startX'] as num).toDouble(),
          (data['startY'] as num).toDouble(),
        ),
        end: Offset(
          (data['endX'] as num).toDouble(),
          (data['endY'] as num).toDouble(),
        ),
      );
    }

    return null;
  }

  Future<void> _loadBoardRole() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return;
    }

    final response = await Supabase.instance.client
        .from('board_members')
        .select('role')
        .eq('board_id', widget.boardId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (!mounted) return;

    setState(() {
      _boardRole = response?['role'] as String?;
      _isLoadingRole = false;
    });
  }

  bool get _canEdit {
    return _boardRole == 'owner' || _boardRole == 'editor';
  }

  bool _isPenSelected = false;
  bool _isEraserSelected = false;
  bool _isErasingObject = false;
  bool _isRectangleSelected = false;
  bool _isCircleSelected = false;
  bool _isStickyNoteSelected = false;
  bool _isSelectMode = false; //true;
  bool _hasPenMoved = false;
  String? _boardRole;
  bool _isLoadingRole = true;
  Offset? _shapeStart;
  Offset? _shapeEnd;

  StickyNote? _selectedStickyNote;
  Offset? _dragOffset;

  // ============================================================
  // CANVAS GESTURES
  // ============================================================

  void _startStroke(DragStartDetails details) {
    if (!_canEdit) return;
    final position = details.localPosition;

    // Select / move mode
    if (_isSelectMode) {
      final note = _findStickyNoteAt(position);

      if (note != null) {
        setState(() {
          _selectedStickyNote = note;
          _dragOffset = position - note.position;
        });
      } else {
        setState(() {
          _selectedStickyNote = null;
          _dragOffset = null;
        });
      }

      return;
    }

    // Eraser
    if (_isEraserSelected) {
      _eraseAtPosition(position);
      return;
    }

    // Sticky note
    if (_isStickyNoteSelected) {
      _addStickyNote(position);
      return;
    }

    // Rectangle / Circle
    if (_isRectangleSelected || _isCircleSelected) {
      setState(() {
        _shapeStart = position;
        _shapeEnd = position;
      });
      return;
    }

    // Pen
    // Pen
    if (!_isPenSelected) return;

    _hasPenMoved = false;

    setState(() {
      _strokes.add([position]);
    });
  }

  void _updateStroke(DragUpdateDetails details) {
    if (!_canEdit) return;
    final position = details.localPosition;

    // Move selected sticky note
    if (_isSelectMode) {
      if (_selectedStickyNote != null && _dragOffset != null) {
        final newPosition = position - _dragOffset!;

        setState(() {
          _selectedStickyNote!.position = newPosition;
        });
      }

      return;
    }

    // Eraser
    if (_isEraserSelected) {
      _eraseAtPosition(position);
      return;
    }

    // Sticky note
    if (_isStickyNoteSelected) {
      return;
    }

    // Rectangle / Circle
    if (_isRectangleSelected || _isCircleSelected) {
      setState(() {
        _shapeEnd = position;
      });
      return;
    }

    // Pen
    // Pen
    if (!_isPenSelected || _strokes.isEmpty) return;

    _hasPenMoved = true;

    setState(() {
      _strokes.last.add(position);
    });
  }

  Future<void> _endStroke(DragEndDetails details) async {
    if (!_canEdit) return;
    // SELECT MODE
    if (_isSelectMode) {
      final note = _selectedStickyNote;

      setState(() {
        _dragOffset = null;
      });

      if (note != null) {
        try {
          await _repository.updateStickyNotePosition(
            objectId: note.id,
            x: note.position.dx,
            y: note.position.dy,
          );
        } catch (e) {
          debugPrint('Failed to update sticky note position: $e');
        }
      }

      return;
    }

    // PEN MODE
    if (_isPenSelected && _strokes.isNotEmpty) {
      final stroke = _strokes.last;

      if (stroke.isEmpty) return;

      try {
        final strokeId = await _repository.createStroke(
          boardId: widget.boardId,
          points: stroke,
        );

        _strokeIds.add(strokeId);
      } catch (e) {
        debugPrint('Failed to save stroke: $e');
      }

      return;
    }

    // SHAPE MODE
    if (_shapeStart == null || _shapeEnd == null) return;
    if (_isRectangleSelected || _isCircleSelected) {
      final start = _shapeStart!;
      final end = _shapeEnd!;

      final shapeType = _isRectangleSelected ? 'rectangle' : 'circle';

      try {
        final shapeId = await _repository.createShape(
          boardId: widget.boardId,
          type: shapeType,
          start: start,
          end: end,
        );

        setState(() {
          _shapes.add(
            WhiteboardShape(
              id: shapeId,
              type:
                  _isRectangleSelected ? ShapeType.rectangle : ShapeType.circle,
              start: start,
              end: end,
            ),
          );

          // _shapeIds.add(shapeId);

          _shapeStart = null;
          _shapeEnd = null;
        });
      } catch (e) {
        debugPrint('Failed to save shape: $e');

        setState(() {
          _shapeStart = null;
          _shapeEnd = null;
        });
      }
    }
  }

  // ============================================================
  // FIND STICKY NOTE
  // ============================================================

  StickyNote? _findStickyNoteAt(Offset position) {
    const double noteWidth = 150;
    const double noteHeight = 120;

    for (int i = _stickyNotes.length - 1; i >= 0; i--) {
      final note = _stickyNotes[i];

      final rect = Rect.fromLTWH(
        note.position.dx,
        note.position.dy,
        noteWidth,
        noteHeight,
      );

      if (rect.contains(position)) {
        return note;
      }
    }

    return null;
  }

  // ============================================================
  // EDIT STICKY NOTE
  // ============================================================

  void _editStickyNote(StickyNote note) {
    if (!_canEdit) return;
    final controller = TextEditingController(
      text: note.text,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Edit Sticky Note',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Write your note...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = controller.text.trim();

                if (text.isEmpty) return;

                try {
                  await _repository.updateStickyNoteText(
                    objectId: note.id,
                    text: text,
                  );

                  if (!mounted) return;

                  setState(() {
                    note.text = text;
                  });

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update sticky note: $e'),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // DELETE STICKY NOTE
  // ============================================================

  Future<void> _deleteStickyNote(StickyNote note) async {
    if (!_canEdit) return;
    try {
      await _repository.deleteStickyNote(
        objectId: note.id,
      );

      if (!mounted) return;

      setState(() {
        _stickyNotes.remove(note);
        _selectedStickyNote = null;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete sticky note: $e'),
        ),
      );
    }
  }

  // ============================================================
  // ERASER
  // ============================================================
  Future<void> _eraseAtPosition(Offset position) async {
    //const double eraserRadius = 25;
    if (!_canEdit) return;
    if (_isErasingObject) return;

    _isErasingObject = true;

    // ============================================================
// ERASE PEN STROKES
// ============================================================
    /* for (int i = _shapes.length - 1; i >= 0; i--) {
      final shape = _shapes[i];

      final rect = Rect.fromPoints(
        shape.start,
        shape.end,
      );

      bool hit = false;

      if (shape.type == ShapeType.rectangle) {
        // Check only the rectangle border.
        const hitDistance = 25.0;

        final topDistance = (position.dy - rect.top).abs();
        final bottomDistance = (position.dy - rect.bottom).abs();
        final leftDistance = (position.dx - rect.left).abs();
        final rightDistance = (position.dx - rect.right).abs();

        final horizontalRange = position.dx >= rect.left - hitDistance &&
            position.dx <= rect.right + hitDistance;

        final verticalRange = position.dy >= rect.top - hitDistance &&
            position.dy <= rect.bottom + hitDistance;

        hit = (horizontalRange && topDistance <= hitDistance) ||
            (horizontalRange && bottomDistance <= hitDistance) ||
            (verticalRange && leftDistance <= hitDistance) ||
            (verticalRange && rightDistance <= hitDistance);
      } else {
        // Check the actual oval boundary.
        final center = rect.center;

        final radiusX = rect.width / 2;
        final radiusY = rect.height / 2;

        if (radiusX > 0 && radiusY > 0) {
          final dx = position.dx - center.dx;
          final dy = position.dy - center.dy;

          final normalizedDistance = math.sqrt(
            (dx * dx) / (radiusX * radiusX) + (dy * dy) / (radiusY * radiusY),
          );

          const hitTolerance = 0.20;

          hit = (normalizedDistance - 1).abs() <= hitTolerance;
        }
      }

      if (hit) {
        final shapeId = _shapeIds[i];

        try {
          await _repository.deleteBoardObject(
            objectId: shapeId,
          );

          setState(() {
            _shapes.removeAt(i);
            _shapeIds.removeAt(i);
          });
        } catch (e) {
          debugPrint('Failed to delete shape: $e');
        }

        return;
      }
    }*/
// ============================================================
// ERASE PEN STROKES
// ============================================================

    const double eraserRadius = 25;

    for (int i = _strokes.length - 1; i >= 0; i--) {
      final stroke = _strokes[i];

      bool hit = false;

      for (final point in stroke) {
        if ((position - point).distance <= eraserRadius) {
          hit = true;
          break;
        }
      }

      if (hit) {
        final strokeId = _strokeIds[i];

        try {
          await _repository.deleteBoardObject(
            objectId: strokeId,
          );

          setState(() {
            _strokes.removeAt(i);
            _strokeIds.removeAt(i);
          });
        } catch (e) {
          debugPrint('Failed to delete stroke: $e');
        }

        _isErasingObject = false;
        return;
      }
    }
    // ============================================================
    // ERASE SHAPES
    // ============================================================

    for (int i = _shapes.length - 1; i >= 0; i--) {
      final shape = _shapes[i];

      final rect = Rect.fromPoints(
        shape.start,
        shape.end,
      );

      bool hit = false;

      if (shape.type == ShapeType.rectangle) {
        // Check the rectangle border instead of the whole area.
        const hitDistance = 10.0;

        final top = (position.dy - rect.top).abs();
        final bottom = (position.dy - rect.bottom).abs();
        final left = (position.dx - rect.left).abs();
        final right = (position.dx - rect.right).abs();

        final insideHorizontal = position.dx >= rect.left - hitDistance &&
            position.dx <= rect.right + hitDistance;

        final insideVertical = position.dy >= rect.top - hitDistance &&
            position.dy <= rect.bottom + hitDistance;

        hit = (insideHorizontal && top <= hitDistance) ||
            (insideHorizontal && bottom <= hitDistance) ||
            (insideVertical && left <= hitDistance) ||
            (insideVertical && right <= hitDistance);
      } else if (shape.type == ShapeType.circle) {
        // Check the circle boundary.
        final center = rect.center;
        final radius = math.min(rect.width, rect.height) / 2;

        final distance = (position - center).distance;

        hit = (distance - radius).abs() <= 10;
      }

      if (hit) {
        final shapeId = shape.id;

        try {
          await _repository.deleteBoardObject(
            objectId: shapeId,
          );

          setState(() {
            _shapes.removeAt(i);
            //_shapeIds.removeAt(i);
          });
        } catch (e) {
          debugPrint('Failed to delete shape: $e');
        }
        _isErasingObject = false;
        return;
      }
    }

    _isErasingObject = false;
  }

  // ============================================================
  // ADD STICKY NOTE
  // ============================================================

  void _addStickyNote(Offset position) {
    if (!_canEdit) return;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Add Sticky Note',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Write your note...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = controller.text.trim();

                if (text.isEmpty) return;

                try {
                  final noteId = await _repository.createStickyNote(
                    boardId: widget.boardId,
                    x: position.dx,
                    y: position.dy,
                    text: text,
                  );

                  if (!mounted) return;

                  setState(() {
                    final newNote = StickyNote(
                      id: noteId,
                      position: position,
                      text: text,
                    );

                    _stickyNotes.add(newNote);

                    _selectedStickyNote = newNote;

                    _isStickyNoteSelected = false;
                    _isSelectMode = true;
                  });

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sticky note saved'),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to save sticky note: $e'),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: _buildCanvas(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.dashboard_customize_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 150,
            child: Text(
              widget.boardTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Select
                  _buildToolButton(
                    icon: Icons.pan_tool_outlined,
                    tooltip: 'Select',
                    isSelected: _isSelectMode,
                    onPressed: () {
                      setState(() {
                        _isSelectMode = true;
                        _isPenSelected = false;
                        _isEraserSelected = false;
                        _isRectangleSelected = false;
                        _isCircleSelected = false;
                        _isStickyNoteSelected = false;
                      });
                    },
                  ),

                  // Pen
                  if (_canEdit) ...[
                    _buildToolButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'Pen',
                      isSelected: _isPenSelected,
                      onPressed: () {
                        setState(() {
                          _isPenSelected = true;
                          _isEraserSelected = false;
                          _isRectangleSelected = false;
                          _isCircleSelected = false;
                          _isStickyNoteSelected = false;
                          _isSelectMode = false;
                        });
                      },
                    ),

                    // Eraser
                    _buildToolButton(
                      icon: Icons.auto_fix_high_outlined,
                      tooltip: 'Eraser',
                      isSelected: _isEraserSelected,
                      onPressed: () {
                        setState(() {
                          _isEraserSelected = true;
                          _isPenSelected = false;
                          _isRectangleSelected = false;
                          _isCircleSelected = false;
                          _isStickyNoteSelected = false;
                          _isSelectMode = false;
                        });
                      },
                    ),

                    // Sticky Note
                    _buildToolButton(
                      icon: Icons.sticky_note_2_outlined,
                      tooltip: 'Sticky Note',
                      isSelected: _isStickyNoteSelected,
                      onPressed: () {
                        setState(() {
                          _isStickyNoteSelected = true;
                          _isPenSelected = false;
                          _isEraserSelected = false;
                          _isRectangleSelected = false;
                          _isCircleSelected = false;
                          _isSelectMode = false;
                        });
                      },
                    ),

                    // Rectangle
                    _buildToolButton(
                      icon: Icons.rectangle_outlined,
                      tooltip: 'Rectangle',
                      isSelected: _isRectangleSelected,
                      onPressed: () {
                        setState(() {
                          _isRectangleSelected = true;
                          _isCircleSelected = false;
                          _isPenSelected = false;
                          _isEraserSelected = false;
                          _isStickyNoteSelected = false;
                          _isSelectMode = false;
                        });
                      },
                    ),

                    // Circle
                    _buildToolButton(
                      icon: Icons.circle_outlined,
                      tooltip: 'Circle',
                      isSelected: _isCircleSelected,
                      onPressed: () {
                        setState(() {
                          _isCircleSelected = true;
                          _isRectangleSelected = false;
                          _isPenSelected = false;
                          _isEraserSelected = false;
                          _isStickyNoteSelected = false;
                          _isSelectMode = false;
                        });
                      },
                    ),
                  ],

                  const SizedBox(width: 12),

                  // Share - Owner only
                  if (!_isLoadingRole && _boardRole == 'owner')
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => InviteCollaboratorDialog(
                            boardId: widget.boardId,
                          ),
                        );
                      },
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 18,
                              color: Color(0xFF6B7280),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Share',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOOL BUTTON
  // ============================================================

  Widget _buildToolButton({
    required IconData icon,
    required String tooltip,
    bool isSelected = false,
    VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          onPressed: onPressed ?? () {},
          tooltip: tooltip,
          icon: Icon(
            icon,
            size: 21,
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CANVAS
  // ============================================================

  Widget _buildCanvas() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        // ----------------------------------------------------------
        // SINGLE TAP
        // ----------------------------------------------------------
        onTapDown: (details) {
          if (!_canEdit) return;
          final position = details.localPosition;

          // Sticky Note
          if (_isStickyNoteSelected) {
            _addStickyNote(position);
            return;
          }

          // Pen single-click point
          if (_isPenSelected) {
            setState(() {
              _strokes.add([position]);
            });
          }
        },

        // ----------------------------------------------------------
        // DOUBLE TAP - EDIT STICKY NOTE
        // ----------------------------------------------------------
        onDoubleTapDown: (details) {
          if (!_canEdit) return;
          if (!_isSelectMode) return;

          final note = _findStickyNoteAt(
            details.localPosition,
          );

          if (note != null) {
            _editStickyNote(note);
          }
        },

        // ----------------------------------------------------------
        // DRAG
        // ----------------------------------------------------------
        onPanStart: _startStroke,
        onPanUpdate: _updateStroke,
        onPanEnd: _endStroke,

        child: Stack(
          children: [
            // --------------------------------------------------------
            // WHITEBOARD
            // --------------------------------------------------------
            CustomPaint(
              painter: WhiteboardPainter(
                strokes: _strokes,
                shapes: _shapes,
                stickyNotes: _stickyNotes,
                selectedStickyNote: _selectedStickyNote,
                previewShape: _shapeStart != null && _shapeEnd != null
                    ? WhiteboardShape(
                        id: '',
                        type: _isRectangleSelected
                            ? ShapeType.rectangle
                            : ShapeType.circle,
                        start: _shapeStart!,
                        end: _shapeEnd!,
                      )
                    : null,
              ),
              child: const SizedBox.expand(),
            ),

            // --------------------------------------------------------
            // DELETE BUTTON
            // --------------------------------------------------------
            // --------------------------------------------------------
            if (_selectedStickyNote != null)
              Positioned(
                left: _selectedStickyNote!.position.dx + 116,
                top: _selectedStickyNote!.position.dy - 12,
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: () {
                      final note = _selectedStickyNote;

                      if (note != null) {
                        _deleteStickyNote(note);
                      }
                    },

                    // Drag delete button together with sticky note
                    onPanUpdate: (details) {
                      if (!_canEdit) return;

                      final note = _selectedStickyNote;

                      if (note == null) return;

                      setState(() {
                        note.position += details.delta;
                      });
                    },

                    onPanEnd: (details) async {
                      final note = _selectedStickyNote;

                      if (note == null) return;

                      try {
                        await _repository.updateStickyNotePosition(
                          objectId: note.id,
                          x: note.position.dx,
                          y: note.position.dy,
                        );
                      } catch (e) {
                        debugPrint(
                          'Failed to update sticky note position: $e',
                        );
                      }
                    },

                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        size: 17,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_boardChannel != null) {
      Supabase.instance.client.removeChannel(
        _boardChannel!,
      );
    }

    super.dispose();
  }
}

// ============================================================
// WHITEBOARD PAINTER
// ============================================================

class WhiteboardPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<WhiteboardShape> shapes;
  final List<StickyNote> stickyNotes;
  final StickyNote? selectedStickyNote;
  final WhiteboardShape? previewShape;

  WhiteboardPainter({
    required this.strokes,
    required this.shapes,
    required this.stickyNotes,
    required this.selectedStickyNote,
    this.previewShape,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF374151)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // ----------------------------------------------------------
    // FREEHAND STROKES
    // ----------------------------------------------------------

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;

      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first,
          2,
          paint..style = PaintingStyle.fill,
        );

        paint.style = PaintingStyle.stroke;
        continue;
      }

      final path = Path();

      path.moveTo(
        stroke.first.dx,
        stroke.first.dy,
      );

      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(
          stroke[i].dx,
          stroke[i].dy,
        );
      }

      canvas.drawPath(
        path,
        paint,
      );
    }

    // ----------------------------------------------------------
    // SHAPES
    // ----------------------------------------------------------

    for (final shape in shapes) {
      _drawShape(
        canvas,
        paint,
        shape,
      );
    }

    // ----------------------------------------------------------
    // SHAPE PREVIEW
    // ----------------------------------------------------------

    if (previewShape != null) {
      final previewPaint = Paint()
        ..color = const Color(0xFF8B5CF6)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      _drawShape(
        canvas,
        previewPaint,
        previewShape!,
      );
    }

    // ----------------------------------------------------------
    // STICKY NOTES
    // ----------------------------------------------------------

    for (final note in stickyNotes) {
      _drawStickyNote(
        canvas,
        note,
        note == selectedStickyNote,
      );
    }
  }

  // ============================================================
  // DRAW SHAPE
  // ============================================================

  void _drawShape(
    Canvas canvas,
    Paint paint,
    WhiteboardShape shape,
  ) {
    final rect = Rect.fromPoints(
      shape.start,
      shape.end,
    );

    if (shape.type == ShapeType.rectangle) {
      canvas.drawRect(
        rect,
        paint,
      );
    } else {
      canvas.drawOval(
        rect,
        paint,
      );
    }
  }

  // ============================================================
  // DRAW STICKY NOTE
  // ============================================================

  void _drawStickyNote(
    Canvas canvas,
    StickyNote note,
    bool isSelected,
  ) {
    const double noteWidth = 150;
    const double noteHeight = 120;

    final rect = Rect.fromLTWH(
      note.position.dx,
      note.position.dy,
      noteWidth,
      noteHeight,
    );

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final shadowRect = Rect.fromLTWH(
      note.position.dx + 3,
      note.position.dy + 4,
      noteWidth,
      noteHeight,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        shadowRect,
        const Radius.circular(8),
      ),
      shadowPaint,
    );

    // Note
    final notePaint = Paint()
      ..color = const Color(0xFFFFF3B0)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        const Radius.circular(8),
      ),
      notePaint,
    );

    // Selection border
    if (isSelected) {
      final selectionPaint = Paint()
        ..color = const Color(0xFF8B5CF6)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          const Radius.circular(8),
        ),
        selectionPaint,
      );
    }

    // Top accent
    final accentPaint = Paint()
      ..color = const Color(0xFFF5D76E)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          note.position.dx,
          note.position.dy,
          noteWidth,
          6,
        ),
        const Radius.circular(8),
      ),
      accentPaint,
    );

    // Text
    final textPainter = TextPainter(
      text: TextSpan(
        text: note.text,
        style: const TextStyle(
          color: Color(0xFF374151),
          fontSize: 14,
          height: 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 6,
      ellipsis: '...',
    );

    textPainter.layout(
      maxWidth: noteWidth - 20,
    );

    textPainter.paint(
      canvas,
      Offset(
        note.position.dx + 10,
        note.position.dy + 15,
      ),
    );
  }

  @override
  bool shouldRepaint(
    covariant WhiteboardPainter oldDelegate,
  ) {
    return true;
  }
}

// ============================================================
// SHAPE MODEL
// ============================================================

enum ShapeType {
  rectangle,
  circle,
}

class WhiteboardShape {
  final String id;
  final ShapeType type;
  final Offset start;
  final Offset end;

  const WhiteboardShape({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
  });
}

// ============================================================
// STICKY NOTE MODEL
// ============================================================

class StickyNote {
  final String id;
  Offset position;
  String text;

  StickyNote({
    required this.id,
    required this.position,
    required this.text,
  });
}
