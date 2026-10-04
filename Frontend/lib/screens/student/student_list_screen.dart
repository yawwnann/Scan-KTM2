import 'package:flutter/material.dart';
import '../../utils/ui/dialog_helper.dart';
import 'dart:async';
import '../../models/student.dart';
import '../../models/faculty_data.dart';
import '../../services/api_service.dart';
import '../../services/local_database_service.dart';
import '../../services/sync_service.dart';
import '../../utils/logging/logger.dart';
import '../../config/app_config.dart';
import '../../data/demo_data.dart';
import 'add_edit_student_screen.dart';
import 'widgets/student_card.dart';
import 'widgets/student_list_header.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen>
    with AutomaticKeepAliveClientMixin {
  List<Student> students = [];
  bool isLoading = true;
  bool isAdmin = false;
  bool isLoadingMore = false;
  bool hasMoreData = true;
  bool hasError = false;
  bool isSyncing = false;
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final SyncService _syncService = SyncService();
  String errorMessage = '';
  String? lastNodeKey;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();
  String? sortOption;

  // Filter options
  String? selectedFaculty;
  String? selectedStudyProgram;
  String? selectedVehicleType;
  bool showFilters = false;

  // Available filter values
  List<String> availableFaculties = [];
  List<String> availableStudyPrograms = [];
  List<String> availableVehicleTypes = [];

  @override
  void dispose() {
    searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadStudents();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _checkAdminStatus() async {
    try {
      final adminStatus = await ApiService.isCurrentUserAdmin().timeout(
        const Duration(seconds: 8),
        onTimeout: () => false,
      );
      if (mounted) {
        setState(() {
          isAdmin = adminStatus;
        });
      }
    } catch (e) {
      Logger.error('Error checking admin: $e');
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!isLoading &&
          !isLoadingMore &&
          hasMoreData &&
          searchQuery.isEmpty &&
          selectedFaculty == null &&
          selectedStudyProgram == null &&
          selectedVehicleType == null &&
          sortOption == null) {
        _loadMoreStudents();
      }
    }
  }

  Future<void> _loadStudents() async {
    setState(() {
      isLoading = true;
      hasMoreData = true;
      hasError = false;
      errorMessage = '';
      lastNodeKey = null;
    });

    try {
      List<Student> fetchedStudents;
      if (AppConfig.isDevelopment) {
        await Future.delayed(const Duration(milliseconds: 500));
        fetchedStudents = DemoData.getAllStudents();
      } else {
        // Cek database lokal SQLite terlebih dahulu (instant, offline ready)
        final localCount = await _localDb.getStudentCount();
        if (localCount > 0) {
          fetchedStudents = await _localDb.getAllStudents(limit: 50);
        } else {
          // Jika lokal kosong, tarik dari backend & simpan ke lokal
          fetchedStudents = await ApiService.getStudentsPaginated(limit: 50);
          if (fetchedStudents.isNotEmpty) {
            unawaited(_localDb.batchUpsertStudents(fetchedStudents));
          }
        }
      }

      if (fetchedStudents.isNotEmpty) {
        lastNodeKey = fetchedStudents.last.nim;
      }

      if (fetchedStudents.length < 20) {
        hasMoreData = false;
      }

      // Update available filter options
      _updateFilterOptions(fetchedStudents);

      if (mounted) {
        setState(() {
          students = fetchedStudents;
        });
      }
    } on TimeoutException {
      Logger.error('Timeout loading students from backend');
      if (mounted) {
        setState(() {
          hasError = true;
          errorMessage =
              'Koneksi ke server timeout.\nPastikan internet aktif, lalu tarik ke bawah untuk refresh.';
        });
      }
    } catch (e) {
      Logger.error('Error loading students: $e');
      if (mounted) {
        setState(() {
          hasError = true;
          errorMessage = 'Gagal memuat data: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSync() async {
    if (isSyncing) return;
    setState(() => isSyncing = true);
    final result = await _syncService.syncAll();
    await _loadStudents();
    if (mounted) {
      setState(() => isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor:
              result.success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _performSearch() async {
    if (AppConfig.isDevelopment) return;
    setState(() {
      isLoading = true;
      hasMoreData = false; // Disable pagination while searching
    });

    try {
      // 1. Coba cari di SQLite lokal terlebih dahulu (sangat cepat & offline)
      final localResults = await _localDb.searchStudents(searchQuery);
      if (localResults.isNotEmpty) {
        if (mounted) {
          setState(() {
            students = localResults;
          });
        }
      } else {
        // 2. Fallback cari ke backend jika di lokal tidak ditemukan
        final searchResults = await ApiService.searchStudentsByName(
          searchQuery,
        );

        if (mounted) {
          setState(() {
            students = searchResults;
          });
        }
      }
    } catch (e) {
      Logger.error('Error searching students: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreStudents() async {
    if (AppConfig.isDevelopment) return; // No pagination in demo

    setState(() {
      isLoadingMore = true;
    });

    try {
      final localCount = await _localDb.getStudentCount();
      List<Student> fetchedStudents = [];

      if (localCount > students.length) {
        fetchedStudents = await _localDb.getAllStudents(
          limit: 20,
          offset: students.length,
        );
      } else {
        fetchedStudents = await ApiService.getStudentsPaginated(
          limit: 20,
          lastNodeKey: lastNodeKey,
        );
        if (fetchedStudents.isNotEmpty) {
          unawaited(_localDb.batchUpsertStudents(fetchedStudents));
        }
      }

      if (fetchedStudents.isNotEmpty) {
        lastNodeKey = fetchedStudents.last.nim;

        if (mounted) {
          setState(() {
            students.addAll(fetchedStudents);
          });
        }
      }

      if (fetchedStudents.length < 20) {
        hasMoreData = false;
      }
    } catch (e) {
      Logger.error('Error loading more students: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoadingMore = false;
        });
      }
    }
  }

  void _updateFilterOptions(List<Student> students) {
    // Use predefined faculty data from FacultyData
    availableFaculties = FacultyData.getFaculties();

    // Get all study programs from all faculties
    availableStudyPrograms = [];
    for (String faculty in availableFaculties) {
      availableStudyPrograms.addAll(FacultyData.getAllStudyPrograms(faculty));
    }
    availableStudyPrograms = availableStudyPrograms.toSet().toList()..sort();

    // Keep vehicle types from actual student data
    availableVehicleTypes =
        students
            .map((s) => s.vehicleType)
            .where((vt) => vt.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
  }

  void _clearAllFilters() {
    setState(() {
      searchQuery = '';
      selectedFaculty = null;
      selectedStudyProgram = null;
      selectedVehicleType = null;
      sortOption = null;
      searchController.clear();
    });
  }

  bool get hasActiveFilters {
    return searchQuery.isNotEmpty ||
        selectedFaculty != null ||
        selectedStudyProgram != null ||
        selectedVehicleType != null ||
        sortOption != null;
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (searchQuery.isNotEmpty) count++;
    if (selectedFaculty != null) count++;
    if (selectedStudyProgram != null) count++;
    if (selectedVehicleType != null) count++;
    if (sortOption != null) count++;
    return count;
  }

  Future<void> _deleteStudent(Student student) async {
    final confirmed = await DialogHelper.showConfirmationDialog(
      context: context,
      title: 'Konfirmasi Hapus',
      message:
          'Yakin ingin menghapus ${student.name} (NIM: ${student.nim})?\nData yang dihapus tidak dapat dikembalikan.',
      confirmText: 'Hapus',
      cancelText: 'Batal',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        bool success;
        if (AppConfig.isDevelopment) {
          DemoData.removeStudent(student.nim);
          success = true;
        } else {
          success = await ApiService.deleteStudent(student.nim);
        }

        if (success) {
          await _loadStudents();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text('Mahasiswa berhasil dihapus'),
                  ],
                ),
                backgroundColor: Colors.green[500],
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text('Gagal menghapus mahasiswa'),
                  ],
                ),
                backgroundColor: Colors.red[400],
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        }
      } catch (e) {
        Logger.error('Error deleting student: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Error: $e')),
                ],
              ),
              backgroundColor: Colors.red[400],
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    }
  }

  List<Student> get filteredStudents {
    List<Student> filtered = List.from(students);

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((student) {
        return student.name.toLowerCase().contains(query) ||
            student.nim.toLowerCase().contains(query) ||
            student.vehicleNumber.toLowerCase().contains(query) ||
            student.faculty.toLowerCase().contains(query) ||
            student.studyProgram.toLowerCase().contains(query);
      }).toList();
    }

    // Apply faculty filter
    if (selectedFaculty != null) {
      filtered = filtered
          .where((student) => student.faculty == selectedFaculty)
          .toList();
    }

    // Apply study program filter
    if (selectedStudyProgram != null) {
      filtered = filtered
          .where((student) => student.studyProgram == selectedStudyProgram)
          .toList();
    }

    // Apply vehicle type filter
    if (selectedVehicleType != null) {
      filtered = filtered
          .where((student) => student.vehicleType == selectedVehicleType)
          .toList();
    }

    // Apply sorting
    if (sortOption != null) {
      switch (sortOption) {
        case 'name_asc':
          filtered.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          break;
        case 'name_desc':
          filtered.sort(
            (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
          );
          break;
        case 'nim_asc':
          filtered.sort((a, b) => a.nim.compareTo(b.nim));
          break;
        case 'nim_desc':
          filtered.sort((a, b) => b.nim.compareTo(a.nim));
          break;
        case 'faculty_asc':
          filtered.sort(
            (a, b) =>
                a.faculty.toLowerCase().compareTo(b.faculty.toLowerCase()),
          );
          break;
        case 'faculty_desc':
          filtered.sort(
            (a, b) =>
                b.faculty.toLowerCase().compareTo(a.faculty.toLowerCase()),
          );
          break;
        case 'scan_time_newest':
          filtered.sort((a, b) => b.scanTime.compareTo(a.scanTime));
          break;
        case 'scan_time_oldest':
          filtered.sort((a, b) => a.scanTime.compareTo(b.scanTime));
          break;
      }
    }

    return filtered;
  }

  Future<void> _navigateToAddStudent() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditStudentScreen(),
      ),
    );
    if (result is Student) {
      // Eagerly update UI so it appears instantly
      setState(() {
        students.add(result);
        _updateFilterOptions(students);
      });
      // Then sync with server in background
      _loadStudents();
    } else if (result == true) {
      _loadStudents();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      floatingActionButton: isAdmin
          ? Padding(
              padding: const EdgeInsets.only(bottom: 100.0), // Hindari tertutup navbar
              child: FloatingActionButton(
                onPressed: _navigateToAddStudent,
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                elevation: 4,
                child: const Icon(Icons.add, size: 28),
              ),
            )
          : null,
      body: Column(
        children: [
          StudentListHeader(
            isLoading: isLoading,
            studentCount: students.length,
            onSync: _handleSync,
            isSyncing: isSyncing,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadStudents,
              color: Theme.of(context).colorScheme.primary,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Modern Search Bar
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Cari mahasiswa...',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF1565C0,
                                ), // Consistent blue
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.search,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: Colors.grey[400],
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        searchQuery = '';
                                        searchController.clear();
                                      });
                                      _loadStudents();
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              searchQuery = value;
                            });
                            if (_debounce?.isActive ?? false)
                              _debounce!.cancel();
                            _debounce = Timer(
                              const Duration(milliseconds: 500),
                              () {
                                if (searchQuery.isNotEmpty) {
                                  _performSearch();
                                } else {
                                  _loadStudents();
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ),

                    // Modern Filter and Sort Controls
                    if (!isLoading) ...[
                      Container(
                        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Row(
                          children: [
                            // Filter Button
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      showFilters = !showFilters;
                                    });
                                  },
                                  icon: Icon(
                                    showFilters
                                        ? Icons.filter_list_off
                                        : Icons.tune,
                                    size: 18,
                                  ),
                                  label: Text(
                                    hasActiveFilters
                                        ? 'Filter (${_getActiveFilterCount()})'
                                        : 'Filter',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: hasActiveFilters
                                        ? const Color(
                                            0xFF1565C0,
                                          ) // Consistent blue
                                        : Colors.white,
                                    foregroundColor: hasActiveFilters
                                        ? Colors.white
                                        : Colors.grey[700],
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: hasActiveFilters
                                            ? const Color(
                                                0xFF1565C0,
                                              ) // Consistent blue
                                            : Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Sort Button
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    setState(() {
                                      sortOption = value;
                                    });
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: null,
                                      child: Row(
                                        children: [
                                          Icon(Icons.clear, size: 18),
                                          SizedBox(width: 8),
                                          Text('Hapus Urutan'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'name_asc',
                                      child: Row(
                                        children: [
                                          Icon(Icons.sort_by_alpha, size: 18),
                                          SizedBox(width: 8),
                                          Text('Nama A-Z'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'name_desc',
                                      child: Row(
                                        children: [
                                          Icon(Icons.sort_by_alpha, size: 18),
                                          SizedBox(width: 8),
                                          Text('Nama Z-A'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'nim_asc',
                                      child: Row(
                                        children: [
                                          Icon(Icons.numbers, size: 18),
                                          SizedBox(width: 8),
                                          Text('NIM A-Z'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'nim_desc',
                                      child: Row(
                                        children: [
                                          Icon(Icons.numbers, size: 18),
                                          SizedBox(width: 8),
                                          Text('NIM Z-A'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'faculty_asc',
                                      child: Row(
                                        children: [
                                          Icon(Icons.school, size: 18),
                                          SizedBox(width: 8),
                                          Text('Fakultas A-Z'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'faculty_desc',
                                      child: Row(
                                        children: [
                                          Icon(Icons.school, size: 18),
                                          SizedBox(width: 8),
                                          Text('Fakultas Z-A'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'scan_time_newest',
                                      child: Row(
                                        children: [
                                          Icon(Icons.access_time, size: 18),
                                          SizedBox(width: 8),
                                          Text('Terbaru'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'scan_time_oldest',
                                      child: Row(
                                        children: [
                                          Icon(Icons.access_time, size: 18),
                                          SizedBox(width: 8),
                                          Text('Terlama'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: sortOption != null
                                          ? const Color(
                                              0xFF1565C0,
                                            ) // Consistent blue
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: sortOption != null
                                            ? const Color(
                                                0xFF1565C0,
                                              ) // Consistent blue
                                            : Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.sort,
                                          size: 18,
                                          color: sortOption != null
                                              ? Colors.white
                                              : Colors.grey[700],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          sortOption != null
                                              ? 'Diurutkan'
                                              : 'Urutkan',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: sortOption != null
                                                ? Colors.white
                                                : Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Filter Options (Expandable)
                      if (showFilters) ...[
                        Container(
                          margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.tune,
                                    color: const Color(
                                      0xFF1565C0,
                                    ), // Consistent blue
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Filter Data',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (hasActiveFilters)
                                    TextButton.icon(
                                      onPressed: _clearAllFilters,
                                      icon: const Icon(
                                        Icons.clear_all,
                                        size: 16,
                                      ),
                                      label: const Text('Hapus Semua'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red[600],
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Faculty Filter
                              if (availableFaculties.isNotEmpty) ...[
                                const Text(
                                  'Fakultas',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedFaculty,
                                      hint: const Text('Pilih Fakultas'),
                                      isExpanded: true,
                                      items: [
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('Semua Fakultas'),
                                        ),
                                        ...availableFaculties.map(
                                          (faculty) => DropdownMenuItem<String>(
                                            value: faculty,
                                            child: Text(faculty),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          selectedFaculty = value;
                                          // Reset study program when faculty changes
                                          if (selectedStudyProgram != null &&
                                              selectedFaculty != null) {
                                            final facultyPrograms =
                                                FacultyData.getAllStudyPrograms(
                                                  selectedFaculty!,
                                                );
                                            if (!facultyPrograms.contains(
                                              selectedStudyProgram,
                                            )) {
                                              selectedStudyProgram = null;
                                            }
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Study Program Filter
                              if (availableStudyPrograms.isNotEmpty) ...[
                                const Text(
                                  'Program Studi',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedStudyProgram,
                                      hint: const Text('Pilih Program Studi'),
                                      isExpanded: true,
                                      items: [
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('Semua Program Studi'),
                                        ),
                                        // Show only programs from selected faculty if faculty is selected
                                        ...(selectedFaculty != null
                                                ? FacultyData.getAllStudyPrograms(
                                                    selectedFaculty!,
                                                  )
                                                : availableStudyPrograms)
                                            .map(
                                              (program) =>
                                                  DropdownMenuItem<String>(
                                                    value: program,
                                                    child: Text(program),
                                                  ),
                                            ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          selectedStudyProgram = value;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Vehicle Type Filter
                              if (availableVehicleTypes.isNotEmpty) ...[
                                const Text(
                                  'Jenis Kendaraan',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedVehicleType,
                                      hint: const Text('Pilih Jenis Kendaraan'),
                                      isExpanded: true,
                                      items: [
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('Semua Jenis Kendaraan'),
                                        ),
                                        ...availableVehicleTypes.map(
                                          (type) => DropdownMenuItem<String>(
                                            value: type,
                                            child: Text(type),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          selectedVehicleType = value;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],

                    // Quick Stats Cards
                    if (!isLoading)
                      Container(
                        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(
                                        0xFF1565C0,
                                      ), // Consistent blue
                                      const Color(
                                        0xFF1976D2,
                                      ), // Slightly darker blue
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF1565C0,
                                      ).withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.people_alt_rounded,
                                      color: Colors.white.withOpacity(0.9),
                                      size: 20,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${students.length}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const Text(
                                      'Total',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green[600]!,
                                      Colors.green[500]!,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.search_rounded,
                                      color: Colors.white.withOpacity(0.9),
                                      size: 20,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${filteredStudents.length}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const Text(
                                      'Hasil',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Student List
                    isLoading
                        ? SizedBox(
                            height: 300,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      const Color(
                                        0xFF1565C0,
                                      ), // Consistent blue
                                    ),
                                    strokeWidth: 3,
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Memuat data mahasiswa...',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : hasError
                        ? SizedBox(
                            height: 350,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.red[50],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.wifi_off_rounded,
                                        size: 48,
                                        color: Colors.red[400],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      'Gagal Memuat Data',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      errorMessage,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                        height: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: _loadStudents,
                                      icon: const Icon(
                                        Icons.refresh,
                                        size: 18,
                                      ),
                                      label: const Text('Coba Lagi'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF1565C0,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : filteredStudents.isEmpty
                        ? SizedBox(
                            height: 300,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      hasActiveFilters
                                          ? Icons.search_off
                                          : Icons.people_outline,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    hasActiveFilters
                                        ? 'Tidak ditemukan mahasiswa'
                                        : 'Belum ada data mahasiswa',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    hasActiveFilters
                                        ? 'Coba ubah filter atau kata kunci pencarian'
                                        : 'Tambahkan mahasiswa baru untuk memulai',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (hasActiveFilters) ...[
                                    const SizedBox(height: 16),
                                    TextButton.icon(
                                      onPressed: _clearAllFilters,
                                      icon: const Icon(
                                        Icons.clear_all,
                                        size: 18,
                                      ),
                                      label: const Text('Hapus Semua Filter'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: List.generate(filteredStudents.length, (
                              index,
                            ) {
                              final student = filteredStudents[index];
                              return StudentCard(
                                student: student,
                                isAdmin: isAdmin,
                                onDelete: () => _deleteStudent(student),
                                onRefresh: _loadStudents,
                              );
                            }),
                          ),
                    
                    if (isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
